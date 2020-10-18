# Configure the Microsoft Azure Provider
variable subscription_id {}
variable client_id {}
variable client_secret {}
variable tenant_id {}
variable ssh_key {}
variable source_ip {}

provider "azurerm" {
    subscription_id = "${var.subscription_id}"
    client_id       = "${var.client_id}"
    client_secret   = "${var.client_secret}"
    tenant_id       = "${var.tenant_id}"
}

variable "servers" {
    default = ["logstash1", "elastic1", "elastic2", "elastic3"]
    #default = ["elastic1"]
}

variable "amount_of_servers" {
    default = "4"
}

# Create a resource group if it doesn’t exist
resource "azurerm_resource_group" "elk-rg" {
    name     = "elk-rg"
    location = "westeurope"

    tags = {
        environment = "Terraform Elk Demo"
    }
}

# Create virtual network
resource "azurerm_virtual_network" "elk-vnet" {
    name                = "elk-vnet"
    address_space       = ["10.2.0.0/16"]
    location            = "westeurope"
    resource_group_name = azurerm_resource_group.elk-rg.name

    tags = {
        environment = "Terraform Elk Demo"
    }
}

# Create subnet
resource "azurerm_subnet" "elk-subnet" {
    name                 = "elk-subnet"
    resource_group_name  = azurerm_resource_group.elk-rg.name
    virtual_network_name = azurerm_virtual_network.elk-vnet.name
    address_prefix       = "10.2.1.0/24"
}

# Create public IPs
resource "azurerm_public_ip" "elk-publicip" {
    count                        = "${length(var.servers)}"
    name                         = "elk-publicip-${var.servers[count.index]}"
    location                     = "westeurope"
    resource_group_name          = azurerm_resource_group.elk-rg.name
    allocation_method            = "Dynamic"

    tags = {
        environment = "Terraform Elk Demo"
    }
}

# Create Network Security Group and rule
resource "azurerm_network_security_group" "elk-nsg" {
    name                = "elk-nsg"
    location            = "westeurope"
    resource_group_name = azurerm_resource_group.elk-rg.name

    security_rule {
        name                       = "ICMP"
        priority                   = 1001
        direction                  = "Inbound"
        access                     = "Allow"
        protocol                   = "ICMP"
        source_port_range          = "*"
        destination_port_range     = "*"
        source_address_prefix      = "${var.source_ip}"
        destination_address_prefix = "*"
    }
    security_rule {
        name                       = "SSH"
        priority                   = 1002
        direction                  = "Inbound"
        access                     = "Allow"
        protocol                   = "Tcp"
        source_port_range          = "*"
        destination_port_range     = "22"
        source_address_prefix      = "${var.source_ip}"
        destination_address_prefix = "*"
    }

    security_rule {
        name                       = "HTTPS"
        priority                   = 1003
        direction                  = "Inbound"
        access                     = "Allow"
        protocol                   = "Tcp"
        source_port_range          = "*"
        destination_port_range     = "443"
        source_address_prefix      = "${var.source_ip}"
        destination_address_prefix = "*"
    }
    tags = {
        environment = "Terraform Elk Demo"
    }
}

# Create network interface
resource "azurerm_network_interface" "elk-nic" {
    count                     = "${length(var.servers)}"
    name                      = "elk-NIC-${var.servers[count.index]}"
    location                  = "westeurope"
    resource_group_name       = azurerm_resource_group.elk-rg.name
    network_security_group_id = azurerm_network_security_group.elk-nsg.id

    ip_configuration {
        name                          = "elk-NicConfiguration"
        subnet_id                     = azurerm_subnet.elk-subnet.id
        #private_ip_address_allocation = "Dynamic"
        private_ip_address_allocation = "Static"
        private_ip_address            = "10.2.1.${count.index+4}"
        public_ip_address_id          = azurerm_public_ip.elk-publicip[count.index].id
    }

    tags = {
        environment = "Terraform Elk Demo"
    }
}

# Generate random text for a unique storage account name
resource "random_id" "randomId" {
    keepers = {
        # Generate a new ID only when a new resource group is defined
        resource_group = azurerm_resource_group.elk-rg.name
    }

    byte_length = 8
}

# Create storage account for boot diagnostics
resource "azurerm_storage_account" "elk-storageaccount" {
    name                        = "diag${random_id.randomId.hex}"
    resource_group_name         = azurerm_resource_group.elk-rg.name
    location                    = "westeurope"
    account_tier                = "Standard"
    account_replication_type    = "LRS"

    tags = {
        environment = "Terraform Elk Demo"
    }
}

# Create virtual machine
resource "azurerm_virtual_machine" "elk-vm" {
    count                 = "${length(var.servers)}"
    name                  = "elk-${var.servers[count.index]}"
    location              = "westeurope"
    resource_group_name   = azurerm_resource_group.elk-rg.name
    network_interface_ids = [azurerm_network_interface.elk-nic[count.index].id]
    vm_size               = "Standard_DS1_v2"
    #vm_size               = "Standard_B4ms"

    storage_os_disk {
        name              = "elk-OsDisk-${var.servers[count.index]}"
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
        computer_name  = "elk-${var.servers[count.index]}"
        admin_username = "account"
    }

    os_profile_linux_config {
        disable_password_authentication = true
        ssh_keys {
            path     = "/home/account/.ssh/authorized_keys"
            key_data = "${var.ssh_key}"

        }
    }

    boot_diagnostics {
        enabled = "true"
        storage_uri = azurerm_storage_account.elk-storageaccount.primary_blob_endpoint
    }

    tags = {
        environment = "Terraform Elk Demo"
    }
}


data "azurerm_public_ip" "elk-publicip" {
  count               = "${var.amount_of_servers}"
  name                = "${element(azurerm_public_ip.elk-publicip.*.name, count.index)}"
  resource_group_name = "${azurerm_virtual_machine.elk-vm[count.index].resource_group_name}"
}

output "public_ip_address" {
  value = "${data.azurerm_public_ip.elk-publicip.*.ip_address}"
}

output "public_ip_address_hostname" {
  value = "${data.azurerm_public_ip.elk-publicip.*.name}"
}
