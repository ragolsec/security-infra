#!/bin/sh
sudo systemctl enable logstash
sudo systemctl start logstash
systemctl restart rsyslog
