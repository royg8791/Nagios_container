#!/bin/bash
#
# This script will be used to generate commands checks config files for nagios checks.
#
test_file="/opt/nagios/etc/tmp/aframe.cfg"
real_file="/opt/nagios/etc/objects/aframe.cfg"

echo "
==================================================================================
-------------------- Building configuration file for aframe ----------------------
=================================================================================="

echo "###############################################################################
# LOCALHOST.CFG - SAMPLE OBJECT CONFIG FILE FOR MONITORING THIS MACHINE
#
# NOTE: This config file is intended to serve as an *extremely* simple 
#       example of how you can create configuration entries to monitor
#       the local (Linux) machine.
###############################################################################

############################### HOST DEFINITION ###############################

define host {
        use                     linux-server,host-pnp   ; Name of host template to use
                                                        ; This host definition will inherit all variables that are defined
                                                        ; in (or inherited by) the linux-server host template definition.
        host_name               aframe
        alias                   aframe.catchmedia.com
        address                 10.3.1.20
        # icon_image              /custom/ubuntu_16.png
        # statusmap_image         /custom/ubuntu_16.png
        }

define command {
        command_name    check_alldisks
        command_line    \$USER1$/check_nrpe -H \$HOSTADDRESS$ -c check_alldisks -t 60
        }

############################# SERVICE DEFINITIONS #############################

define service {
        use                             local-service
        host_name                       aframe
        service_description             HTTP
        check_command                   check_http
        }
" > $test_file

for i in check_ping!100.0,20%!500.0,60% check_alldisks check_users check_total_procs check_zombie_procs check_load!5.0,4.0,3.0!10.0,6.0,4.0 check_ssh!22 check_ram; do
    echo -e "define service {\
    \n        use                             local-service,srv-pnp\
    \n        host_name                       aframe\
    \n        service_description             $(echo $i | cut -d! -f1)\
    \n        check_command                   $i\
    \n        }
    " >> $test_file
done

echo "--------------------------- Done building aframe.cfg -----------------------------
==================================================================================
"

if [[ "$(diff $test_file $real_file 2>&1)" ]]; then
        sudo chown nagios:nagios $test_file
        sudo chmod 666 $test_file
        mv $test_file $real_file
else
        rm $test_file
fi
