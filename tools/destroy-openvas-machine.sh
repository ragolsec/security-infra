#!/bin/sh
cd /opt/security-infra/terraform/openvas/

echo "Deleting OpenVAS VM from Azure"
/opt/terraform/terraform destroy --auto-approve 
