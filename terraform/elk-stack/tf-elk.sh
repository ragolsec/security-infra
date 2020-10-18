#!/bin/sh
sudo echo "Creating ELK stack instances to Azure + updating /etc/hosts"
/opt/terraform/terraform apply -auto-approve
/opt/terraform/terraform output > ip_addresses.txt
./tf-elk-addresses.py
