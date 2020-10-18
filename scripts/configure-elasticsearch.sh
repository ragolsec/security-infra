#!/bin/sh
sysctl -w vm.max_map_count=262144
sysctl -p /etc/sysctl.conf
chown -R elasticsearch:elasticsearch /usr/share/elasticsearch
echo "10.2.1.5 elk-elastic1" >> /etc/hosts
echo "10.2.1.6 elk-elastic2" >> /etc/hosts
echo "10.2.1.7 elk-elastic3" >> /etc/hosts
systemctl daemon-reload
systemctl enable elasticsearch
systemctl start elasticsearch
