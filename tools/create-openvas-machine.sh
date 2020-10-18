#!/bin/sh

eval $(ssh-agent -s)
# Using sudo, so we have sudo rights when they are needed.
sudo echo
echo "Adding SSH key to SSH agent, so there is no need to input SSH key passphrase all the time"
echo
ssh-add

cd /opt/security-infra/terraform/openvas/

echo
echo "Creating VM to Azure"
/opt/terraform/terraform apply --auto-approve | grep ip_address > ip_address.txt
sed -i 's/ip_address = //' ip_address.txt
sed -i 's/\x1b\[[0-9;]*[a-zA-Z]//g' ip_address.txt
IP=`cat ip_address.txt`


# Check if we already have openvas1 in /etc/hosts, and change its IP if it's there.
# If it's not, add it.
export TEST_STR=""
TEST_STR=$(grep openvas /etc/hosts)

if [ "$TEST_STR" = "" ]
then
  echo "$IP openvas1" | sudo tee -a /etc/hosts
else
  sudo sed -i "/openvas1/c\\$IP openvas1" /etc/hosts
fi

echo 
echo "Azure VM created and available via ssh@openvas1. /etc/hosts is updated."
echo 
echo "Adding host to ~/.ssh/known_hosts"

ssh-keyscan -H openvas1 > ~/.ssh/known_hosts

echo "Installing OpenVAS/GVM to the openvas1 -server via Ansible scripts"

ansible-playbook /opt/security-infra/playbooks/openvas/install-gvm.yml
