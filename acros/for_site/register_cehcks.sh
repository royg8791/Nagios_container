#!/bin/bash
#
# register checks with acros
#
#################### Redis DB ####################
# NIF  --- redis-cli -h 10.3.14.38  -p 12006 -n 10
# PROD --- redis-cli -h 10.3.8.133  -p 12006 -n 10
# SLIV --- redis-cli -h 10.13.7.187 -p 12006 -n 10
##################################################

#1. Get SITE from consul DC, Get list of farms
#2. If there is no consul (cmj, special machines (naf*, nve*), then read site from /etc/cm_site.json
#{


# declare host ip for redis according to SITE
site=$(egrep ^[^" "] /mnt/data/monitoring/structure.yml | cut -d: -f1)
[[ "$site" == "nif" ]] && redis_host="10.3.14.38"
[[ "$site" == "prod" ]] && redis_host="10.3.8.133"
[[ "$site" == "sliv" ]] && redis_host="10.13.7.187"
jump="jump_$site"

check=$1
# exit if check already exists
[[ "$check" ]] && [[ "$(redis-cli -h $redis_host -p 12006 -n 10 GET "checks:${check}_${HOSTNAME}")" ]] && exit 0

farms=$(egrep ^" " /mnt/data/monitoring/structure.yml)
for i in $farms; do
    [[ "$HOSTNAME" == "main-$i" ]] && farm=$i
done

[[ "$farm" ]] && mail_host="$farm" || mail_host="$site"

function create_cmnrpe () {
    local chk=$1
    local interval=$2
    local method=$3
    local var1=$4
    local var2=$5

    content=$(echo "${chk}_${HOSTNAME}:\n  ci: ${interval}\n  cc: ${method}!${var1}!${var2}\n  ops-telegram-${mail_host}@mail.catchmedia.com")

    redis-cli -h $redis_host -p 12006 -n 10 SETEX "checks:${chk}_${HOSTNAME}" 86400 "$content" &>/dev/null
}

############################## gather checks ##############################
function check_list () {
    local chk=$1
    local interval=$2
    local method=$3
    local var1=$4
    local var2=$5
    checks="${checks}$chk $interval $method $var1 $var2\n"
}

# NFS
check_list "nfs" 5 "cmnrpe_gather_metrics" "nfs" "$HOSTNAME"

# disk, load, memory, ssh, swap, dns
check_lxc=$(grep --quiet "UNCONFIGURED FSTAB FOR BASE SYSTEM" /etc/fstab && echo lxc || echo vm)
if [[ "$check_lxc" == "vm" ]]; then
    check_list "swappiness" 60 "cmnrpe_gather_metrics" "swappiness" "$HOSTNAME"
    for i in disk load memory ssh swap; do
        check_list "$i" 5 "cmnrpe_gather_metrics" "$i" "$HOSTNAME"
    done
    if [[ $(consul -v &>/dev/null;echo $?) -eq 0 ]]; then
        check_list "dns" 5 "cmnrpe_gather_metrics" "dns" "$HOSTNAME"
    fi
fi

# Docker mounts
if [[ "$(mount | grep /docker/volumes)" ]]; then
    check_list "docker-mount" 10 "cmnrpe_gather_metrics" "docker-mount" "$HOSTNAME"
fi

# Sonyliv EFS-load files check
if [[ "$HOSTNAME" == "nfs01-sonyliv" ]]; then
    check_list "efs-load" 10 "cmnrpe_gather_metrics" "efs-load" "$HOSTNAME"
fi

# Sound-Hound Finger-Print (SHFP)
if [[ "$HOSTNAME" == "shfp-atl" ]]; then
    check_list "shfp" 60 "cmnrpe_gather_metrics" "shfp" "$HOSTNAME"
fi

