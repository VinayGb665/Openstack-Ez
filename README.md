# Openstack-Ez ![Build Status](https://travis-ci.org/cazala/coin-hive.svg?branch=master)

## Openstack (Ocata) installation made easy



**Please not that the project is not completely stable and has some prerequisites**

## Prerequisites
* The script does not take care of configuring networking .That has to be done by the user.
* Need root/administrator access
* Works only on Xenial systems
## How to use
* Clone the repo into your machine
* Open the script.sh in any desired text editor
* Find and replace the string "C_SERVER" with your controller IP address
* Find and replace the string "secret" with a preffered common password 
* Open /etc/hosts as root and add your ip address with hostname as controller
* Your /etc/hosts file should look something like this (assuming 10.10.1.10 as my controller ip)
```
127.0.0.1       localhost
127.0.1.1       XYZ
10.10.1.10      controller
# The following lines are desirable for IPv6 capable hosts
::1     ip6-localhost ip6-loopback
ffff::f ip6-localnet
ffff::f ip6-mcastprefix
ffff::f ip6-allnodes
ffff::f ip6-allrouters



```

* Run the script as follows

```
#. script.sh

```
## Notes
* The script doesnt install neutron (Still under construction)
* Only the controller node for swift is installed and configured
