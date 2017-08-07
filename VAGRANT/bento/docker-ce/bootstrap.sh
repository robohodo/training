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
#yum -y install bind-utils tree docker golang 
yum -y install bind-utils tree  yum-utils golang  git

#Nameserver 10.0.2.3 returns bogus IP addresses for VM's. 
#Removing from /etc/resolv.conf so we can register with puppet. 
#A bad hack. But necessary for now. 

sed -i 's/DEFROUTE=yes/DEFROUTE=no/' /etc/sysconfig/netwrok-scripts/ifcfg-enp0s3
sed -i 's/PEERDNS=yes/PEERDNS=no/' /etc/sysconfig/netwrok-scripts/ifcfg-enp0s3

# Register with puppet 
#curl -k https://robows-puppet.localdomain:8140/packages/current/install.bash | bash

# install docker 
yum-config-manager --add-repo \
    https://download.docker.com/linux/centos/docker-ce.repo
yum -y install docker-ce
systemctl enable docker 
systemctl start docker 

#Allow vagrant to run docker commands
usermod -G docker vagrant 

#Setup for Steve's docker traing. 


cat >> /home/vagrant/setup_docker_training.sh << EOF
mkdir GIT
cd GIT
git clone https://github.com/chesshacker/docker-training.git
docker pull alpine
docker pull nginx
docker pull node
docker pull python:3-alpine
docker pull openjdk:jre-alpine
docker pull mysql:5.7
docker pull wordpress
docker pull postgres
docker pull ruby:2.4
EOF
su - vagrant -c " sh /home/vagrant/setup_docker_training.sh "

# Update OS
yum -y update

reboot
