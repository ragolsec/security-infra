#!/usr/bin/python3
target_url = "https://releases.hashicorp.com/terraform/"
import urllib.request
data = urllib.request.urlopen(target_url)

version = 0

for line in data:
    line = line.decode("utf-8")
    index = line.find('/terraform/')
    if (index != -1):
        version = line.split("/")[2]
        print(version)
        break

