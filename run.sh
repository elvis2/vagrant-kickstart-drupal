#!/bin/bash

# Run all of the installation as vagrant user. If we need to install something
# as root instal with sudo.
su -c "bash /vagrant/kickstart.sh  2>&1 | tee -a /vagrant/logs/kickstart-install.log" vagrant
