#!/bin/bash
#
# This script will be used to generate commands checks config files for nagios checks.
#
test_file="/opt/nagios/etc/tmp/webtests.cfg"
real_file="/opt/nagios/etc/objects/webtests.cfg"

echo "
==================================================================================
---------------------Building configuration file for webtests---------------------
=================================================================================="

echo "################################################################################
# This configuration file shoul never get edited from inside here
# To edit this, please go check config.json and cfg_builder.sh
# checks are done from nrpe container that runs on p03 cluster:
# root@nrpe:/opt/webtests/tests/configs
#
# Define a host for the local machine
define host {
  use         linux-server,host-pnp
  host_name   webtests
  alias       webtest-all.catchmedia.com
  address     nrpe.nif.catchmedia.com
  # here might go parents string (if not main)
### parents webtest-main

  # here might go icon and statusmap images
            # icon_image          /custom/ubuntu_16.png
            # status_image        /custom/ubuntu_16.png
}

#--------------------------------------------------------------------#

############################  Commands #############################
" > $test_file

for i in webtest check_media_upload; do
    echo "define command{
        command_name    $i
        command_line    \$USER1$/check_nrpe -H \$HOSTADDRESS$ -t 180 -c $i -a \$ARG1$ \$ARG2$
        }
    " >> $test_file
done

echo "
############################  Services #############################
" >> $test_file





path="/opt/nagios/etc/config/web.yml"
farms=$(sed -n /farms:/,/different_sites:/p $path | grep ^"    " | grep : | sed 's/://g')
for i in $farms; do
    farm_web_checks=$(sed -n /$i:/,/:/p $path | grep -v :)
    for j in $farm_web_checks; do
        echo -e "define service {\
        \n        use                       local-service\
        \n        host_name                 webtests\
        \n        service_description       $i $j" >> $test_file
        if [[ "$j" == "media_upload" ]]; then
            echo "        check_command             check_media_upload!$i" >> $test_file
        elif [[ "$j" == "cmts_sanity" ]]; then
            echo "        check_command             webtest!$i!cmtsadmin_sanity" >> $test_file
        else
            echo "        check_command             webtest!$i!$j" >> $test_file
        fi
        echo "        }
        " >> $test_file
    done
done

echo "#-------------------------------------------------------------------#

########################  Different Sites #########################
" >> $test_file

different_sites=$(sed -n /different_sites:/,/^[^" "]/p $path | grep ^"    " | cut -d: -f1)
for i in $different_sites; do
    echo "define service{
        use                             local-service
        host_name                       webtests
        service_description             $i Sanity
        check_command                   $(sed -n /different_sites:/,/^[^" "]/p $path | grep "$i" | cut -d: -f2 | sed 's/ //g')
        }
    " >> $test_file
done

echo "----------------------------Done building webtests.cfg----------------------------
==================================================================================
"

if [[ "$(diff $test_file $real_file 2>&1)" ]]; then
        sudo chown nagios:nagios $test_file
        sudo chmod 666 $test_file
        mv $test_file $real_file
else
        rm $test_file
fi
