#!/bin/bash
#
# This script will be used to generate commands checks config files for nagios checks.
#
test_file="/opt/nagios/etc/tmp/https.cfg"
real_file="/opt/nagios/etc/objects/https.cfg"

echo "
==================================================================================
----------------Building configuration file for HTTPS hosts checks----------------
=================================================================================="

echo "
#
# Define a host for the local machine
################################################################################
define host{
  use       linux-server,host-pnp
  host_name web-https
  alias     https.catchmedia.com
  address   nrpe.nif.catchmedia.com
  # Here might go parents string (if not main)
###  parents webtest-main

  # Here might go icon and statusmap images
          # icon_image              /custom/ubuntu_16.png
          # statusmap_image         /custom/ubuntu_16.png
}

define command {
        command_name    check_https
        command_line    \$USER1$/check_nrpe -H \$HOSTADDRESS$ -t 60 -c check_https -a \$ARG1$
        }
" > $test_file

hosts=$(sed -n /hosts:/,/^[^" "]/p /opt/nagios/etc/config/web.yml | grep "com")
for i in $hosts
do
    echo "define service {
	use                             local-service
	host_name                       web-https
	service_description             https://$i
	check_command                   check_https!$i
	}
" >> $test_file
done

echo "-----------------------------Done building https.cfg------------------------------
==================================================================================
"

if [[ "$(diff $test_file $real_file 2>&1)" ]]; then
    sudo chown nagios:nagios $test_file
    sudo chmod 666 $test_file
    mv $test_file $real_file
else
    rm $test_file
fi
