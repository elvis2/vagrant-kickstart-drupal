#!/bin/bash

## The last password you'll ever need.
# add current user to sudoers file - careful, this line could brick the box.
echo "$USER ALL=(ALL) NOPASSWD: ALL" | sudo tee -a /etc/sudoers.d/vagrant > /dev/null
sudo chmod 0440 /etc/sudoers.d/vagrant

# Add current user to root 'group' to make it easier to edit config files
# note: seems unsafe for anyone unaware.
sudo adduser $USER www-data
sudo adduser $USER root
sudo adduser $USER admin

## Disk size Accounting
# Starting size:
df -h -T > /vagrant/logs/kickstart-size-start.txt

# # Remove the standard Kernel and install virtual kernel.
# # Should be less overhead (aka better performance) in Virtual environment.
# sudo apt-get -yq update
# sudo apt-get -yq purge linux-generic linux-headers-generic linux-image-generic linux-generic-pae  linux-image-generic-pae linux-headers-generic-pae linux-headers-3.2.0-23 linux-headers-3.2.0-23-generic-pae linux-image-3.2.0-23-generic-pae
# sudo apt-get -yq install linux-virtual linux-headers-virtual linux-image-virtual
sudo apt-get -yq update
# sudo apt-get -yq upgrade

# ################################################################################ Drupal sites

# Create a directory for websites to live in.
mkdir ~/websites

# Create directories for logs to live in.
mkdir ~/websites/logs
mkdir ~/websites/logs/mail
mkdir ~/websites/logs/profiler
mkdir ~/websites/logs/xhprof

# Change ownership and permissions on the new directories.
sudo chown :www-data ~/websites
sudo chmod -R ug=rwX,o= ~/websites

# ##### Install LAMP packages

# Define package names, and debconf config values.  Keep package names in sync.
LAMP_APACHE="libapache2-mod-php5 php-pear"
LAMP_MYSQL="mysql-server libmysqlclient18 mysql-common"
#LAMP_PHP="php5 php5-dev php5-common php5-xsl php5-curl php5-gd php5-pgsql php5-cli php5-mcrypt php5-sqlite php5-mysql php-pear php5-imap php5-xdebug php-apc"
LAMP_PHP="php5 php-apc php5-cli php5-curl php5-gd php5-imap php5-mysql php5-mcrypt php5-sqlite php5-xdebug php5-xsl"
LAMP_TOOLS="phpmyadmin"
MISC="unzip zip"

echo mysql-server-5.5 mysql-server/root_password        password kickstart | sudo debconf-set-selections
echo mysql-server-5.5 mysql-server/root_password_again  password kickstart | sudo debconf-set-selections
echo phpmyadmin       phpmyadmin/reconfigure-webserver  text     apache2    | sudo debconf-set-selections
echo phpmyadmin       phpmyadmin/dbconfig-install       boolean  true       | sudo debconf-set-selections
echo phpmyadmin       phpmyadmin/app-password-confirm   password kickstart | sudo debconf-set-selections
echo phpmyadmin       phpmyadmin/mysql/admin-pass       password kickstart | sudo debconf-set-selections
echo phpmyadmin       phpmyadmin/password-confirm       password kickstart | sudo debconf-set-selections
echo phpmyadmin       phpmyadmin/setup-password         password kickstart | sudo debconf-set-selections
echo phpmyadmin       phpmyadmin/mysql/app-pass         password kickstart | sudo debconf-set-selections

# Now install the packages.  debconf shouldn't need to ask so many questions.
sudo apt-get -yq install $LAMP_APACHE $LAMP_MYSQL $LAMP_PHP $LAMP_TOOLS $MISC
sudo mysqladmin -u root 'kickstart'

# ###### Configure APACHE
sudo a2enmod ssl
sudo a2enmod rewrite
sudo a2dismod cgi
sudo a2dismod autoindex

# configure default site
echo "<VirtualHost *:80>
  DocumentRoot /var/www
  <Directory /var/www/>
    Options Indexes FollowSymLinks MultiViews
    AllowOverride All
    Order allow,deny
    allow from all
  </Directory>
</VirtualHost>" | sudo tee /etc/apache2/sites-available/000-default  > /dev/null
sudo a2ensite 000-default

# Fix ssl for easier virtual hosting
echo "NameVirtualHost *:80
Listen 80
<IfModule mod_ssl.c>
    NameVirtualHost *:443
    Listen 443
