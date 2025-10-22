#!/bin/bash
set -e

# Update
apk update -q -U
apk upgrade -q -U -a

apk add --update rsync
apk add --update inotify-tools
# Nginx
apk add --update nginx

# PHP
apk add --update php82
apk add --update php82-curl
apk add --update php82-fileinfo
apk add --update php82-fpm
apk add --update php82-gd
apk add --update php82-iconv
apk add --update php82-json
apk add --update php82-opcache
apk add --update php82-mysqli php82-mysqlnd
apk add --update php82-mbstring
apk add --update php82-simplexml
apk add --update php82-xml
apk add --update php82-xmlwriter
apk add --update php82-xmlreader

apk add --update php82-session
apk add --update php82-openssl
apk add --update php82-intl

apk add --no-cache curl

# Runit (services)
apk add --update runit

# Bash
apk add --update bash

# PHP alias
ln -s /usr/bin/php82 /usr/bin/php

# Clear
rm -rf /var/cache/apk/*

# PHP
#####

#!/bin/bash
set -e

# PHP ini
echo "
short_open_tag = Off;
display_errors = Off;
allow_url_fopen = On;

memory_limit = 32M;
post_max_size = 10M;
upload_max_filesize = 10M;
max_file_uploads = 10M;
max_execution_time = 60;
cgi.fix_pathinfo = 0;

session.use_trans_sid = 0;
session.use_only_cookies = 1;
session.hash_function = sha512;
session.hash_bits_per_character = 5;
session.entropy_file = /dev/urandom;
session.entropy_length = 256;
session.cookie_httponly = 1;
" >> /etc/php82/php.ini

# PHP fpm
echo "
[global]
emergency_restart_threshold = 3
emergency_restart_interval = 1m
process_control_timeout = 5s

[www]
listen = /var/run/php-fpm.sock
listen.mode = 0666
listen.allowed_clients = 127.0.0.1
access.log = /dev/null" > /etc/php82/php-fpm.d/www.conf


# Services
##########

# Nginx service
mkdir /etc/service/nginx
echo "#!/bin/sh
exec 2>&1
exec /usr/sbin/nginx -c /etc/nginx/nginx.conf -g \"daemon off;\"" > /etc/service/nginx/run
chmod +x /etc/service/nginx/run

# Php service
mkdir /etc/service/php82
echo "#!/bin/sh
exec 2>&1
exec /usr/sbin/php-fpm82 -R -c /etc/php82/php.ini -y /etc/php82/php-fpm.conf --nodaemonize"  > /etc/service/php82/run
chmod +x /etc/service/php82/run


# Clean
rm -rf /tmp/*