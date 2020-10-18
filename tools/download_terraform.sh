#!/bin/sh
TER_VER=$(python3 check_terraform_version.py)
cd ~
wget https://releases.hashicorp.com/terraform/${TER_VER}/terraform_${TER_VER}_linux_amd64.zip
unzip terraform_${TER_VER}_linux_amd64.zip
sudo mkdir -p /opt/terraform
sudo mv terraform /opt/terraform
sudo ln -s /opt/terraform/terraform /usr/bin/terraform
