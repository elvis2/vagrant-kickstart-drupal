#!/bin/bash

su -c "bash /vagrant/kickstart.sh  2>&1 | tee -a /vagrant/logs/kickstart-install.log" vagrant
