#!/bin/bash

grep --quiet APACHE_RUN_USER= /etc/apache2/envvars || \
  echo "export APACHE_RUN_USER=$APACHE_RUN_USER" >> /etc/apache2/envvars
grep --quiet APACHE_RUN_GROUP= /etc/apache2/envvars || \
echo "export APACHE_RUN_GROUP=$APACHE_RUN_GROUP" >> /etc/apache2/envvars

. /etc/apache2/envvars

. /etc/default/apache-htcacheclean

export TZ="${NAGIOS_TIMEZONE}"

#/usr/sbin/apache2 -D NO_DETACH &
/etc/init.d/apache2 start

