#!/bin/bash

# Inject custom fact

touch /.tomcat.server

# Update /etc/hosts 
cat >> /etc/hosts << EOF 
192.168.140.128 robows-puppet.localdomain robows-puppet #00 0c 29 b5 b5 86 
192.168.140.129 robows-jenkins.localdomain robows-jenkins #00 0c 29 2d 43 fb
192.168.0.3 robows.localdomain robows #90 b1 1c 7a a7 c7
EOF

cat >>/home/vagrant/.ssh/authorized_keys << EOF
ssh-rsa AAAAB3NzaC1yc2EAAAADAQABAAABAQDGxvCj177Dk6jQvIgfDsD+tqgE8/QjmVEc+iRwhBj65jdkDcPWIQYzyOCt+uWAEeNl4CMmQ/7kv27nDZKIMqxPtzXqQeUgHjfOJ7/aajEx9BkWl71DQhrmGjYdd2ft1jvJDK68JCLRuJ4TgwPl1dTSe5gqucKytirCpS7IqfuC4j04Sg1VON/VcOcfxgCrO+CHmx/rs2kTFPTHBgIq6DbrQOkhHTz+JR/EV/vfc7Ta7iAKL0iqxV3VMbu2yKQd4AnWOy8vZku2KjRrwIIB1Hr2l3zpuEqM8i70kUW4zyGeieud8nXgnE0NWMN54fAMfSTBlo94YmBFCcGua6LnPQGd rhodo@robows.localdomain
EOF

#Install extra software.
yum -y install bind-utils tree docker golang 

#Nameserver 10.0.2.3 returns bogus IP addresses for VM's. 
#Removing from /etc/resolv.conf so we can register with puppet. 
#A bad hack. But necessary for now. 

sed -i 's/DEFROUTE=yes/DEFROUTE=no/' /etc/sysconfig/netwrok-scripts/ifcfg-enp0s3
sed -i 's/PEERDNS=yes/PEERDNS=no/' /etc/sysconfig/netwrok-scripts/ifcfg-enp0s3

# Register with puppet 
#curl -k https://robows-puppet.localdomain:8140/packages/current/install.bash | bash

# Update OS
yum -y update

