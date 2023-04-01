FROM ubuntu:16.04

# Docker container for Observium Community Edition
#
# It requires option of e.g. '--link observiumdb:observiumdb' with another MySQL or MariaDB container.
# Example usage:
# 1. MySQL or MariaDB container
# $ docker run --name observiumdb \
# -v /home/docker/observium/data:/var/lib/mysql \
# -e MYSQL_ROOT_PASSWORD=passw0rd \
# -e MYSQL_USER=observium \
# -e MYSQL_PASSWORD=passw0rd \
# -e MYSQL_DATABASE=observium \
# mariadb
#
# 2. This Observium container
# $ docker run --name observiumapp --link observiumdb:observiumdb \
# -v /home/docker/observium/logs:/opt/observium/logs \
# -v /home/docker/observium/rrd:/opt/observium/rrd \
# -e OBSERVIUM_ADMIN_USER=admin \
# -e OBSERVIUM_ADMIN_PASS=passw0rd \
# -e OBSERVIUM_DB_HOST=observiumdb \
# -e OBSERVIUM_DB_USER=observium \
# -e OBSERVIUM_DB_PASS=passw0rd \
# -e OBSERVIUM_DB_NAME=observium \
# -e OBSERVIUM_BASE_URL=http://yourserver.yourdomain:80 \
# -p 80:80 mbixtech/observium
#
# References:
# - Follow platform guideline specified in https://github.com/docker-library/official-images
# 

# Credits to:
LABEL maintainer "somsakc@hotmail.com"
LABEL version="1.5"
LABEL description="Docker container for Observium Community Edition"

ARG OBSERVIUM_ADMIN_USER=admin
ARG OBSERVIUM_ADMIN_PASS=passw0rd
ARG OBSERVIUM_DB_HOST=observiumdb
ARG OBSERVIUM_DB_USER=observium
ARG OBSERVIUM_DB_PASS=passw0rd
ARG OBSERVIUM_DB_NAME=observium

# set environment variables
ENV LANG en_US.UTF-8
ENV LANGUAGE en_US.UTF-8
ENV OBSERVIUM_DB_HOST=$OBSERVIUM_DB_HOST
ENV OBSERVIUM_DB_USER=$OBSERVIUM_DB_USER
ENV OBSERVIUM_DB_PASS=$OBSERVIUM_DB_PASS
ENV OBSERVIUM_DB_NAME=$OBSERVIUM_DB_NAME

RUN /bin/sh -c echo 'debconf debconf/frontend select Noninteractive' | debconf-set-selections
RUN /bin/sh -c 'apt-get update'
RUN /bin/sh -c 'apt-get install -y libapache2-mod-php7.0 php7.0-cli php7.0-mysql php7.0-mysqli php7.0-gd php7.0-mcrypt php7.0-json php-pear snmp fping mysql-client python-mysqldb rrdtool subversion whois mtr-tiny ipmitool graphviz imagemagick apache2'
RUN /bin/sh -c 'apt-get install -y locales'
RUN /bin/sh -c 'locale-gen en_US.UTF-8'
RUN /bin/sh -c 'DEBIAN_FRONTEND=noninteractive apt-get install -yq libvirt-bin'
RUN /bin/sh -c 'apt-get install -y cron supervisor wget'
RUN /bin/sh -c 'apt-get clean'
RUN /bin/sh -c 'mkdir -p /opt/observium /opt/observium/lock /opt/observium/logs /opt/observium/rrd'
RUN /bin/sh -c 'cd /opt && wget http://www.observium.org/observium-community-latest.tar.gz && tar zxvf observium-community-latest.tar.gz && rm observium-community-latest.tar.gz'
RUN /bin/sh -c 'cat /opt/observium/VERSION'
RUN cd /opt/observium
RUN cp /opt/observium/config.php.default /opt/observium/config.php
RUN sed -i -e "s/= 'localhost';/= getenv('OBSERVIUM_DB_HOST');/g" /opt/observium/config.php 
RUN sed -i -e "s/= 'USERNAME';/= getenv('OBSERVIUM_DB_USER');/g" /opt/observium/config.php 
RUN sed -i -e "s/= 'PASSWORD';/= getenv('OBSERVIUM_DB_PASS');/g" /opt/observium/config.php 
RUN sed -i -e "s/= 'observium';/= getenv('OBSERVIUM_DB_NAME');/g" /opt/observium/config.php
RUN echo "\$config['base_url'] = getenv('OBSERVIUM_BASE_URL');" >> /opt/observium/config.php 
COPY observium-init /opt/observium/observium-init.sh
RUN chmod a+x /opt/observium/observium-init.sh
RUN chown -R www-data:www-data /opt/observium
RUN find /opt -ls
RUN phpenmod mcrypt
RUN a2dismod mpm_event && a2enmod mpm_prefork && a2enmod php7.0 && a2enmod rewrite
COPY observium-apache24 /etc/apache2/sites-available/000-default.conf
RUN rm -fr /var/www
COPY observium-cron /tmp/observium
RUN echo "" >> /etc/crontab && \
    cat /tmp/observium >> /etc/crontab && \
    rm -f /tmp/observium
RUN apt install -y nano lynx

WORKDIR /opt/observium
# COPY supervisord.conf /etc/supervisor/supervisord.conf
# CMD ["supervisord", "-c", "/etc/supervisor/supervisord.conf"]
CMD apachectl -D FOREGROUND
EXPOSE 80/tcp
VOLUME [/opt/observium/lock /opt/observium/logs /opt/observium/rrd]
