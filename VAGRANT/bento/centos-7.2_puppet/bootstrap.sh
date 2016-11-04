#!/bin/bash

# Inject custom fact

touch /.tomcat_server

# Register with puppet 
curl -k https://robows-puppet.localdomain:8140/packages/current/install.bash | bash

# Update OS
yum -y update

