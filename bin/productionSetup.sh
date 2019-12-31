#!/bin/bash

# Instructions to setup the server

####################################################
# Installing Nginx
####################################################

nginx() {
  # Main Source: http://www.howtoforge.com/install-nginx-on-centos-5.5-with-ssl-pcre-geoip-zlib-gzip-and-dav-support

  # Install C++ compiler required by PCRE
  yum -y install gcc gcc-c++ autoconf automake

  # Install packages required by Nginx
  yum -y install httpd-devel pcre perl pcre-devel zlib zlib-devel GeoIP GeoIP-devel

  mkdir -p /root/Download_and_Install && cd /root/Download_and_Install

  # You may want to get the latest version of these 3 installers
  wget ftp://ftp.csx.cam.ac.uk/pub/software/programming/pcre/pcre-8.33.tar.gz
  wget http://zlib.net/zlib-1.2.8.tar.gz
  wget ftp://ftp.openssl.org/source/openssl-1.0.1e.tar.gz

  tar xzf zlib-1.2.8.tar.gz
  tar xzf openssl-1.0.1e.tar.gz
  tar xzf pcre-8.33.tar.gz

  # You may want to get the latest version 
  wget http://nginx.org/download/nginx-1.5.7.tar.gz
  tar xzf nginx-1.5.7.tar.gz

  useradd nginx -d /usr/share/nginx -M -s /sbin/nologin

  cd nginx-1.5.7
  ./configure --user=nginx --group=nginx --prefix=/usr/share/nginx --sbin-path=/usr/sbin/nginx --conf-path=/etc/nginx/nginx.conf --error-log-path=/var/log/nginx/error.log --http-log-path=/var/log/nginx/access.log --http-client-body-temp-path=/var/lib/nginx/tmp/client_body --http-proxy-temp-path=/var/lib/nginx/tmp/proxy --http-fastcgi-temp-path=/var/lib/nginx/tmp/fastcgi --pid-path=/var/run/nginx.pid --lock-path=/var/lock/subsys/nginx --with-http_ssl_module --with-http_realip_module --with-http_addition_module --with-http_sub_module --with-http_dav_module --with-http_flv_module --with-http_gzip_static_module --with-http_stub_status_module --with-http_perl_module --with-mail --with-mail_ssl_module --with-openssl=/root/Download_and_Install/openssl-1.0.1e --with-pcre --with-pcre=/root/Download_and_Install/pcre-8.33 --with-zlib=/root/Download_and_Install/zlib-1.2.8 --with-http_geoip_module

  make
  # Go for a cup of coffee and check there is no error when you back
  make install

  mkdir -p /var/lib/nginx/tmp/client_body
  chown -R nginx.nginx /var/lib/nginx/
  chmod -R 770 /var/lib/nginx/
}

####################################################
# Installing Plank
####################################################

cpanm() {
  # Install cpanminus if not installed
  curl -L http://cpanmin.us | perl - --sudo App::cpanminus
}

perl_modules() {
  mkdir -p /root/Download_and_Install && cd /root/Download_and_Install

  # wget http://zlib.net/zlib-1.2.8.tar.gz
  # tar xzf zlib-1.2.8.tar.gz
  # cd zlib-*
  # ./configure
  # make && make install

  # wget ftp://ftp.openssl.org/source/openssl-1.0.1e.tar.gz
  # tar xzf openssl-1.0.1e.tar.gz
  # cd openssl-*
  # ./config
  # make
  # make test
  # make install

  yum -y install gmp.x86_64 gmp-devel.x86_64 perl-Math-GMP.x86_64
  yum -y install gcc gcc-c++ autoconf automake
  yum -y install httpd-devel pcre perl pcre-devel zlib zlib-devel GeoIP GeoIP-devel

  /usr/local/bin/cpanm App::cpanoutdated
  /usr/local/bin/cpan-outdated -p | /usr/local/bin/cpanm

  yum -y install libssh2 
  mkdir -p /root/Download_and_Install && cd /root/Download_and_Install  
  wget ftp://rpmfind.net/linux/centos/6.4/os/x86_64/Packages/libssh2-devel-1.4.2-1.el6.x86_64.rpm
  rpm -Uvh libssh2-devel-1.4.2-1.el6.x86_64.rpm

  /usr/local/bin/cpanm Dancer Dancer::Plugin::Database Dancer::Plugin::FlashMessage Dancer::Session::Cookie
  /usr/local/bin/cpanm Template Data::SpreadPagination YAML
  /usr/local/bin/cpanm IO::Socket::SSL Crypt::SaltedHash
  /usr/local/bin/cpanm Net::SCP Net::SFTP::Foreign Net::SSH2 Net::SCP::Expect
  /usr/local/bin/cpanm Task::Plack 
  # TODO: Remove Net::SCP::Expect, it is not required.
}

