#!/bin/bash
#
# listens to changesw in redis channel, and initiates scripts accordingly
#
#################### Redis DB ####################
# NIF  --- redis-cli -h 10.3.14.38  -p 12006 -n 10
# PROD --- redis-cli -h 10.3.8.133  -p 12006 -n 10
# SLIV --- redis-cli -h 10.13.7.187 -p 12006 -n 10
##################################################
# declare host ip for redis according to SITE
site=$(egrep ^[^" "] /mnt/data/monitoring/structure.yml | cut -d: -f1)
[[ "$site" == "nif" ]] && redis_host="10.3.14.38"
[[ "$site" == "prod" ]] && redis_host="10.3.8.133"
[[ "$site" == "sliv" ]] && redis_host="10.13.7.187"
jump="jump_$site"

##### output------ "pmessage","remetric:*","remetric:disk_doc2-nqa","metric"

farms=$(egrep ^" " /mnt/data/monitoring/structure.yml)
for i in $farms; do
    [[ "$HOSTNAME" =~ "$i" ]] && host="main-$i"
done
[[ ! "$host" ]] && host="$jump"

stdbuf -oL redis-cli -h $redis_host -p 12006 -n 10 --csv psubscribe "run_checks:*" "run_metrics:*" "recheck:*" "remetric:*" | while read event;
do
    run_checks=$(echo "$event" | grep "run_checks:$host")
    run_metrics=$(echo "$event" | grep "run_metrics:$host")
    [[ "$run_checks" ]] && /opt/rolmin/nagios/register_checks.sh
    [[ "$run_metrics" ]] && /opt/rolmin/nagios/publish_metrics.sh

    recheck=$(echo "$event" | egrep "recheck:.*$HOSTNAME" | awk -F \" '{print $(NF-1)}')
    remetric=$(echo "$event" | egrep "remetric:.*$HOSTNAME" | awk -F \" '{print $(NF-1)}')
    [[ "$recheck" ]] && /opt/rolmin/nagios/register_checks.sh $recheck
    [[ "$remetric" ]] && /opt/rolmin/nagios/publish_metrics.sh $remetric
done
