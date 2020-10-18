#!/bin/sh

echo "Installing ansible, you may need to input sudo password"
sudo apt install ansible

ssh-keygen -t rsa -b 4096 -C "ansible"

