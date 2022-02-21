#!/bin/bash
#
# checks the integrity of all files that have to be intact
# makes sure nagios runs correctly
#
# all .cfg files have to be checked
#
# runs from cron
##########################################################

sites=$(ls /opt/nagios/etc/sites/)

for site in $sites; do
    metrics=$(/opt/nagios/libexec/check_nrpe -H nrpe.$site.catchmedia.com -t 600 -c cmnrpe_gather_checks -a $site checks_count)
    tmp_file="/opt/nagios/etc/tmp/$site"

    /opt/nagios/libexec/check_nrpe -H nrpe.$site.catchmedia.com -t 600 -c cmnrpe_gather_checks -a $site>> $tmp_file

    [[ ! "$(cat $tmp_file)" ]] && rm -rf /opt/nagios/etc/sites/$site
    rm $tmp_file

    farms=$(ls /opt/nagios/etc/sites/$site/farms/)
    for farm in $farms; do
        metrics=$(/opt/nagios/libexec/check_nrpe -H nrpe.$site.catchmedia.com -t 600 -c cmnrpe_gather_checks -a $site checks_count $farm)
        tmp_file="/opt/nagios/etc/tmp/$farm"

        /opt/nagios/libexec/check_nrpe -H nrpe.$site.catchmedia.com -t 600 -c cmnrpe_gather_checks -a $farm >> $tmp_file
        [[ ! "$(cat $tmp_file)" ]] && rm -rf /opt/nagios/etc/sites/$site/farms/$farm
        rm $tmp_file
    done
done
