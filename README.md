# security-infra

## Changes
Update 2020-08-15: Moved remote username from hardcoded to configurable via variables.yml. Changed systemd scripts based on the changed information at https://sadsloth.net/post/install-gvm11-src-on-debian/ Also updated version numbers of the GVM source packages.

Update 2020-06-27: Updated the version numbers of packages the GVM script compiles. Some minor updates to this README.

Update 2020-01-18: Various changes to scripts under tools/ directory. OpenVAS -related were not working anymore after the latest changes to OpenVAS Ansible part. Also changed download_terraform.sh to download the latest one automatically. And finally some small clarifications etc. to this README.

Update 2020-01-13: OpenVAS Ansible playbooks should now install GVM-11 correctly. Finally. :) 

Thanks to this howto: https://sadsloth.net/post/install-gvm11-src-on-debian/

Also GVM module version numbers were moved to one file, so you need to edit only one location when versions change.

Update 2020-01-11: OpenVAS refactoring + version change started, so the latest config won't work yet. Machine is installed correctly, and most of the packages are compiled + installed correctly, but not all. The build process has changed quite much between GVM-10 and GVM-11, and the build process used in this documentaion is not yet updated/tested to work with the GVM-11. 

OpenVAS Ansible part used previously .sh -scripts for most of the things, so Ansible just started the script which did the magic.  Now those things are done via various Ansible modules, which is the proper way.

Update 2020-01-02: Work in progress. Mostly things should work, but documentation is not yet final and things are not fully tested. 

## Documentation for installing security tools automatically

I am using this repo to document things I've learned when I've played with Azure, Ansible, Terraform, etc. Because security related things are close to my heart, I will concentrate on those things and systems. For now this will cover installation instructions for security related systems, but who knows what will be offered in the future. 

The instructions will cover a setup where servers will be created to Azure using Terraform, and after servers are up and running, Ansible is used to install the required components and necessary configuration files. If you are using AWS or some other (cloud) environment, you just need to replace the Azure part. 

