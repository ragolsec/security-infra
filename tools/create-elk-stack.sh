#!/bin/sh
cd /opt/security-infra/terraform/elk-stack/

echo "Adding ssh-key to ssh-agent, so there is no need to input the password every time"

eval $(ssh-agent -s)
ssh-add

# Adding sudo for this part so the password is asked from the start...
sudo echo 
echo "Creating VMs to Azure"
/opt/terraform/terraform apply --auto-approve
/opt/terraform/terraform output > ip_addresses.txt
./tf-elk-addresses.py

ssh-keyscan -H elk-logstash1 > ~/.ssh/known_hosts
ssh-keyscan -H elk-elastic1 >> ~/.ssh/known_hosts
ssh-keyscan -H elk-elastic2 >> ~/.ssh/known_hosts
ssh-keyscan -H elk-elastic3 >> ~/.ssh/known_hosts


cd /opt/security-infra/playbooks/elk-stack
ansible-playbook install-and-configure-elasticsearch.yml
ansible-playbook install-and-configure-logstash.yml
ansible-playbook install-and-configure-kibana.yml

