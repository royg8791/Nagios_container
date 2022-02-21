#!/bin/bash
#
# This script will be used to generate commands checks config files for nagios checks.
#
test_file="/opt/nagios/etc/tmp/websites.cfg"
real_file="/opt/nagios/etc/objects/websites.cfg"

echo "
==================================================================================
---------------------Building configuration file for websites---------------------
=================================================================================="

echo -e "###
### Host ###

define host {
        use                     linux-server            ; Name of host template to use
                                                        ; This host definition will inherit all variables that are defined
                                                        ; in (or inherited by) the linux-server host template definition.
        host_name               websites
        address                 nrpe.nif.catchmedia.com
        }

### commands ###

define command{
        command_name    check_site
        command_line    \$USER1$/check_site -H \$ARG1$ -u \$ARG2$ -O \"\$ARG3$\"
        }

define command{
        command_name    check_site_ftp
        command_line    \$USER1$/check_tcp -H \$ARG1$ -p \$ARG2$
        }

### Service Group ###

define servicegroup {
        servicegroup_name           websites" > $test_file

websites=$(sed -n /websites:/,/^[^" "]/p /opt/nagios/etc/config/web.yml | grep '://' | cut -d: -f-2)
for i in $websites; do
    echo "        members             websites,$i" >> $test_file
done
echo "        }

### Services ###
" >> $test_file

for i in $websites; do
    check_command=$(egrep "$i:" /opt/nagios/etc/config/web.yml | awk '{print $2}')
    echo -e "define service {\
    \n        use                             local-service,srv-pnp\
    \n        host_name                       websites\
    \n        service_description             $i\
    \n        check_command                   $check_command\
    \n        retry_interval                  1 # minutes\
    \n        }
    " >> $test_file
done


echo "----------------------------Done building websites.cfg----------------------------
==================================================================================
"

if [[ "$(diff $test_file $real_file 2>&1)" ]]; then
        sudo chown nagios:nagios $test_file
        sudo chmod 666 $test_file
        mv $test_file $real_file
else
        rm $test_file
fi
