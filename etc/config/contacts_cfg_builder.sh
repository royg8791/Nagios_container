#!/bin/bash
#
# This script will be used to generate Contacts checks config files for nagios checks.
#
test_file="/opt/nagios/etc/tmp/contacts.cfg"
real_file="/opt/nagios/etc/objects/contacts.cfg"

echo "
==================================================================================
--------------------Building configuration file for Contacts----------------------
=================================================================================="

echo "###############################################################################
# CONTACTS.CFG - SAMPLE CONTACT/CONTACTGROUP DEFINITIONS
#
#
# NOTES: This config file provides you with some example contact and contact
#        group definitions that you can reference in host and service
#        definitions.
#
#        You don't need to keep these definitions in a separate file from your
#        other object definitions.  This has been done just to make things
#        easier to understand.
#
###############################################################################



###############################################################################
###############################################################################
#
# CONTACTS
#
###############################################################################
###############################################################################

# Just one contact defined by default - the Nagios admin (that's you)
# This contact definition inherits a lot of default values from the 'generic-contact'
# template which is defined elsewhere.

# Send low-priority notifications
define contact {
        contact_name                            nagiosadmin                             ; Short name of user
        use                                     generic-contact                         ; Inherit default values from generic-contact template (defined above)
        alias                                   Nagios Admin                            ; Full name of user
        email                                   ops-nagios@mail.catchmedia.com          ; <<***** CHANGE THIS TO YOUR EMAIL ADDRESS ******
        service_notification_period             24x7
        host_notification_period                24x7
        # w=warning, u=unreachable, c=critical, r=recovered, f=flapping, s=scheduled downtime
        service_notification_options            w,u,c,r,f,s
        # d=down, u=up, r=recovered, f=flapping, s=scheduled downtime
        host_notification_options               d,u,r,f,s
        # service_notification_commands         notify-service-by-email
        # host_notification_commands            notify-host-by-email
        # register                              0
        }
" > $test_file

sites=$(ls /opt/nagios/etc/sites/)
farms=$(find /opt/nagios/etc/sites/*/farms -maxdepth 0 -type d -exec ls {} \;)

file_path=$(find /opt/nagios/etc/sites/ -type f -name "*.yml")
emails=$(cat $file_path | egrep @ | sort | uniq)

for i in $emails ops-telegram@mail.catchmedia.com; do
    echo -e "define contact{\
        \n        contact_name                            cm-contact__$(echo $i | cut -d@ -f1)\
        \n        use                                     generic-contact\
        \n        alias                                   cm\
        \n        email                                   $i\
        \n        service_notification_period             24x7\
        \n        host_notification_period                24x7\
        \n        service_notification_options            c,r\
        \n        host_notification_options               d,u,r\
        \n        }
        " >> $test_file
done

echo "###############################################################################
###############################################################################
#
# CONTACT GROUPS
#
###############################################################################
###############################################################################

# We only have one contact in this simple configuration file, so there is
# no need to create more than one contact group.

define contactgroup{
        contactgroup_name                       admins
        alias                                   Nagios Administrators
        members                                 nagiosadmin,cm-contact__ops-telegram
        }
" >> $test_file

contacts=$(cat $file_path | egrep ^[^" "]"|@" | cut -d@ -f1 | sed -z 's/\n  /__/g' | cut -d: -f2 | cut -c3- | sort | uniq)
for i in $contacts; do
    cm_cg_name="cm-contact-group__$i"
    cm_contacts="cm-contact__$(echo $i | sed 's/__/,cm-contact__/g')"
    echo -e "define contactgroup{\
        \n        contactgroup_name                       $cm_cg_name\
        \n        alias                                   Nagios Administrators\
        \n        members                                 nagiosadmin,$cm_contacts\
        \n        }
        " >> $test_file
done

echo "---------------------------Done building contacts.cfg-----------------------------
==================================================================================
"

if [[ "$(diff $test_file $real_file 2>&1)" ]]; then
        sudo chown nagios:nagios $test_file
        sudo chmod 666 $test_file
        mv $test_file $real_file
else
        rm $test_file
fi
