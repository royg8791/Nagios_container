#!/bin/bash
#
# This script will be used to generate commands checks config files for nagios checks.
#
test_file="/opt/nagios/etc/tmp/commands.cfg"
real_file="/opt/nagios/etc/objects/commands.cfg"

echo "
==================================================================================
--------------------Building configuration file for Commands----------------------
=================================================================================="

echo "################################################################################
# COMMANDS.CFG - SAMPLE COMMAND DEFINITIONS FOR NAGIOS 4.2.0
#
# NOTES: This config file provides you with some example command definitions
#        that you can reference in host, service, and contact definitions.
#
#        You don't need to keep commands in a separate file from your other
#        object definitions.  This has been done just to make things easier to
#        understand.
################################################################################

################################################################################
#
# SAMPLE NOTIFICATION COMMANDS
#
# These are some example notification commands.  They may or may not work on
# your system without modification.  As an example, some systems will require
# you to use \"/usr/bin/mailx\" instead of \"/usr/bin/mail\" in the commands below.
#
################################################################################

# 'notify-host-by-email' command definition

define command {
	command_name		notify-host-by-email
	command_line		/usr/bin/printf \"NAGIOS\" | /usr/bin/mail -s \"\$HOSTNAME$ ---- \$HOSTSTATE$ ---- \$NOTIFICATIONTYPE$\\n\$NOTIFICATIONTYPE$\\nService Link: https://nagios.catchmedia.com/nagios/cgi-bin/extinfo.cgi?type=1&host=\$HOSTNAME$\" \$CONTACTEMAIL$
	}

# 'notify-service-by-email' command definition

define command {
	command_name		notify-service-by-email
	command_line		/usr/bin/printf \"NAGIOS\" | /usr/bin/mail -s \"\$HOSTALIAS$ ---- \$SERVICESTATE$ ---- \$NOTIFICATIONTYPE$\\n\$SERVICEDESC$\\nService Link: https://nagios.catchmedia.com/nagios/cgi-bin/extinfo.cgi?type=2&host=\$HOSTNAME$&service=\$SERVICEDESC$\" \$CONTACTEMAIL$
	}

# This command checks to see if a host is \"alive\" by pinging it
# The check must result in a 100% packet loss or 5 second (5000ms) round trip average time to produce a critical error.
# Note: Five ICMP echo packets are sent (determined by the '-p 5' argument)

define command {
	command_name		check-host-alive
	command_line		\$USER1$/check_tcp -H \$HOSTADDRESS$ -p 5666
	}

# Gathering Checks command is used for getting lists of checks from sites and farms using nrpe

define command {
	command_name        cmnrpe_gather_checks
        command_line        /opt/nagios/etc/config/gather_checks.sh \$ARG1$ \$ARG2$
        }

######################### check_local_host Definition ##########################

define command {
        command_name    check_local_disk
        command_line    \$USER1$/check_disk -w \$ARG1$ -c \$ARG2$ -p \$ARG3$
        }

define command {
        command_name    check_local_procs
        command_line    \$USER1$/check_procs -w \$ARG1$ -c \$ARG2$ -s \$ARG3$
        }

define command {
        command_name    check_process_syslogng
        command_line    \$USER1$/check_nrpe -t 60:UNKNOWN -H \$HOSTADDRESS$ -c check_process_syslogng_remote
        }

define command {
        command_name    check_nrpe
        command_line    \$USER1$/check_nrpe -t 60:UNKNOWN -H \$HOSTADDRESS$ -c \$ARG1$
        }

define command {
        command_name    check_local_mrtgtraf
        command_line    \$USER1$/check_mrtgtraf -F \$ARG1$ -a \$ARG2$ -w \$ARG3$ -c \$ARG4$ -e \$ARG5$
        }
" > $test_file

for i in load users swap; do
	echo -e "define command {\
	\n        command_name    check_local_$i\
	\n        command_line    \$USER1$/check_$i -w \$ARG1$ -c \$ARG2$\
	\n        }
	" >> $test_file
done



echo "########################## Sample Services Definition ##########################

define command {
        command_name    check_remote_command
        command_line    \$USER1$/check_remote_command.sh -H \$HOSTADDRESS$ -C \$ARG1$
        }

define command{
        command_name    check_http
        command_line    \$USER1$/check_http -I \$HOSTADDRESS$ \$ARG1$
        }

define command{
        command_name    check_ssh
        command_line    \$USER1$/check_ssh -p \$ARG1$ \$HOSTADDRESS$
        }

define command{
        command_name    check_dhcp
        command_line    \$USER1$/check_dhcp \$ARG1$
        }

define command{
        command_name    check_ping
        command_line    \$USER1$/check_ping -H \$HOSTADDRESS$ -w \$ARG1$ -c \$ARG2$ -p 5
        }

define command{
        command_name    check_nt
        command_line    \$USER1$/check_nt -H \$HOSTADDRESS$ -p 12489 -v \$ARG1$ \$ARG2$
        }

define command{
        command_name    check_mem
        command_line    \$USER1$/check_mem.sh -w \$ARG1$ -c \$ARG2$ -W \$ARG3$ -C \$ARG4$
        }

define command{
        command_name    check_ram
        command_line    \$USER1$/check_nrpe -t 60:1 -H \$HOSTADDRESS$ -c check_mem
        }

" >> $test_file

for i in users gfs swap disk load disk{1..9} sd{a..p} zombie_procs total_procs dmesg soft_raid geoip time; do
	echo -e "define command {\
	\n        command_name    check_$i\
	\n        command_line    \$USER1$/check_nrpe -t 60:1 -H \$HOSTADDRESS$ -c check_$i\
	\n        }
" >> $test_file
done
for i in ftp hpjd snmp smtp imap pop; do
	echo -e "define command {\
	\n        command_name    check_$i\
	\n        command_line    \$USER1$/check_$i -H \$HOSTADDRESS$ \$ARG1$\
	\n        }
" >> $test_file
done
for i in tcp udp; do
	echo -e "define command {\
	\n        command_name    check_$i\
	\n        command_line    \$USER1$/check_$i -H \$HOSTADDRESS$ -p \$ARG1$ \$ARG2$\
	\n        }
" >> $test_file
done

file_path=$(find /opt/nagios/etc/sites/ -type f -name "*.yml")
### "commands" is for all site.cfg and farm.cfg files
cmd=$(egrep cc: $file_path | awk '{print $3}' | cut -d! -f1 | sort | uniq)
for i in $cmd; do 
	echo -e "define command {\
	\n    command_name        $i\
	\n    command_line        \$USER1$/check_nrpe -H \$HOSTADDRESS$ -t 600 -c $i -a \$ARG1$ \$ARG2$ \$ARG3$\
	\n    }
	" >> $test_file
done

echo "---------------------------Done building commands.cfg-----------------------------
==================================================================================
"

if [[ "$(diff $test_file $real_file 2>&1)" ]]; then
        sudo chown nagios:nagios $test_file
        sudo chmod 666 $test_file
        mv $test_file $real_file
else
        rm $test_file
fi