os_update() {
  yum clean all && yum clean metadata && yum clean dbcache && yum makecache && yum update -y
}

git() {
  yum -y install zlib-devel openssl-devel cpio expat-devel gettext-devel git
}

mysql() {
  yum -y install mysql-server
  #/etc/init.d/mysqld start
  service mysqld start
  /usr/bin/mysql_secure_installation
  # current root password is none (press enter). Then set a new password for root 'P0l1t1c5'
  mysql -p <<'SQL'
CREATE DATABASE IF NOT EXISTS ftg;
SHOW DATABASES;
CREATE USER 'ftg'@'localhost' IDENTIFIED BY 'YPftg4all';
GRANT ALL PRIVILEGES ON ftg.* TO 'ftg'@'localhost' WITH GRANT OPTION;
SQL
  mysql -p <<'SQL2'
SELECT 'Databases: ';
SHOW DATABASES;
SELECT 'Users: ';
SELECT User FROM mysql.user;
SELECT 'Grants: ';
SHOW GRANTS;
SELECT 'User ftg grants: ';
SHOW GRANTS FOR 'ftg'@'localhost';
SQL2
}

apache() {
  yum -y install httpd mod_ssl mod_perl httpd-devel

  cat <<'VIRTUALHOST' > /etc/httpd/conf.d/doxTG.conf
<VirtualHost *:80>
    ServerName flph068.ffdc.sbc.com
    DocumentRoot /opt/FTG/doxTG
    ServerAdmin ja6351@yp.com

    SetEnv DANCER_ENVIRONMENT "production"

    <Directory "/opt/FTG/doxTG">
        AllowOverride None
        Options +ExecCGI -MultiViews +SymLinksIfOwnerMatch
        Order allow,deny
        Allow from all
        AddHandler fastcgi-script .fcgi
    </Directory>

    ScriptAlias / /opt/FTG/doxTG/public/dispatch.fcgi
    <Location />
        SetHandler perl-script
        PerlHandler Plack::Handler::Apache2
        PerlSetVar psgi_app /opt/FTG/doxTG/bin/server.pl
    </Location>

    ErrorLog  /var/log/httpd/doxTG-error.log
    CustomLog /var/log/httpd/doxTG-access_log common
</VirtualHost>  
VIRTUALHOST
  cat /etc/httpd/conf.d/doxTG.conf
  apachectl configtest
}


fastcgi(){
  yum -y install libtool httpd-devel apr-devel apr

  mkdir -p /root/Download_and_Install && cd /root/Download_and_Install

  wget http://www.fastcgi.com/dist/mod_fastcgi-current.tar.gz
  tar -zxvf mod_fastcgi-current.tar.gz && cd mod_fastcgi-*/
  cp Makefile.AP2 Makefile
  make top_dir=/usr/lib64/httpd
  make install top_dir=/usr/lib64/httpd
  echo "LoadModule fastcgi_module modules/mod_fastcgi.so" > /etc/httpd/conf.d/mod_fastcgi.conf
  apachectl configtest
}

doxTG(){
  useradd ftg -d /opt/FTG -c "doxTG User" -u 10002 -g 1007
  usermod -G 1007 apache
  chmod 775 /opt/FTG
  su - ftg
  echo "export DANCER_ENVIRONMENT=production" >> ~/.bash_profile
  ssh-keygen -C "ftg@yp.com" 
  chmod 755 .ssh/
  #cat ~/.ssh/id_rsa.pub | ssh git@fltva073.ffdc.sbc.com 'cat >> ~/.ssh/authorized_keys'
  ssh-copy-id -i ~/.ssh/id_rsa.pub git@fltva073.ffdc.sbc.com
  git clone git@fltva073.ffdc.sbc.com:/opt/git/FTG.git
  mv FTG doxTG 
  chmod 775 /opt/FTG/doxTG 
  cd doxTG
  # mkdir logs
  mkdir var
  mkdir tmp
  > logs/production.log
  > logs/access.log
  mysql -u ftg -p ftg < db/production.init.mysql.sql
  cd db/
  rm id_rsa
  rm id_rsa.pub
  ln -s ~/.ssh/id_rsa
  ln -s ~/.ssh/id_rsa.pub
  # Send public keys to servers:
  servers='ja6351@135.161.22.132 ja6351@135.161.22.100 soper@135.161.22.156 ftg@150.234.133.48'
  for server in $servers
  do
    ssh-copy-id -i ~/.ssh/id_rsa.pub $server
  done
  exit
}

main() {
  os_update
  git
  cpanm
  mysql
  apache
  # nginx
  fastcgi
  perl_modules
  doxTG
  /etc/init.d/httpd restart
  echo "Open a Browser with http://flph068.ffdc.sbc.com/ or http://fltva073.ffdc.sbc.com/"
}