# Redis, gwserver, Integmon checks
if [[ "$farm" ]]; then
    if [[ "$(consul catalog services 2>/dev/null| egrep -v "metrics" | egrep "redis|etl|php|fe" | grep "$farm")" ]]; then
        check_list "redis" 20 "cmnrpe_gather_metrics" "redis" "$HOSTNAME"
    fi
    if [[ "$(consul members 2>/dev/null| grep "gws")" ]]; then
        check_list "gws" 60 "cmnrpe_gws" "$farm"
    fi
    for i in apache cron database db_primkeys db_replication etc_hosts ingestion ingestion_apply jobs_queue jobs_queue_hour machine_running redis_offloaders reports_infra reports_tasks web_services workers; do
        check_list "integmon-$i" 20 "cmnrpe_gather_metrics" "integmon-$i" "$HOSTNAME"
    done
    if [[ "$site" == "sliv" ]]; then
        check_list "backups" 10 "cmnrpe_gather_metrics" "backups" "$HOSTNAME"
    fi
fi

# Redis, Vertica State/Storage, Drives, Docker Swarm, Backups nafbs13/sonyliv
if [[ "$HOSTNAME" == "$jump" ]]; then
    if [[ "$(consul catalog services 2>/dev/null| egrep -v "metrics" | egrep "redis|etl|php|fe" | grep -v "$(echo $farms|sed 's/ /|/g')")" ]]; then
        check_list "redis" 20 "cmnrpe_gather_metrics" "redis" "$HOSTNAME"
    fi
    check_list "vertica-state" 20 "cmnrpe_gather_metrics" "vertica-state" "$HOSTNAME"
    check_list "vertica-storage" 20 "cmnrpe_gather_metrics" "vertica-storage" "$HOSTNAME"
    if [[ "$site" == "nif" ]]; then
        check_list "drives" 300 "cmnrpe_script" "/opt/rolmin/nagios/bin/check_r630_drives.sh" "$site"
        check_list "backups-nafbs13" 300 "cmnrpe_script" "/opt/rolmin/nagios/bin/bas_check_backups.sh"
    elif [[ "$site" == "sliv" ]]; then
        check_list "backups-AWS-EBS" 300 "cmnrpe_gather_metrics" "backups-AWS-EBS" "$HOSTNAME"
    fi

    check_list "docker-swarm" 60 "cmnrpe_swarm" "$site"
fi

# Bare-Metal memory RAM cards check
bm_check=$(hostnamectl status 2>/dev/null | grep Chassis | awk '{print $2}')
if [[ "$bm_check" == "server" ]]; then
    check_list "bare-metal-mem" 1440 "cmnrpe_gather_metrics" "bare-metal-mem" "$HOSTNAME"
fi

# Portworx Disk/Volume
if [[ $(pxctl &>/dev/null;echo $?) -eq 0 ]]; then
    check_list "portworx-disk" 60 "cmnrpe_gather_metrics" "portworx-disk" "$HOSTNAME"
    check_list "portworx-volume" 60 "cmnrpe_gather_metrics" "portworx-volume" "$HOSTNAME"
fi

# LSI RAID, RAID consistency
if [[ $(/opt/MegaRAID/MegaCli/MegaCli64 -v &>/dev/null;echo $?) -eq 0 ]]; then
    check_list "raid" 60 "cmnrpe_gather_metrics" "raid" "$HOSTNAME"
    check_list "raid-consistency" 10080 "cmnrpe_gather_metrics" "raid-consistency" "$HOSTNAME"
elif [[ $(/usr/sbin/tw_cli show ver &>/dev/null;echo $?) -eq 0 ]]; then
    check_list "raid" 60 "cmnrpe_gather_metrics" "raid" "$HOSTNAME"
fi

# in case no "check" was specified - run on all checks
if [[ "$check" ]]; then
    chk=$(echo -e "$checks" | grep $check)
    create_cmnrpe $chk
else
    for i in $(seq $(echo -e "$checks"|egrep .+|wc -l)); do
        chk=$(echo -e "$checks" | sed -n ${i}p)
        create_cmnrpe $chk
    done
fi
