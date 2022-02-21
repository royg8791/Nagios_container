#!/bin/bash
#
# This script will be used to generate config files for nagios checks.
# Data for configuring the file can be found in config.json.
#
######################################################################

site=$1
farm=$2

# pidof -x -o $$ "server_cfg_builder.sh" &>/dev/null && exit 0

if [[ "$farm" ]]; then
    path="/opt/nagios/etc/tmp/$farm.cfg"
    yml="/opt/nagios/etc/tmp/$farm.yml"
    [[ "$(ps aux | egrep "server_cfg_builder.sh $site $farm$" | grep -v "grep" | wc -l)" -ne 2 ]] && exit 0
else
    path="/opt/nagios/etc/tmp/$site.cfg"
    yml="/opt/nagios/etc/tmp/$site.yml"
    [[ "$(ps aux | egrep "server_cfg_builder.sh $site$" | grep -v "grep" | wc -l)" -ne 2 ]] && exit 0
fi
[[ ! -d "/opt/nagios/etc/tmp" ]] && mkdir -p /opt/nagios/etc/tmp

config_file_creator () {
    echo -e "########## Server Configuration File ##########\
    \n#\
    \n# This configuration file shoul never get edited from inside here\
    \n# To edit this, please go check server_cfg_builder.sh\
    \n#\
    \n# checks are done from nrpe machine:\
    \n# root@nrpe:/opt/nrpe/bin\
    \n#\
    \n# Define a host for the local machine\
    \ndefine host {" > $path

    if [[ "$farm" ]]; then
        echo -e "    use             linux-server-$farm,host-pnp\
        \n    host_name       $site"_"$farm\
        \n    alias           $farm" >> $path
        else
        echo -e "    use             linux-server-$site,host-pnp\
        \n    host_name       $site\
        \n    alias           $site" >> $path
    fi

    echo -e "    address         nrpe.$site.catchmedia.com\
    \n    # here might go parents string (if not main)\
    \n    ### parents webtest-main\
    \n    # here might go icon and statusmap images\
    \n        # icon_image          /custom/ubuntu_16.png\
    \n        # status_image        /custom/ubuntu_16.png\
    \n}\

    \n# this service gathers all checks for this server every 10 minutes\
    \ndefine service {" >> $path

    if [[ "$farm" ]]; then
        echo -e "        use                         cm-service-template__ops-telegram-$farm\
        \n        host_name                   $site"_"$farm\
        \n        service_description         Add and Gather Checks\
        \n        check_command               cmnrpe_gather_checks!$site!$farm" >> $path
    else
        echo -e "        use                         cm-service-template__ops-telegram-$site\
        \n        host_name                   $site\
        \n        service_description         Add and Gather Checks\
        \n        check_command               cmnrpe_gather_checks!$site" >> $path
    fi

    echo -e "        check_interval              60 # minutes\
    \n        max_check_attempts          3\
    \n        retry_interval              5 # minutes\
    \n        notification_interval       60 # minutes\
    \n        }\

    \n# example of use: /opt/nagios/libexec/check_nrpe -H nrpe.$site.catchmedia.com -t 600 -c \"command_name\" -a \"ARGS\"\
    \n#\

    \n##########################################################################################################\

    \n##### List of checks - $site $farm #####\

    \n##########################################################################################################
    " >> $path

    check_list=$(grep ^[^" "] $yml)
    for i in $check_list; do
        service_name=$(grep -A4 "^$i" $yml | grep @ | cut -d@ -f1)
        service_description=${i/:/}
        check_command=$(grep -A4 "^$i" $yml | grep cc: | awk '{print $2}')
        check_interval=$(grep -A4 "^$i" $yml | grep ci: | awk '{print $2}')
        notification_interval=$check_interval

        echo -e "define service {\
        \n        use                         cm-service-template__$(echo $service_name | sed 's/ /__/g')" >> $path
        if [[ -n "$farm" ]]; then
            echo "        host_name                   $site"_"$farm" >> $path
        else
            echo "        host_name                   $site" >> $path
        fi
        echo -e "        service_description         $service_description\
        \n        check_command               $check_command\
        \n        check_interval              $check_interval # minutes\
        \n        max_check_attempts          3\
        \n        retry_interval              1 # minutes\
        \n        notification_interval       $notification_interval # minutes\
        \n        }
        " >> $path
    done
    echo "##########################################################################################################
    " >> $path
}

[[ "$farm" ]] && echo "=============== $farm ===============" || echo "=============== $site ==============="
config_file_creator
