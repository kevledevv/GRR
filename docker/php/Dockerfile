# PHP 8 docker environement with alpine, nginx, php8

# Alpine base
FROM alpine:3.18

# Install
COPY install.sh /install.sh
RUN /bin/sh install.sh
RUN adduser -D -g "" "app"

# App files
WORKDIR /app

# Setup
COPY setup.sh /setup.sh
RUN /bin/sh /setup.sh

# Run
EXPOSE 80
CMD ["runsvdir", "/etc/service"]