</IfModule>" | sudo tee /etc/apache2/ports.conf > /dev/null

echo "<IfModule mod_ssl.c>
<VirtualHost *:443>
  ServerAdmin webmaster@localhost
  DocumentRoot /var/www
  <Directory />
    Options FollowSymLinks
    AllowOverride None
  </Directory>
  <Directory /var/www/>
    Options Indexes FollowSymLinks MultiViews
    AllowOverride None
    Order allow,deny
    allow from all
  </Directory>
  SSLEngine on
  SSLCertificateFile    /etc/ssl/certs/ssl-cert-snakeoil.pem
  SSLCertificateKeyFile /etc/ssl/private/ssl-cert-snakeoil.key
</VirtualHost>
</IfModule>" | sudo tee /etc/apache2/sites-available/default-ssl > /dev/null
sudo a2ensite default-ssl


# ################################################################################ Configure MYSQL

sudo sed -i 's/#log_slow_queries/log_slow_queries/g'          /etc/mysql/my.cnf
sudo sed -i 's/#long_query_time/long_query_time/g'            /etc/mysql/my.cnf

# ################################################################################ Configure PHP
# FIXME haven't checked for unnecessary code since 9.10
# sudo sed -i 's/find_this/replace_with_this/g' infile1 infile2 etc
sudo sed -i 's/magic_quotes_gpc = On/magic_quotes_gpc = Off/g'                       /etc/php5/apache2/php.ini /etc/php5/cli/php.ini
sudo sed -i 's/short_open_tag = On/short_open_tag = Off/g'                           /etc/php5/apache2/php.ini /etc/php5/cli/php.ini
sudo sed -i 's/max_execution_time = 30/max_execution_time = 300/g'                   /etc/php5/apache2/php.ini /etc/php5/cli/php.ini
sudo sed -i 's/memory_limit = 16M/memory_limit = 64M/g'                              /etc/php5/apache2/php.ini /etc/php5/cli/php.ini
sudo sed -i 's/memory_limit = 32M/memory_limit = 64M/g'                              /etc/php5/apache2/php.ini /etc/php5/cli/php.ini
sudo sed -i 's/upload_max_filesize = 2M/upload_max_filesize = 50M/g'                 /etc/php5/apache2/php.ini /etc/php5/cli/php.ini
sudo sed -i 's/post_max_size = 8M/post_max_size = 50M/g'                             /etc/php5/apache2/php.ini /etc/php5/cli/php.ini
sudo sed -i 's/;error_log = filename/error_log = \/var\/log\/php-error.log/g'        /etc/php5/apache2/php.ini /etc/php5/cli/php.ini # php 5.2
sudo sed -i 's/;error_log = php_errors.log/error_log = \/var\/log\/php-error.log/g'  /etc/php5/apache2/php.ini /etc/php5/cli/php.ini # php 5.3
sudo sed -i 's/display_errors = Off/display_errors = On/g'                           /etc/php5/apache2/php.ini /etc/php5/cli/php.ini
sudo sed -i 's/display_startup_errors = Off/display_startup_errors = On/g'           /etc/php5/apache2/php.ini /etc/php5/cli/php.ini

# Fix comment bug that will show warning on command line
sudo sed -i 's/# /\/\/ /g'            /etc/php5/cli/conf.d/mcrypt.ini
sudo sed -i 's/# /\/\/ /g'            /etc/php5/cli/conf.d/imap.ini

# Install upload progress (warning in D7)
sudo pecl -q install uploadprogress
echo "extension=uploadprogress.so" | sudo tee /etc/php5/apache2/conf.d/uploadprogress.ini > /dev/null

# ###### Restart web server
sudo service mysql restart
sudo /etc/init.d/apache2 restart

# ################################################################################ Configure phpmyadmin
# show hex data on detail pages.
echo "
# Show 1000 rows instead of 30 by default
\$cfg['MaxRows'] = 1000;
# Show BLOB data as a string not hex.
\$cfg['DisplayBinaryAsHex'] = false;
# Show BLOB data in row detail pages.
\$cfg['ProtectBinary'] = false;
# Show BLOB data on table browse pages.  Hack to hardcode all requests.
\$_REQUEST['display_blob'] = true;
" | sudo tee -a /etc/phpmyadmin/config.inc.php

