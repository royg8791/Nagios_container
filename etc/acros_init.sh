#!/bin/bash
#
# this script runs all configuration file builders in the correct order
# establishing the entire nagios checking system
######################################################################

echo "
##################################################################################
##################################################################################
==================================================================================

-----------------------------Configuring ACROS System-----------------------------

==================================================================================
##################################################################################
##################################################################################
"

###### Try to use list of sites from previous runs, resort to hardcoded list if empty ######
sites=$(ls /opt/nagios/etc/sites/)
if [ -z "$sites" ];
then
  # First run, use hardcoded list of sites, will be used if persistent volume is empty
  sites="nif prod sliv"
fi

for s in $sites; do
    mkdir -p /opt/nagios/etc/sites/$s/farms
    /opt/nagios/etc/config/gather_checks.sh $s
    farms=$(/opt/nagios/libexec/check_nrpe -H nrpe.$s.catchmedia.com -t 600 -c cmnrpe_gather_checks -a farms)
    for f in $farms; do
        mkdir -p /opt/nagios/etc/sites/$s/farms/$f/
        /opt/nagios/etc/config/gather_checks.sh $s $f
    done
done

# gather web.yml
/opt/nagios/libexec/check_nrpe -H nrpe.nif.catchmedia.com -t 600 -c cmnrpe_gather_checks -a nif webtests > /opt/nagios/etc/config/web.yml

/opt/nagios/etc/config/templates_cfg_builder.sh
/opt/nagios/etc/config/https_cfg_builder.sh
/opt/nagios/etc/config/contacts_cfg_builder.sh
/opt/nagios/etc/config/aframe_cfg_builder.sh
/opt/nagios/etc/config/commands_cfg_builder.sh
/opt/nagios/etc/config/websites_cfg_builder.sh
/opt/nagios/etc/config/webtests_cfg_builder.sh

sudo chmod -R 777 /opt/nagios/etc/*

echo "
##################################################################################
##################################################################################
==================================================================================

------------------------------ACROS System Complete-------------------------------

==================================================================================
##################################################################################
##################################################################################
"

sv restart nagios
