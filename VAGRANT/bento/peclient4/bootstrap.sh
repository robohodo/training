#!/bin/bash

# Inject custom fact

touch /.tomcat.server

# Update /etc/hosts 
cat >> /etc/hosts << EOF 
192.168.140.128 robows-puppet.localdomain robows-puppet #00 0c 29 b5 b5 86 
192.168.140.129 robows-jenkins.localdomain robows-jenkins #00 0c 29 2d 43 fb
192.168.0.3 robows.localdomain robows #90 b1 1c 7a a7 c7
EOF

#Remove NetworkManager 
yum -y remove NetworkManager

#Install bind-8tils
yum -y install bind-utils  

# Update OS
yum -y update

# Register with puppet 
curl -k https://robows-puppet.localdomain:8140/packages/current/install.bash | bash

#Reboot 
/sbin/shutdown -r now 
