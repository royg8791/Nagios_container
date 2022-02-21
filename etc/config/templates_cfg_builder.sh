#!/bin/bash
#
# This script will be used to generate template config files for nagios checks.
#
test_file="/opt/nagios/etc/tmp/templates.cfg"
real_file="/opt/nagios/etc/objects/templates.cfg"

echo "
==================================================================================
-----------------------Building Template configuration file-----------------------
=================================================================================="

echo "###############################################################################
# TEMPLATES.CFG - SAMPLE OBJECT TEMPLATES
#
# NOTES: This config file provides you with some example object definition
#        templates that are refered by other host, service, contact, etc.
#        definitions in other config files.
#
#        You don't need to keep these definitions in a separate file from your
#        other object definitions.  This has been done just to make things
#        easier to understand.
#
###############################################################################


###############################################################################
###############################################################################
#
# CONTACT TEMPLATES
#
###############################################################################
###############################################################################

# Generic contact definition template - This is NOT a real contact, just a template!

define contact{
        name                            generic-contact           ; The name of this contact template
        service_notification_period     24x7                      ; service notifications can be sent anytime
        host_notification_period        24x7                      ; host notifications can be sent anytime
        service_notification_options    w,u,c,r,f,s               ; send notifications for all service states, flapping events, and scheduled downtime events
        host_notification_options       d,u,r,f,s                 ; send notifications for all host states, flapping events, and scheduled downtime events
        service_notification_commands   notify-service-by-email   ; send service notifications via email
        host_notification_commands      notify-host-by-email      ; send host notifications via email
        register                        0                         ; DONT REGISTER THIS DEFINITION - ITS NOT A REAL CONTACT, JUST A TEMPLATE!
        }


###############################################################################
###############################################################################
#
# HOST TEMPLATES
#
###############################################################################
###############################################################################

# Generic host definition template - This is NOT a real host, just a template!

define host{
        name                            generic-host        ; The name of this host template
        notifications_enabled           1                   ; Host notifications are enabled
        event_handler_enabled           1                   ; Host event handler is enabled
        flap_detection_enabled          1                   ; Flap detection is enabled
        process_perf_data               1                   ; Process performance data
        retain_status_information       1                   ; Retain status information across program restarts
        retain_nonstatus_information    1                   ; Retain non-status information across program restarts
        notification_period             24x7                ; Send host notifications at any time
        register                        0                   ; DONT REGISTER THIS DEFINITION - ITS NOT A REAL HOST, JUST A TEMPLATE!
        }

# Linux host definition template - This is NOT a real host, just a template!
define host{
        name                            linux-server        ; The name of this host template
        use                             generic-host        ; This template inherits other values from the generic-host template
        check_period                    24x7                ; By default, Linux hosts are checked round the clock
        check_interval                  5                   ; Actively check the host every 5 minutes
        retry_interval                  1                   ; Schedule host check retries at 1 minute intervals
        max_check_attempts              10                  ; Check each Linux host 10 times (max)
        check_command                   check-host-alive    ; Default command to check Linux hosts
        notification_period             workhours           ; Linux admins hate to be woken up, so we only notify during the day
                                                            ; Note that the notification_period variable is being overridden from
                                                            ; the value that is inherited from the generic-host template!
        notification_interval           120                 ; Resend notifications every 2 hours
        notification_options            d,u,r               ; Only send notifications for specific host states
        contact_groups                  admins              ; Notifications get sent to the admins by default
        register                        0                   ; DONT REGISTER THIS DEFINITION - ITS NOT A REAL HOST, JUST A TEMPLATE!
        }

define host{
        name                            linux-server-low
        use                             linux-server

        contact_groups                  opsnotes_grp
        register                        0
        }
