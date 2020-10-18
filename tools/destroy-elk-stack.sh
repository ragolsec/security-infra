#!/bin/sh
cd /opt/security-infra/terraform/elk-stack/

echo "Deleting ELK Stack from Azure"
/opt/terraform/terraform destroy --auto-approve 