At the moment I have a working way to install security scanner OpenVAS (http://www.openvas.org/) to a Debian 10 (Buster) virtual machine and ELK Stack (https://www.elastic.co/what-is/elk-stack) is installed to 4 Debian 10 (Buster) virtual machines. Preferred setup for ELK Stack would have been 5 machines, but because Azure free subscription is restricted to use 4 vCPUs, I have combined Logstash + Kibana on the same server and have the common three node cluster for the Elasticsearch. So, if you are working with paid Azure subscription, it is better to separete Logstash and Kibana to their own servers. 


The document assumes that you have a Debian 10 machine up and running where you can install all of the management things. The code is for quite specific use case at the moment and it assumes many things. Of course you can edit the files to suit your needs better. In my own development environment the management Debian is running on my home lab, but it can of course be running on Azure or some other environment.

If you already have the machine up and running, you can safely skip the Terraform part and just continue from the Ansible section of this document. 

### The repo structure 

There are the following directories in this repo:

- files: Configuration etc. files which are directly copied to the VMs in Azure
- playbooks: Ansible playbooks which you can use to install/configure various parts of the infra.
- scripts: Mostly Bash-scripts which are used in Ansible-scripts to help in various things.
- terraform: Terraform templates for various parts of the infra.
- tools: Scripts which you can run directly to prepare your local machine for Ansible/Terraform and start the build process for various parts of the whole environment.

### Preparations
If you want to use the scripts etc. found in this repo, you can start by cloning the repo. Because of the way files are currently written, please clone it under /opt/

```
$ cd /opt
$ git clone https://github.com/ragol-github/security-infra.git
```

Remote machines will use 'account' as their username for installing and configuring things, so it's better to create the account with same name to your local management server. Sudo rights are needed for this account so it can update /etc/hosts with the public IPs of the created Azure VMs.

If you want to use some other username, just update playbooks/openvas/variables.yml accordingly.

 
```
$ sudo adduser account sudo
```

After that just change to the new account and run the prepare-debian.sh -script from the repo. Naturally it's always necessary to check what the script will actually do, before relying blindly to some script you found from the Internetz..... Basically it will install all the required .debs, create SSH Key for the account and do some other necessary things which may pop up later.

```
$ sudo su account
$ cd /opt/security-infra/tools
$ cat prepare-debian.sh
$ ./prepare-debian.sh
```

## Terraform

Terraform  (https://www.terraform.io/) is a system which allows you to deliver the whole infrastractures just by writing code. Your Terraform code tells the final configuration of the infra. So if you first have 10 servers, later need 5 more, and a little after that 2 less, your final code covers 13 servers. You don't first write code for 10 servers and then later code to add 5 more and after that remove 2. 

Terraform is suitable for creating networks, firewall rules for the network, virtual machines which are started from a provided virtual image, etc. That's why I decided to use Terraform only for spinning up the machines, and then switch to Ansible to install software + configuration files for those software packages.

There are no official debs for Terraform. It's is distributed in .tar.gz -format and latest can be found from: https://www.terraform.io/downloads.html

After that you can install it via the following way. In my scripts I've assumed that Terraform is located under /opt/terraform. You can also use the security-infra/tools/download_terraform.sh -script, which does the following, but it downloads automatically the latest version. The latest available can be beta version, but if you are just playing with this repo, it's most probably okay. If you are downloading Terraform to be used in the production, then beta version may not be the best option. 

```
$ cd ~
$ export TER_VER="0.12.28"
$ wget https://releases.hashicorp.com/terraform/${TER_VER}/terraform_${TER_VER}_linux_amd64.zip
$ unzip terraform_${TER_VER}_linux_amd64.zip
$ sudo mkdir /opt/terraform
$ sudo mv terraform /opt/terraform
$ sudo ln -s /opt/terraform/terraform /usr/bin/terraform
```

### Connecting Terraform to Azure

Terraform is a really powerful system, which also means in this case that it requires quite many hours to learn all the details. Luckily you don't need to learn everything to make it work in simpler cases. The first thing you need to get working is the connectivity to the environment where the systems will be deployed. In this document I'm using Azure, so I won't cover other environments. Although it should be quite simple change to use AWS for example and Google is your friend in that case.

Terraform uses Providers to connect to differents systems, eg. AWZ, Azure, GCP, vSphere, or quite many more: https://www.terraform.io/docs/providers/index.html

The official Terraform Azure Provider documentation is available: https://www.terraform.io/docs/providers/azurerm/index.html This documentation will use Azure Service Principals with Client Secret for authenticating, and info to create one can be found at https://www.terraform.io/docs/providers/azurerm/guides/service_principal_client_secret.html. Of course you need to have first the suitable Azure subscription. If you don't have a paid one, you can get free subscription which is suitable for testing purposes:  https://azure.microsoft.com/en-us/free/

Azure free has limitations, but it can be used quite well for small scale testing. The biggest issue I've found is that you can get only 4 vCPUs simultaneously, so you can get 4 VMs with 1 vCPU. I didn't find out this from the documentation, but I found it out when trying to get 5th server up and running. 

I didn't want to include my connection details to the Terraform code because it will be published via this repo. Luckily Terraform offers many ways to separate that kind of things from the actual code. I put the connection details in terraform.tfvars file inside the same directory where other tf-files are located and just referenced the variables in my actual code.

So, like this:

```
terraform.tfvars

subscription_id = "00000000-0000-0000-0000-000000000000"
# Client/Appid
client_id       = "00000000-0000-0000-0000-000000000000"
client_secret   = "00000000-0000-0000-0000-000000000000"
tenant_id       = "00000000-0000-0000-0000-000000000000"


actul-terraform-file.tf

provider "azurerm" {
    subscription_id = var.subscription_id
    client_id       = var.client_id
    client_secret   = var.client_secret
    tenant_id       = var.tenant_id
}
```

My setup is built around the examples found here: https://github.com/terraform-providers/terraform-provider-azurerm There isn't any particular one I've based the setup on, but I've taken the info from multiple example files.

### Creating the first Terraform file

I won't document all details in this README, because the code is quite simple and almost self documenting. terraform/openvas/openvas.tf handles the creation of one server and terraform/elk-stack/elk-stack.tf handles the cluster creation. Some explanation is provided after the instructions how to deploy the environment.

Before you can apply the files, you need to init your Terraform installation in every directory from where you plan to deploy your servers.

```
$ cd /opt/security-infra/terraform/openvas
$ /op/terraform/terraform init
```

After the Terraform environment is initialized, you can first check that the tf-files will actually do. Terraform will scan all .tf -files in the directory where you are running it.


```
$ /op/terraform/terraform plan
```

If you are satisfied for the results, you can deploy the environment. The deployment will show first what it will do and asks if you really want to proceed. If you have changed your code after the previous deployment, it will deploy only the changes, not recreate the whole environment. 


```
$ /op/terraform/terraform apply
```


And, when you are finished and want to tear down the whole dev environment so that it won't cause any unnecessary costs (it will again tell what will be done and ask confirmation):


```
$ /op/terraform/terraform destroy
```

Be prepared, removing things can take surprisingly long time.... It was quite weird to notice, it may took many times longer than when you are creating them. 

Good thing in using Terraform+Ansible based setup for deploying the dev environment is that you don't have to leave it running because it takes too long to redeploy (or to destroy it). 

## Ansible

Ansible documentation is available at: https://docs.ansible.com/


### Install Ansible to Debian 10 (Buster)

Install Ansible normally via apt (or aptitude if you prefer to use it). 

If you prefer to, you can use the provided script in this repo tools/prepare_debian.sh to do almost all of these tasks for you. 


```
$ sudo apt install ansible
```

Create ansible hosts list by adding the following to /etc/ansible/hosts.  You must do this manually, the above mentioned script won't do this.

```
[scanners]
openvas1

[logstash]
elk-logstash1

[elastic]
elk-elastic1
elk-elastic2
elk-elastic3

[kibana]
elk-logstash1
```


Create SSH keys to be used for Ansible (select suitable title for your key, the -C paramater). For location of the key files, just press enter to accept the default location and for SSH passphrase it is good practice to select secure passphrase. 

```
[account@ansible ~]$ ssh-keygen -t rsa -b 4096 -C "<your.email@server.invalid>"
Generating public/private rsa key pair.
Enter file in which to save the key (/home/account/.ssh/id_rsa):
Enter passphrase (empty for no passphrase):
Enter same passphrase again:
Your identification has been saved in /home/account/.ssh/id_rsa.
Your public key has been saved in /home/account/.ssh/id_rsa.pub.
```

## OpenVAS (GVM)

OpenVAS is a vulnerability scanner. So it will scan the speficied network ranges/hosts and tells if it can find any vulnerabilities based on the database. Basically it shows CVE-numbers you haven't yet fixed in your system, if it just can find out it through scanning. Scans can be either unauthenticated or authenticated. And there can be also some other type of scans. 

The relationship between OpenVAS and Greenbone Vulnerability Management is a bit complex, and thus is also the choice between different versions not so simple. But here are the most important parts from https://www.openvas.org 

"The year 2017 marked the beginning of a new era: First of all, Greenbone became visible as the driving force behind OpenVAS, reducing the brand confusion. This included several activities, the most essential one the renaming of the "OpenVAS framework" to "Greenbone Vulnerability Management" (GVM), of which the OpenVAS Scanner is one of many modules. It also lead to "GVM-10" as the successor of "OpenVAS-9". No license changes happened, all modules remained Open Source

In 2019 the branding separation was completed. OpenVAS now represents the actual vulnerability scanner as it did originally and the "S" in "OpenVAS" now stands for "Scanner" rather than "System". These changes are accompanied by an updated OpenVAS logo. The framework where OpenVAS is embedded is the Greenbone Vulnerability Management (GVM)."

Greenbone publishes a community edition of their GSM ONE system as a virtual appliance, which may be suitable for many use cases. But if you want to get your hands on the actual OpenVAS, you need to compile it from the source code. The problem in this method is that it's not one tar.gz which you'll download and then compile, but there are multiple packages and they need to be compiled in the proper order because there are dependencies between packages. And depending on your requirements there are quite many packages you need to install to the host OS. Some are mandatory, some are optional. And it's not always very clear which packages you'll actually need to install before the compilation process goes through.

This document and scripts assume that you'll want and need everything. Who wouldn't? :) 

The OpenVAS part of the process is built around the HOWTO available at: https://sadsloth.net/post/install-gvm11-src-on-debian/ 

If you just want to test things before reading further, you can do the following. It will create the machine to Azure and install OpenVAS there. When everything's ready, the scanner can be found at https://openvas1

```
$ sudo su account
$ cd tools
$ ./create-openvas-machine.sh
Creating VM to Azure
Azure VM created and available via ssh@openvas1. /etc/hosts is updated.

Adding host to ~/.ssh/known_hosts
# openvas1:22 SSH-2.0-OpenSSH_7.9p1 Debian-10+deb10u1
# openvas1:22 SSH-2.0-OpenSSH_7.9p1 Debian-10+deb10u1
# openvas1:22 SSH-2.0-OpenSSH_7.9p1 Debian-10+deb10u1

PLAY [scanners] ****************************************************************************************************************************************************

TASK [Gathering Facts] *********************************************************************************************************************************************
Enter passphrase for key '/home/account/.ssh/id_rsa':
ok: [openvas1]

TASK [install acl] *************************************************************************************************************************************************

changed: [openvas1]

<redacted>

PLAY [scanners] ****************************************************************************************************************************************************

TASK [Gathering Facts] *********************************************************************************************************************************************
ok: [openvas1]

TASK [Add the user 'openvas'] **************************************************************************************************************************************
changed: [openvas1]

TASK [Create compile dirs] *****************************************************************************************************************************************
ok: [openvas1]

TASK [Download, compile and install OpenVAS] ***********************************************************************************************************************
changed: [openvas1]

<redacted>

PLAY [scanners] ****************************************************************************************************************************************************

TASK [Gathering Facts] *********************************************************************************************************************************************
ok: [openvas1]

TASK [Copy vimrc] **************************************************************************************************************************************************
changed: [openvas1]

TASK [Configure and start gvmd] ************************************************************************************************************************************
changed: [openvas1]

PLAY RECAP *********************************************************************************************************************************************************
openvas1                   : ok=64   changed=47   unreachable=0    failed=0    skipped=0    rescued=0    ignored=0

```

### Ansible process for OpenVAS

I'm not going through in a detailed way all of the dirty details, because you can see them in the Ansible files found at playbooks/openvas and scripts+files referenced by the Ansible files. If you already have the server up and running and need to just install OpenVAS there, you can do the following:

```
$ cd playbooks/openvas
$ ansible-playbook install-gvm.yml
```

The default password to login to the system after it is installed can be found in scripts/configure-gvmd.sh.

Basically ansible logins via SSH to the destination server and runs the provided commands through that connection, so you need to have a suitable account on the server with sudo rights. If using sudo requires password, you can change the command above to

```
$ ansible-playbook install-gmvd.yml --ask-become-pass
```

But let's get started about the actual OpenVAS part. It's best to start at the file which describes the order or the process, but let's first check what versions the script is compiling. The version numbers below are the ones used in this HOWTO.

```
$ cat variables.yml
---
# The latest version numbers for these packages can be found from the following URLs
# https://github.com/greenbone/gsa/releases
# https://github.com/greenbone/gvm-libs/releases
# https://github.com/greenbone/gvmd/releases
# https://github.com/greenbone/openvas-smb/releases
# https://github.com/greenbone/openvas/releases
# https://github.com/greenbone/ospd/releases
# https://github.com/greenbone/ospd-openvas/releases
gsa_version: "9.0.1"
gvm_libs_version: "11.0.1"
gvmd_version: "9.0.1"
openvas_smb_version: "1.0.5"
openvas_version: "7.0.1"
ospd_version: "2.0.1"
ospd_openvas_version: "1.0.1"
```

Here's the actual compile process and the order in which things are compiled.


```
$ cat playbooks/openvas/install-gvm.yml
---
- import_playbook: install-debs.yml
- import_playbook: create-user.yml
- import_playbook: compile-gvm-libs.yml
- import_playbook: compile-openvas-smb.yml
- import_playbook: compile-openvas.yml
- import_playbook: configure-redis.yml
- import_playbook: compile-gvmd.yml
- import_playbook: configure-postgresql.yml
- import_playbook: configure-gvmd.yml
- import_playbook: compile-gsa.yml
- import_playbook: compile-ospd.yml
- import_playbook: start-gvm.yml
```

So, first you need to install all of the required debs. Not all of these are really required, some of them are only optional, but as I wrote before, this setup is designed to build all of the options. Then the Ansible script creates the required user account.

Next it's time to compile the first group of the source packages. The Ansible script downloads the correct .tar.gz and compiles it. Then it's time to configure Redis cache, which is needed by the system. And when Redis is up and running, it's time to compile & configure some more packages.

Let's look a bit more closely the file compile-gvm-libs.yml.

```
$ cat playbooks/openvas/compile-gvm-libs.yml
---
- hosts: scanners
  become: yes
  vars_files:
    - variables.yml
  tasks:
    - name: Create compile dirs
      file:
        path: /tmp/gvm
        state: directory
        owner: account
        mode: '0755'
    - name: Download GVM-libs tar.gz
      get_url:
        url: https://github.com/greenbone/gvm-libs/archive/v{{gvm_libs_version}}.tar.gz
        dest: /tmp/gvm/gvm-libs.tar.gz
    - name: Extract GVM-libs
      unarchive:
        src: /tmp/gvm/gvm-libs.tar.gz
        dest: /tmp/gvm
        remote_src: yes
    - name: Create build dir
      file:
        path: /tmp/gvm/gvm-libs-{{gvm_libs_version}}/build
        state: directory
    - name: Build GVM-libs
      command: "{{ item }} chdir=/tmp/gvm/gvm-libs-{{gvm_libs_version}}/build"
      with_items:
        - cmake -DCMAKE_INSTALL_PREFIX=/opt/gvm ..
        - make
        - make doc
      environment:
        PKG_CONFIG_PATH: /opt/gvm/lib/pkgconfig:$PKG_CONFIG_PATH
    - name: Install GVM-libs
      make:
        chdir: /tmp/gvm/gvm-libs-{{gvm_libs_version}}/build
        target: install
```

This file handles all hosts under [scanners] section in /etc/ansible/hosts, which includes openvas1 VM in this case. Then the script gets 'sudo root' access with the line 'become: yes'. Common variables, basically the version numbers, are read from variables.yml.

After that things are probably quite clear. All of these commands 'user, file, script' are documented quite thoroughly either in the official documentation or posts found via Google. All of those commands are doing things only if they need to be done. So if /tmp/gvm is already created, there is no need to create it again. 

Ansible is quite powerful tool. You can have loops (as shown above), conditionals, imports, etc. And the number of those plugins/commands is huge. You can set things in sysctl, configure systemd services, install packages, configure postgres, etc. Before you write an sh script, or even try plugin 'command' to run some direct command in command line, it's better to do some googling. In some cases Ansible even tries to educate you in a way 'Are you really sure that you want to use that ln -command? You probably would like to check the file-plugin.' Quite nice!


## ELK Stack

Taken from the website of the company (Elastic) behind ELK Stack (https://www.elastic.co/what-is/elk-stack):

"ELK" is the acronym for three open source projects: Elasticsearch, Logstash, and Kibana. Elasticsearch is a search and analytics engine. Logstash is a server-side data processing pipeline that ingests data from multiple sources simultaneously, transforms it, and then sends it to a "stash" like Elasticsearch. Kibana lets users visualize data with charts and graphs in Elasticsearch. 

So, three products, what's the required server and infra architecture? Shortly. It depends. Not so shortly. Calculating hardware specs for ELK Stack is... a complex topic, to put it mildly. When you google it, you'll get quite many thoughts and processes for calculations (or basically estimations). It's totally different thing if you're getting 100 logs/s or 100MB/day than 100 GB/day. And if you need to store them for 7 days not 2 years. 

Quite often there are one or more Logstash servers, at least three node Elasticsearch cluster (performance + high-availability) and one server for Kibana. For this document I tried to create 1 + 3 + 1 server configuration, but it's not possible with the free Azure subscription. So, Logstash + Kibana are installed on the same server and then there is 3 node Elasticsearch cluster just to show how it can be done.

These days there may also be Beats server in front of the Logstash and even Redis/Kafka/etc between Beats and Logstash.

Installing ELK Stack is much easier than installing OpenVAS, because Elastic provides deb packages. But configuring it to work properly in your own environment is much, much more difficult. Configuration files in this documentation are simple and probably not usable in the real life. There are some performance tunings for various components which I've taken from various HOWTOs on the Internet.

The architecture + configurations used in this documentation are relying heavily but not only to information provided in this quite thorough guide: https://logz.io/learn/complete-guide-elk-stack/

### Logstash

Installation is pretty straightforward. Install Java, add Logstash-repo and install it via apt install logstash. 

The configuration on the other hand is much more complex topic, and some ideas can be found from example here if the link above was not enough:

https://devconnected.com/how-to-install-logstash-on-ubuntu-18-04-and-debian-9/

### Elasticsearch
Installation is pretty straightforward also here. Install Java, add Elastic-repo and install it via apt install elasticsearch.

The configuration on the other hand is much more complex topic, and some ideas can be found from example here if the link above was not enough:

https://tecadmin.net/install-elasticsearch-on-debian/

### Kibana

Installation is the same as with ElasticSearch and Logstash.

Info about configuring it for example here: https://logz.io/blog/kibana-tutorial/

The configuration used in this HOWTO installs Kibana to the same server as Logstash. There is also a Nginx reverse proxy with self signed SSL certs in front of the Kibana. In the real life you would of course want to have real certificates, so please consult this documentation https://docs.ansible.com/ansible/latest/modules/openssl_certificate_module.html and update the playbooks/elk-stack/install-and-configure-kibana.yml accordingly. Ansible even provides methods for automating Let's Encrypt certificate usage. 