" > $test_file
for i in Windows-Server Generic-Printer Generic-Switch
do
    first_part=$(echo $i|cut -d- -f1)
    second_part=$(echo $i|cut -d- -f2)
    echo -e "# Defines a $first_part $second_part template\

    \ndefine host{\
    \n      name                    ${i,,}      ; The name of this host template\
    \n      use                     generic-host        ; Inherit default values from the generic-host template\
    \n      check_period            24x7                ; By default, Windows servers are monitored round the clock\
    \n      check_interval          5                   ; Actively check the server every 5 minutes\
    \n      retry_interval          1                   ; Schedule host check retries at 1 minute intervals\
    \n      max_check_attempts      10                  ; Check each server 10 times (max)\
    \n      check_command           check-host-alive    ; Default command to check if servers are \"alive\"" >> $test_file
    if [ "$second_part" == "Printer" ]
    then
        echo "      notification_period     workhours           ; Printers are only used during the workday" >> $test_file
    else
        echo "      notification_period     24x7                ; Send notification out at any time - day or night" >> $test_file
    fi
    echo -e "      notification_interval   30                  ; Resend notifications every 30 minutes\
    \n      notification_options    d,r                 ; Only send notifications for specific host states\
    \n      contact_groups          admins              ; Notifications get sent to the admins by default" >> $test_file
    if [ "$first_part" == "Windows" ]
    then
        echo "      hostgroups              windows-servers     ; Host groups that Windows servers should be a member of" >> $test_file
    fi
    echo -e "      register                0                   ; DONT REGISTER THIS - ITS JUST A TEMPLATE\
    \n      }
    " >> $test_file
done
echo "###############################################################################
###############################################################################
#
# SERVICE TEMPLATES
#
###############################################################################
###############################################################################

# Generic service definition template - This is NOT a real service, just a template!

define service{
        name                            generic-service     ; The 'name' of this service template
        active_checks_enabled           1                   ; Active service checks are enabled
        passive_checks_enabled          1                   ; Passive service checks are enabled/accepted
        parallelize_check               1                   ; Active service checks should be parallelized (disabling this can lead to major performance problems)
        obsess_over_service             1                   ; We should obsess over this service (if necessary)
        check_freshness                 0                   ; Default is to NOT check service 'freshness'
        notifications_enabled           1                   ; Service notifications are enabled
        event_handler_enabled           1                   ; Service event handler is enabled
        flap_detection_enabled          1                   ; Flap detection is enabled
        process_perf_data               1                   ; Process performance data
        retain_status_information       1                   ; Retain status information across program restarts
        retain_nonstatus_information    1                   ; Retain non-status information across program restarts
        is_volatile                     0                   ; The service is not volatile
        check_period                    24x7                ; The service can be checked at any time of the day
        max_check_attempts              3                   ; Re-check the service up to 3 times in order to determine its final (hard) state
        check_interval                  20                  ; Check the service every 10 minutes under normal conditions
        retry_interval                  2                   ; Re-check the service every two minutes until a hard state can be determined
        contact_groups                  admins              ; Notifications get sent out to everyone in the 'admins' group
        notification_options            w,u,c,r             ; Send notifications about warning, unknown, critical, and recovery events
        notification_interval           60                  ; Re-notify about service problems every hour
        notification_period             24x7                ; Notifications can be sent out at any time
        register                        0                   ; DONT REGISTER THIS DEFINITION - ITS NOT A REAL SERVICE, JUST A TEMPLATE!
        }

# Local service definition template - This is NOT a real service, just a template!

define service{
        name                            local-service       ; The name of this service template
        use                             generic-service     ; Inherit default values from the generic-service definition
        max_check_attempts              5                   ; Re-check the service up to 4 times in order to determine its final (hard) state
        check_interval                  15                  ; Check the service every 5 minutes under normal conditions
        retry_interval                  2                   ; Re-check the service every minute until a hard state can be determined
        register                        0                   ; DONT REGISTER THIS DEFINITION - ITS NOT A REAL SERVICE, JUST A TEMPLATE!
        }

#High priority service (Alert by call, 1 min check period)

define service{
        name                            high-priority-service
        notifications_enabled           1
        check_interval                  1
        contact_groups                  high
        use                             generic-service
        register                        0
        }
" >> $test_file

sites=$(ls /opt/nagios/etc/sites/)
farms=$(find /opt/nagios/etc/sites/*/farms -maxdepth 0 -type d -exec ls {} \;)

file_path=$(find /opt/nagios/etc/sites/ -type f -name "*.yml")
contacts=$(cat $file_path | egrep ^[^" "]"|@" | cut -d@ -f1 | sed -z 's/\n  /__/g' | cut -d: -f2 | cut -c3- | sort | uniq)

echo "
#------------------------------------------------#

# Defining hosts for all sites and farms

#------------------------------------------------#

" >> $test_file

for i in $sites $farms; do
    cm_cgs=$(echo "$contacts" | grep "\-$i")
    cm_cgs="cm-contact-group__$(echo $cm_cgs | sed 's/ /,cm-contact-group__/g')"
    [[ ! "$cm_cgs" ]] && continue
    echo "define host{
        name                            linux-server-$i
        use                             linux-server
        contact_groups                  $cm_cgs
        register                        0
        }
    " >> $test_file
done

echo "
#------------------------------------------------#

# Defining services for all contact groups

#------------------------------------------------#

# Notifications get sent out to all contact groups under service name

" >> $test_file

for i in $(echo "$contacts"); do
    cm_temp="cm-service-template__$i"
    cm_cgs="cm-contact-group__$i"
    echo "define service{
        name                            $cm_temp
        use                             generic-service
        contact_groups                  $cm_cgs
        register                        0
        }
    " >> $test_file
done

echo "# Med priority service (Alert by email, 5 min check period)

define service{
        name                            med-priority-service
        notifications_enabled           1
        check_interval                  5
        contact_groups                  medium
        use                             generic-service
        register                        0
        }

# Low priority service (No alert, 10 min check period)

define service{
        name                            low-priority-service
        check_interval                  10
        use                             generic-service
        register                        0
        }

define service{
        name                            cmts                    ; The name of this service template
        use                             generic-service         ; Inherit default values from the generic-service definition
        max_check_attempts              5                       ; Re-check the service up to 4 times in order to determine its final (hard) state
        check_interval                  5                       ; Check the service every 5 minutes under normal conditions
        retry_interval                  2                       ; Re-check the service every minute until a hard state can be determined
        register                        0                       ; DONT REGISTER THIS DEFINITION - ITS NOT A REAL SERVICE, JUST A TEMPLATE!
        }


define service{
        name                            workers                 ; The name of this service template
        use                             generic-service         ; Inherit default values from the generic-service definition
        max_check_attempts              5                       ; Re-check the service up to 4 times in order to determine its final (hard) state
        check_interval                  360                     ; Check the service every 4 hours under normal conditions
        retry_interval                  2                       ; Re-check the service every hour until a hard state can be determined
        notification_interval           360                     ; Re-notify about service problems every 4 hours
        register                        0                       ; DONT REGISTER THIS DEFINITION - ITS NOT A REAL SERVICE, JUST A TEMPLATE!
        }

define service{
        name                            smart                   ; The name of this service template
        use                             generic-service         ; Inherit default values from the generic-service definition
        max_check_attempts              5                       ; Re-check the service up to 4 times in order to determine its final (hard) state
        check_interval                  240                     ; Check the service every 4 hours under normal conditions
        retry_interval                  2                       ; Re-check the service every hour until a hard state can be determined
        notification_interval           240                     ; Re-notify about service problems every 4 hours
        register                        0                       ; DONT REGISTER THIS DEFINITION - ITS NOT A REAL SERVICE, JUST A TEMPLATE!
        }

define service{
        name                            qa                      ; The name of this service template
        use                             generic-service         ; Inherit default values from the generic-service definition
        max_check_attempts              5                       ; Re-check the service up to 4 times in order to determine its final (hard) state
        check_interval                  720                     ; Check the service every 4 hours under normal conditions
        retry_interval                  2                       ; Re-check the service every hour until a hard state can be determined
        notification_interval           720                     ; Re-notify about service problems every 4 hours
        register                        0                       ; DONT REGISTER THIS DEFINITION - ITS NOT A REAL SERVICE, JUST A TEMPLATE!
        active_checks_enabled           0
        passive_checks_enabled          0
        notification_period             non-workhours
        }

define service{
        name                            backupmon               ; The name of this service template
        use                             generic-service         ; Inherit default values from the generic-service definition
        max_check_attempts              5                       ; Re-check the service up to 4 times in order to determine its final (hard) state
        check_interval                  1440                    ; Check the service every 4 hours under normal conditions
        retry_interval                  2                       ; Re-check the service every hour until a hard state can be determined
        notification_interval           1440                    ; Re-notify about service problems every 4 hours
        register                        0                       ; DONT REGISTER THIS DEFINITION - ITS NOT A REAL SERVICE, JUST A TEMPLATE!
        }

define service{
        name                            servers-behind-firewall ; The name of this service template
        use                             generic-service         ; Inherit default values from the generic-service definition
        max_check_attempts              5                       ; Re-check the service up to 4 times in order to determine its final (hard) state
        check_interval                  60                      ; Check the service every 5 minutes under normal conditions
        retry_interval                  5                       ; Re-check the service every minute until a hard state can be determine
        register                        0                       ; DONT REGISTER THIS DEFINITION - ITS NOT A REAL SERVICE, JUST A TEMPLATE!
        active_checks_enabled           1                       ; Active service checks are enabled
        passive_checks_enabled          1                       ; Passive service checks are enabled/accepted
        }


define service{
        name                            rds
        use                             generic-service
        max_check_attempts              5
        check_interval                  5
        retry_interval                  2
        notification_interval           5
        register                        0
        }

define service{
        name                            locks                   ; The name of this service template
        use                             generic-service         ; Inherit default values from the generic-service definition
        max_check_attempts              5                       ; Re-check the service up to 4 times in order to determine its final (hard) state
        check_interval                  60                      ; Check the service every 5 minutes under normal conditions
        retry_interval                  2                       ; Re-check the service every minute until a hard state can be determined
        register                        0                       ; DONT REGISTER THIS DEFINITION - ITS NOT A REAL SERVICE, JUST A TEMPLATE!
        }

#---------------------- Integmon & Webmon ----------------------#
" >> $test_file
for i in $farms; do
    echo "define host{
        name            integmon_$i
        notes_url       /nagios/run_test/integmon_$i.php
        }

define host{
        name            webmon_$i
        notes_url       /nagios/run_test/webmon_$i.php
        }
" >> $test_file
done

echo "
define host {
        name host-pnp
        action_url /pnp4nagios/index.php/graph?host=\$HOSTNAME$&srv=_HOST_' class='tips' rel='/pnp4nagios/index.php/popup?host=\$HOSTNAME$&srv=_HOST_
        register 0
        }
define service {
        name srv-pnp
        action_url /pnp4nagios/index.php/graph?host=\$HOSTNAME$&srv=\$SERVICEDESC$' class='tips' rel='/pnp4nagios/index.php/popup?host=\$HOSTNAME$&srv=\$SERVICEDESC$
        register 0
        }
" >> $test_file

echo "---------------------------Done building templates.cfg----------------------------
==================================================================================
"

if [[ "$(diff $test_file $real_file 2>&1)" ]]; then
        sudo chown nagios:nagios $test_file
        sudo chmod 666 $test_file
        mv $test_file $real_file
else
        rm $test_file
fi
