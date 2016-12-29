#!/bin/bash

# Inject custom fact

touch /.apache_httpd.server

# Register with puppet 
curl -k https://robows-puppet.localdomain:8140/packages/current/install.bash | bash

# Update OS
yum -y update

