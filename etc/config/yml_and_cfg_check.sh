#!/bin/bash
#
# runs as part of the "cmnrpe_gather_checks" command
# checks that the yml file has been created successfuly
###########################################################

NAGIOS_OK=0
NAGIOS_WARNING=1
NAGIOS_CRITICAL=2
NAGIOS_UNKNOWN=3
function set_exit_code () {
    local new_exit_code=$1
    [ $EXIT_CODE -lt $new_exit_code ] && EXIT_CODE=$new_exit_code
}
EXIT_CODE=$NAGIOS_OK

sites=$(ls /opt/nagios/etc/sites/ 2>/dev/null)
farms=$(find /opt/nagios/etc/sites/*/farms -maxdepth 0 -type d -exec ls {} \;)

input_file=$1

site=$2
farm=$3

[[ "$(ps aux | grep "yml_and_cfg_check.sh ... $site $farm" | grep -v "grep" | wc -l)" -eq 1 ]] && exit 0


farm_n_site_check () {
    if [[ -n "$farm" ]]; then
        if [[ "$farms" =~ "$farm" ]] && [[ "$sites" =~ "$site" ]]; then
            yaml_file="/opt/nagios/etc/sites/$site/farms/$farm/$farm.yml"
            cfg_file="/opt/nagios/etc/sites/$site/farms/$farm/$farm.cfg"
            server=$farm
        else
            set_exit_code $NAGIOS_UNKNOWN
        fi
    else
        if [[ "$sites" =~ "$site" ]]; then
            yaml_file="/opt/nagios/etc/sites/$site/$site.yml"
            cfg_file="/opt/nagios/etc/sites/$site/$site.cfg"
            server=$site
        else
            set_exit_code $NAGIOS_UNKNOWN
        fi
    fi
}

yaml_check () {
    local host=$1
    tmp_yml_file="/opt/nagios/etc/tmp/$host.yml"
    if [[ -s "$tmp_yml_file" ]]; then
        test=0
        ci=$(grep "ci:" $tmp_yml_file | wc -l)
        cc=$(grep "cc:" $tmp_yml_file | wc -l)
        [[ $cc -ne $ci ]] && let test++

        if [[ $test -gt 0 ]]; then
            set_exit_code $NAGIOS_WARNING
        fi
    else
        set_exit_code $NAGIOS_CRITICAL
    fi
}

cfg_check () {
    local host=$1
    tmp_yml_file="/opt/nagios/etc/tmp/$host.yml"
    tmp_cfg_file="/opt/nagios/etc/tmp/$host.cfg"
    if [[ -s "$tmp_cfg_file" ]]; then
        test=0
        services=$(grep "define service" $tmp_cfg_file)
        checks=$(grep ^[^" "] $tmp_yml_file)
        [[ $(echo "$services" | wc -l) -ne $(echo "$checks" | wc -l)+1 ]] && let test++
        [[ $(cat $tmp_cfg_file | grep "^#" | wc -l) -ne 16 ]] && let test++

        if [[ $test -ne 0 ]]; then
            set_exit_code $NAGIOS_WARNING
        fi
    else
        set_exit_code $NAGIOS_CRITICAL
    fi
}


farm_n_site_check

### YAML files check
[[ "$input_file" == "yml" ]] && yaml_check $server

### cfg files check
[[ "$input_file" == "cfg" ]] && cfg_check $server

exit $EXIT_CODE
