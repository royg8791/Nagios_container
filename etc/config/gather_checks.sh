#!/bin/bash
#
# runs "Gather Checks" command for sites and farms
#
###################################################
# Cron does not include /sbin and /usr/sbin into PATH for root-owned jobs
export PATH=/usr/local/sbin:/usr/local/bin:/usr/sbin:/usr/bin:/sbin:/bin:/usr/games:/usr/local/games

NAGIOS_OK=0
NAGIOS_WARNING=1
NAGIOS_CRITICAL=2
NAGIOS_UNKNOWN=3
function set_exit_code () {
    local new_exit_code=$1
    [ $EXIT_CODE -lt $new_exit_code ] && EXIT_CODE=$new_exit_code
}
EXIT_CODE=$NAGIOS_OK

site=$1
farm=$2

if [[ "$farm" ]]; then
    host=$farm
    destination_path="/opt/nagios/etc/sites/$site/farms/$farm/"
    [[ "$(ps aux | egrep "gather_checks.sh $site $farm$" | grep -v "grep" | wc -l)" -ne 2 ]] && exit 0
else
    host=$site
    destination_path="/opt/nagios/etc/sites/$site/"
    [[ "$(ps aux | egrep "gather_checks.sh $site$" | grep -v "grep" | wc -l)" -ne 2 ]] && exit 0
fi

[[ ! -d "/opt/nagios/etc/tmp" ]] && mkdir -p /opt/nagios/etc/tmp
yaml_file="/opt/nagios/etc/tmp/$host.yml"
cfg_file="/opt/nagios/etc/tmp/$host.cfg"

result () {
    exit_code=$1
    type=$2
    if [[ "$exit_code" -eq "$NAGIOS_OK" ]]; then
        res+="OK: $host.$type up to code\n"
    elif [[ "$exit_code" -eq "$NAGIOS_WARNING" ]]; then
        res+="Warning: $host.$type integrity check error\n"
    elif [[ "$exit_code" -eq "$NAGIOS_CRITICAL" ]]; then
        res+="Critical: $host.$type is missing or empty\n"
    else
        res+="UNKNOWN: wrong site [$site] or farm [$farm]\n"
    fi
}

[[ -f "$yaml_file" ]] && rm -f $yaml_file

checks_count=$(/opt/nagios/libexec/check_nrpe -H nrpe.$site.catchmedia.com -t 600 -c cmnrpe_gather_checks -a $site checks_count $farm)
for m in $checks_count; do
    # create tmp_yml_file
    /opt/nagios/libexec/check_nrpe -H nrpe.$site.catchmedia.com -t 600 -c cmnrpe_gather_checks -a $site $farm $m >> $yaml_file
done

# check tmp_yml_file
/opt/nagios/etc/config/yml_and_cfg_check.sh yml $site $farm
exit=$?
result $exit yml
set_exit_code $exit

# create tmp_cfg_file
/opt/nagios/etc/config/server_cfg_builder.sh $site $farm

# check tmp_cfg_file
/opt/nagios/etc/config/yml_and_cfg_check.sh cfg $site $farm
exit=$?
result $exit cfg
set_exit_code $exit

if [[ $EXIT_CODE -eq $NAGIOS_OK ]]; then
    if [[ "$(diff $yaml_file ${destination_path}$host.yml 2>&1)" ]]; then
        sudo chown nagios:nagios $yaml_file
        sudo chmod 666 $yaml_file
        mv $yaml_file $destination_path
    else
        rm $yaml_file
    fi
    if [[ "$(diff $cfg_file ${destination_path}$host.cfg 2>&1)" ]]; then
        sudo chown nagios:nagios $cfg_file
        sudo chmod 666 $cfg_file
        mv $cfg_file $destination_path
    else
        rm $cfg_file
    fi
else
    rm $yaml_file $cfg_file
fi

echo -e $res

[[ "$farm" ]] && echo "$farm" >> /opt/nagios/var/gather.log || echo "$site" >> /opt/nagios/var/gather.log

if [[ -z "$(ps aux|grep gather_checks.sh|egrep -v "$$|gather_checks.sh $site $farm"|grep -v grep)" ]]; then
    sudo sv reload nagios
fi

exit $EXIT_CODE