# never log me out!
echo "
/*
* Prevent timeout for a year at a time.
* (seconds * minutes * hours * days * weeks)
*/
\$cfg['LoginCookieValidity'] = 60*60*24*7*52;
ini_set('session.gc_maxlifetime', \$cfg['LoginCookieValidity']);
" | sudo tee -a /etc/phpmyadmin/config.inc.php


# ################################################################################ user management

echo "This is where Quickstart websites go.

Quickstart includes some command line scripts to automate site creation.

To create a site (dns, apache, code, database, and install):

  1) Start a terminal (top left icon, click the black box with a [>_] )

  2) Paste in this command (don't include the $)
    $ drush kickstart-create --domain=newsite.dev
         or
    $ drush qc --domain=newsite.dev

To delete a site:
  $ drush kickstart-delete --domain=newsite.dev
         or
  $ drush qd --domain=newsite.dev

For more information:
  $ drush help kickstart-create
  $ drush help kickstart-destroy
  Or goto http://drupal.org/node/819398" > ~/websites/README.txt


# ################################################################################ Drush
# Install drush

sudo apt-get -yq install drush
sudo drush dl -y drush-7.x-5.x-dev --destination='/usr/share'

# Install drush kickstart
mkdir ~/.drush
mkdir ~/.drush/kickstart

cp /vagrant/drush/* ~/.drush/kickstart/
cp /vagrant/make_templates/*.make ~/websites

# ################################################################################ Email catcher

# Configure email collector
mkdir ~/config
chmod -R 770 /home/vagrant/websites/logs/mail
sudo sed -i 's/;sendmail_path =/sendmail_path=\/home\/vagrant\/config\/sendmail.php/g' /etc/php5/apache2/php.ini /etc/php5/cli/php.ini
chmod +x /home/vagrant/config/sendmail.php

# ################################################################################ XDebug Debugger/Profiler

# Configure xdebug - installed 2.1 from apt
mkdir /home/vagrant/websites/logs/profiler
echo "
xdebug.remote_enable=on
xdebug.remote_handler=dbgp
xdebug.remote_host=localhost
xdebug.remote_port=9000
xdebug.profiler_enable=0
xdebug.profiler_enable_trigger=1
xdebug.profiler_output_dir=/home/vagrant/websites/logs/profiler
" | sudo tee -a /etc/php5/conf.d/xdebug.ini > /dev/null


# ################################################################################ Install a web-based profile viewer
cd ~/websites/logs/profiler

wget -nv -O webgrind.zip http://webgrind.googlecode.com/files/webgrind-release-1.0.zip
unzip webgrind.zip
rm webgrind.zip

# Setup Web server
echo "127.0.0.1 webgrind

" | sudo tee -a /etc/hosts > /dev/null

echo "Alias /profiler /home/vagrant/websites/logs/profiler/webgrind

<Directory /home/vagrant/websites/logs/profiler/webgrind>
  Allow from All
</Directory>
" | sudo tee /etc/apache2/conf.d/webgrind > /dev/null

chmod -R 770 /home/vagrant/websites/logs/profiler


# ################################################################################ XHProf profiler (Devel Module)
# Adapted from: http://techportal.ibuildings.com/2009/12/01/profiling-with-xhprof/

# supporting packages
sudo apt-get -yq install graphviz

# get it
cd ~
mkdir /home/vagrant/websites/logs/xhprof

wget -nv http://pecl.php.net/get/xhprof-0.9.2.tgz
tar xvf xhprof-0.9.2.tgz
mv xhprof-0.9.2 /home/vagrant/websites/logs/xhprof
rm xhprof-0.9.2.tgz
rm package.xml

# build and install it
cd /home/vagrant/websites/logs/xhprof/extension/
phpize
./configure
make
sudo make install

# configure php
echo "
[xhprof]
extension=xhprof.so
xhprof.output_dir=\"/home/vagrant/websites/logs/xhprof\"
" | sudo tee /etc/php5/conf.d/xhprof.ini > /dev/null

# configure apache
echo "Alias /xhprof /home/vagrant/websites/logs/xhprof/xhprof_html

<Directory /home/vagrant/websites/logs/profiler/xhprof/xhprof_html>
  Allow from All
</Directory>
" | sudo tee /etc/apache2/conf.d/xhprof > /dev/null

chmod -R 770 /home/vagrant/websites/logs/xhprof


# ################################################################################ Restart apache
sudo apache2ctl restart
