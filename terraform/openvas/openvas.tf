# Configure the Microsoft Azure Provider

variable subscription_id {}
variable client_id {}
variable client_secret {}
variable tenant_id {}
variable ssh_key {}
variable source_ip {}
variable environment {}

provider "azurerm" {
    subscription_id = var.subscription_id
    client_id       = var.client_id
    client_secret   = var.client_secret
    tenant_id       = var.tenant_id
}

# Create a resource group if it doesn’t exist
resource "azurerm_resource_group" "openvas-rg" {
    name     = "openvas-rg"
    location = "westeurope"

    tags = {
        environment = var.environment
    }
}

# Create virtual network
resource "azurerm_virtual_network" "openvas-vnet" {
    name                = "openvas-vnet"
    address_space       = ["10.3.0.0/16"]
    location            = "westeurope"
    resource_group_name = azurerm_resource_group.openvas-rg.name

    tags = {
        environment = var.environment
    }
}

# Create subnet
resource "azurerm_subnet" "openvas-subnet" {
    name                 = "openvas-subnet"
    resource_group_name  = azurerm_resource_group.openvas-rg.name
    virtual_network_name = azurerm_virtual_network.openvas-vnet.name
    address_prefix       = "10.3.1.0/24"
}

# Create public IPs
resource "azurerm_public_ip" "openvas-publicip" {
    name                         = "openvas-publicip"
    location                     = "westeurope"
    resource_group_name          = azurerm_resource_group.openvas-rg.name
    allocation_method            = "Dynamic"

    tags = {
        environment = var.environment
    }
}

# Create Network Security Group and rule
resource "azurerm_network_security_group" "openvas-nsg" {
    name                = "openvas-nsg"
    location            = "westeurope"
    resource_group_name = azurerm_resource_group.openvas-rg.name

    security_rule {
        name                       = "SSH"
        priority                   = 1001
        direction                  = "Inbound"
        access                     = "Allow"
        protocol                   = "Tcp"
        source_port_range          = "*"
        destination_port_range     = "22"
        source_address_prefix      = var.source_ip
        destination_address_prefix = "*"
    }

    security_rule {
        name                       = "HTTPS"
        priority                   = 1002
        direction                  = "Inbound"
        access                     = "Allow"
        protocol                   = "Tcp"
        source_port_range          = "*"
        destination_port_range     = "443"
        source_address_prefix      = var.source_ip
        destination_address_prefix = "*"
    }
    security_rule {
        name                       = "ICMP"
        priority                   = 1003
        direction                  = "Inbound"
        access                     = "Allow"
        protocol                   = "ICMP"
        source_port_range          = "*"
        destination_port_range     = "*"
        source_address_prefix      = var.source_ip
        destination_address_prefix = "*"
    }
    tags = {
        environment = var.environment
    }
}

# Create network interface
resource "azurerm_network_interface" "openvas-nic" {
    name                      = "openvas-NIC"
    location                  = "westeurope"
    resource_group_name       = azurerm_resource_group.openvas-rg.name
    network_security_group_id = azurerm_network_security_group.openvas-nsg.id

    ip_configuration {
        name                          = "openvas-NicConfiguration"
        subnet_id                     = azurerm_subnet.openvas-subnet.id
        private_ip_address_allocation = "Dynamic"
        public_ip_address_id          = azurerm_public_ip.openvas-publicip.id
    }

    tags = {
        environment = var.environment
    }
}

# Generate random text for a unique storage account name
resource "random_id" "randomId" {
    keepers = {
        # Generate a new ID only when a new resource group is defined
        resource_group = azurerm_resource_group.openvas-rg.name
    }

    byte_length = 8
}

# Create storage account for boot diagnostics
resource "azurerm_storage_account" "openvas-storageaccount" {
    name                        = "diag${random_id.randomId.hex}"
    resource_group_name         = azurerm_resource_group.openvas-rg.name
    location                    = "westeurope"
    account_tier                = "Standard"
    account_replication_type    = "LRS"

    tags = {
        environment = var.environment
    }
}

# Create virtual machine
resource "azurerm_virtual_machine" "openvas-vm" {
    name                  = "openvas-VM"
    location              = "westeurope"
    resource_group_name   = azurerm_resource_group.openvas-rg.name
    network_interface_ids = [azurerm_network_interface.openvas-nic.id]
    vm_size               = "Standard_DS1_v2"

    storage_os_disk {
        name              = "openvas-OsDisk"
        caching           = "ReadWrite"
        create_option     = "FromImage"
        managed_disk_type = "Premium_LRS"
    }

    storage_image_reference {
        publisher = "Debian"
        offer     = "debian-10"
        sku       = "10"
        version   = "latest"
    }


    os_profile {
        computer_name  = "openvas"
        admin_username = "account"
    }

    os_profile_linux_config {
        disable_password_authentication = true
        ssh_keys {
            path     = "/home/account/.ssh/authorized_keys"
            key_data = var.ssh_key
        }
    }

    boot_diagnostics {
        enabled = "true"
        storage_uri = azurerm_storage_account.openvas-storageaccount.primary_blob_endpoint
    }

    tags = {
        environment = var.environment
    }
}

data "azurerm_public_ip" "openvas-publicip" {
  resource_group_name = azurerm_resource_group.openvas-rg.name
  depends_on          = [azurerm_virtual_machine.openvas-vm]
  name                = azurerm_public_ip.openvas-publicip.name
}

output "ip_address" {
  value = data.azurerm_public_ip.openvas-publicip.ip_address
}
