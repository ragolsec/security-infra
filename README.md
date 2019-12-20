# security-infra
## Documentation for installing security tools automatically

This document describes how to install security scanner X to a virtual machine running in Azure using Ansible as the automation tool. The documentation is based around Centos 8 and assumes that you already have a Centos 8 machine up and running. 

CentOS 8 can be downloaded from: https://centos.org/download/

### Install Ansible to Centos 8.

Ansible is available from epel-repository, so you need to first enable it.

```
$ sudo yum install -y epel-release
```

After epel-repository has been enabled, you can install ansible. It will install also some additional python-packages.

```
$ sudo yum install -y ansible
```

Create ansible hosts list by adding scanner1 to /etc/ansible/hosts under scanners section which you also added.

[scanners]
scanner1


Create SSH keys to be used for ansible

```
$ ssh-keygen -t rsa -b 4096 -C "ansible"
```

For location of the key files, just press enter to accept the default location. For SSH passphrase it is good practice to select secure passphrase. 

Add ssh keys with passphrase to the ssh-agent

```
$ ssh-add
```

It will ask your passphrase, and add the key. After this copy the public part of the key to the destination machine.

```
[account@ansible ~]$ ssh-copy-id account@scanner1
/usr/bin/ssh-copy-id: INFO: attempting to log in with the new key(s), to filter out any that are already installed
/usr/bin/ssh-copy-id: INFO: 1 key(s) remain to be installed -- if you are prompted now it is to install the new keys
account@scanner1's password:

Number of key(s) added: 1

Now try logging into the machine, with:   "ssh 'account@scanner1'"
and check to make sure that only the key(s) you wanted were added.
```

Now you can check whether ansible works or not 

```
$ ansible all -m ping
```
