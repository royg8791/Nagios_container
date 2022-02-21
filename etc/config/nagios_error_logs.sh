#!/bin/bash
#
# gathers Errors from log file for future use
#
# gather problems and when they're solved
#
##########################################################

error_log="/opt/nagios/etc/objects/error.log"
problem_log="/opt/nagios/etc/objects/problem.log"

start_time=$(date -d "15 minute ago" +%s)
stop_time=$(date +%s)

IFS=$'\n' # internal field separator

while [[ -z "$(grep $start_time /opt/nagios/var/nagios.log)" ]]; do
    let start_time++
done

data=$(sed -n "/$start_time/,/$stop_time/p" /opt/nagios/var/nagios.log)

errors=$(echo "$data" | grep -i "] error:")
crits=$(echo "$data" | grep "SERVICE ALERT" | grep -i "critical" | grep -v "port 5666:")
oks=$(echo "$data" | grep "SERVICE ALERT" | grep -i "ok")

[[ -z "$errors" ]] && [[ -z "$crits" ]] && [[ -z "$oks" ]] && exit 0

for error in $errors; do
    error=$(echo $error | cut -d] -f2-)
    
    [[ ! "$(cat "$error_log")" =~ "$error" ]] && echo "$error" >> $error_log
done
for crit in $crits; do
    crit_time=$(echo $crit | cut -d] -f1 | cut -d\[ -f2)
    crit=$(echo $crit | cut -d: -f2-)
    crit_msg="$(echo "$(date --date="@$crit_time") -$crit")"

    [[ ! "$(cat "$problem_log")" =~ "$crit_msg" ]] && echo "$crit_msg" >> $problem_log
done
for ok in $oks; do
    ok_time=$(echo $ok | cut -d] -f1 | cut -d\[ -f2)
    ok=$(echo $ok | cut -d: -f2-)
    ok_msg="$(echo "$(date --date="@$ok_time") -$ok")"
    ok_sgn=$(echo $ok | cut -d\; -f-2)
    
    if [[ "$(grep "$ok_sgn" $problem_log)" ]]; then
        if [[ ! "$(cat "$problem_log")" =~ "$ok_msg" ]]; then
            problem_line=$(grep "$ok_sgn" $problem_log | tail -1)
            if [[ "$(echo "$problem_line" | grep "CRITICAL")" ]]; then
                sed -i "s/$problem_line/$problem_line\n└─$ok_msg/" $problem_log
            fi
        fi
    fi
done
