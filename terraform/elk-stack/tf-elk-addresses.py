#!/usr/bin/python
import os

ipfile = open("ip_addresses.txt", "r")

data = ipfile.readlines()

ipfile.close()

index = ""

for i,val in enumerate(data):
    if(val.find('public_ip_address_hostname') <> -1):
        index = i

number_of_addresses = index-1

for i in range(1,number_of_addresses):
    hostname = data[i+number_of_addresses+1][3:-3].split("-")[2]
    ip = data[i][3:-3]
    #line = data[i][3:-3] + " " + data[i+number_of_addresses+1][3:-3].split("-")[2]
    os.system('sudo sed -i "/' + hostname + '/c\\' + ip + ' elk-' + hostname + '" /etc/hosts')
