#!/bin/bash
set -e
#--------------------------------------------------------------------
#-- Configuration
#--------------------------------------------------------------------

# Application file directory
export APP_DIR="/app"

# Service user
export USER="app"

# Document root in the APP_DIR
export STATIC_DIR=""

# Server RAM
# memory_free=$(free -m | awk 'NR==2{printf $2}')
# memory_limit=$(expr $(cat /sys/fs/cgroup/memory.max) / 1024 / 1024)
# export RAM=$(($memory_limit > $memory_free ? $memory_free : $memory_limit))

# Maximum upload size in Megabytes
export UPLOAD_MAX="50"

# Check if the app dir exists, or create it
if [ ! -d "$APP_DIR" ]; then
	mkdir -p "$APP_DIR"
fi

# Fix app dir permissions
find "$APP_DIR" -type d -exec chmod 750 {} \;
find "$APP_DIR" -type f -exec chmod 640 {} \;
chown -R "$USER:$USER" "$APP_DIR"


# Nginx
#######

#!/bin/bash
set -e

# Create a defaut nginx configuration
max_threads=12

echo "
user root $USER;
worker_processes auto;
worker_rlimit_nofile 8192;

events {
	worker_connections $max_threads;
}

http {
	include		/etc/nginx/mime.types;
	include		/etc/nginx/fastcgi.conf;
	
	index		index.php index.html index.htm;
	autoindex	off;
	
	default_type	text/html;
	error_log		/dev/stderr info;
	access_log		off;
	sendfile		off;
	tcp_nopush		on;
	server_tokens	off;
	
	# Gzip
	gzip on;
	gzip_disable \"msie6\";
	gzip_vary on;
	gzip_proxied any;
	gzip_comp_level 6;
	gzip_buffers 16 8k;
	gzip_http_version 1.1;
	gzip_types text/plain text/xml text/html text/css text/tab-separated-values text/csv text/javascript image/svg+xml application/xhtml+xml application/xml application/rss+xml application/x-javascript application/javascript application/json;
	
	# woff2
	types {
    	application/font-woff2 woff2;
	}
	
	# Cache
	map \$sent_http_content_type \$cacheable_types {
		\"image/x-icon\"			\"max-age=604800\";		# 1 weak
		\"image/gif\"				\"max-age=2628000\";	# 1 month
		\"image/png\"				\"max-age=2628000\";	# 1 month
		\"image/jpg\"				\"max-age=2628000\";	# 1 month
		\"image/jpeg\"				\"max-age=2628000\";	# 1 month
		\"application/font-woff\"	\"max-age=31557600\";	# 1 year
		\"text/css\"				\"max-age=31557600\";	# 1 year
		\"application/javascript\"	\"max-age=31557600\";	# 1 year
		\"text/javascript\"			\"max-age=31557600\";	# 1 year
		default						\"max-age=0\";
	}
	
	# Temp folders
	client_max_body_size		${UPLOAD_MAX}m;
	client_body_buffer_size		128k;
	client_body_temp_path		/tmp/client_body_temp;
	fastcgi_temp_path			/tmp/fastcgi_temp;
	
	# Servers
	include /etc/nginx/servers/*.conf;
}" > /etc/nginx/nginx.conf

# Default nginx configuration
if [ ! -f /etc/nginx/servers/default.conf ]; then
	mkdir -p /etc/nginx/servers
	echo "
	server {
		listen 80 default_server;
		root \"$APP_DIR/$STATIC_DIR\";
		proxy_connect_timeout       60m;
		proxy_send_timeout          60m;
		proxy_read_timeout          60m;
		send_timeout                60m;
		fastcgi_read_timeout        60m;
		client_header_timeout 60m;
		client_body_timeout 60m;
		
		fastcgi_buffers 8 128k;
		fastcgi_buffer_size 256k;
		# Php files
		location ~ \\.php\$ {
			try_files \$uri =404;
			fastcgi_pass unix:/var/run/php-fpm.sock;
		}
		
		location / {
			# Cache time
			add_header \"Cache-Control\" \$cacheable_types;
		}
	}" > /etc/nginx/servers/default.conf
fi

# Rename SERVER_SOFTWARE
sed -i -r 's/(fastcgi_param\s+SERVER_SOFTWARE\s+).*;/\1virtualgarden;/g' /etc/nginx/fastcgi.conf

# Nginx pid file
mkdir -p /run/nginx
chown $USER:$USER /run/nginx
chmod 770 /run/nginx

# PHP
#####

#!/bin/bash
set -e

# php.ini changes
echo "
post_max_size = ${UPLOAD_MAX}M
upload_max_filesize = ${UPLOAD_MAX}M
request_terminate_timeout = 60m
max_execution_time = 60m
memory_limit = 64M
display_errors = on
" >> /etc/php82/php.ini

# php-fpm.conf changes
max_threads=20

echo "
clear_env = off

user = root
group = $USER

pm = ondemand
pm.max_children = $max_threads
pm.process_idle_timeout = 15s
pm.max_requests = 200
" >> /etc/php82/php-fpm.d/www.conf

# Clean
rm -rf /tmp/*
# Remove docker files, not needed
rm -rf /app/docker
rm -f /app/personnalisation/connect.inc.php