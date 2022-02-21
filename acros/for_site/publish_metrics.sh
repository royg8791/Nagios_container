#!/bin/bash
#
# publishes metrics with acros
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

metric=$1
# exit if no existing check for particular metric and if metric already exists
if [[ "$metric" ]]; then
    [[ ! "$(redis-cli -h $redis_host -p 12006 -n 10 GET "checks:${metric}_${HOSTNAME}")" ]] && exit 0
    [[ "$(redis-cli -h $redis_host -p 12006 -n 10 GET "metrics:${metric}_${HOSTNAME}")" ]] && exit 0
else
    # in case no "metric" was specified - run on all metrics
    for i in $(redis-cli -h $redis_host -p 12006 -n 10 keys checks:\*|grep $HOSTNAME); do
        metric=$(echo "$i" | cut -d: -f2 | sed "s/_$HOSTNAME//")
        $0 $metric
    done
    exit 0
fi

farms=$(egrep ^" " /mnt/data/monitoring/structure.yml)
for i in $farms; do
    [[ "$HOSTNAME" == "main-$i" ]] && farm=$i
done

function size_addapter () {
  symbol="bytes"
  let len=$(echo "$1" | wc -m)-1
  if [ $len -lt 4 ]
  then
    size=$1
    symbol="b"
  elif [ $len -lt 7 ]
  then
    dec=${1: -3}
    size="${1%${dec}}.${dec::1}"
    symbol="Kb"
  elif [ $len -lt 10 ]
  then
    let size=$1/1000
    dec=${size: -3}
    size="${size%${dec}}.${dec::1}"
    symbol="Mb"
  elif [ $len -lt 13 ]
  then
    let size=$1/1000000
    dec=${size: -3}
    size="${size%${dec}}.${dec::1}"
    symbol="Gb"
  else
    let size=$1/1000000000
    dec=${size: -3}
    size="${size%${dec}}.${dec::1}"
    symbol="Tb"
  fi
  ans="[$size]$symbol"
  echo $ans
}

function create_metric () {
    local mtrc=$1
    local message=$2
    local problem=$3
    local var=$4
    local warn=$5
    local crit=$6

    [[ ! "$metric" ]] && [[ "$(redis-cli -h $redis_host -p 12006 -n 10 GET "metrics:${mtrc}_${HOSTNAME}")" ]] && return

    if [[ -n "$var" ]] && [[ -n "$warn" ]] && [[ -n "$crit" ]]; then
        if [[ $var -lt $warn ]]; then
            redis-cli -h $redis_host -p 12006 -n 10 SETEX "metrics:${mtrc}_${HOSTNAME}" 86400 "OK:       ${message}" &>/dev/null
        elif [[ $var -lt $crit ]]; then
            redis-cli -h $redis_host -p 12006 -n 10 SETEX "metrics:${mtrc}_${HOSTNAME}" 86400 "WARNING:  $(echo "${message}"|grep -v PROBLEM)\n${problem}" &>/dev/null
        else
            redis-cli -h $redis_host -p 12006 -n 10 SETEX "metrics:${mtrc}_${HOSTNAME}" 86400 "CRITICAL: $(echo "${message}"|grep -v PROBLEM)\n${problem}" &>/dev/null
        fi
    else
        redis-cli -h $redis_host -p 12006 -n 10 SETEX "metrics:${mtrc}_${HOSTNAME}" 86400 "$(echo "${message}"|grep -v PROBLEM)\n${problem}" &>/dev/null
    fi
}

######################################### metric checks #########################################

function metric_backups () {
    data=$(/mnt/data/monitoring/bin/backups_check.sh)
    problem=$(echo "$data" | grep "PROBLEM")
    create_metric "$metric" "$data" "$problem"
}

function metric_backups-AWS-EBS () {
    data=$(/mnt/data/monitoring/bin/EBS_backup_check.sh)
    problem=$(echo "$data" | grep "PROBLEM")
    create_metric "$metric" "$data" "$problem"
}

function metric_bare-metal-mem () {
    total_slots=$(/usr/sbin/dmidecode -t 17 | grep "Memory Device" | wc -l)
    message="Total Slots - $total_slots\n"
    used_slots=0
    for slot in $(/usr/sbin/dmidecode -t 17 | grep "^Handle" | awk '{print $2}'); do
        slot_data=$(/usr/sbin/dmidecode -t 17 | grep -A22 "$slot")

        locator=$(echo "$slot_data" | grep "Locator:" | head -1 | awk '{print $2}')

        # check if slot is in use
        manufacturer=$(echo "$slot_data" | grep "Manufacturer:" | cut -d: -f2)
        serial_number=$(echo "$slot_data" | grep "Serial Number:" | cut -d: -f2)
        if [[ "$manufacturer" == " Not Specified" ]] && [[ "$serial_number" == " Not Specified" ]]; then
            unused_slots="${unused_slots},${locator} "
            continue
        fi
        let used_slots++

        # check for problems
        error_info=$(echo "$slot_data" | grep "Error Information Handle:" | cut -d: -f2)
        if [[ "$error_info" == " Not Provided" ]]; then
            message="${message}OK:       Memory Slot - $locator\n"
        else
            message="${message}Critical: Memory Slot - $locator - $error_info\n"
            problems="${problems}PROBLEM:$locator - $error_info\n"
        fi
        ### could add a test for amount of wanted slots (using $used_slots)
    done

    message="${message}\nUnused Slots - ${unused_slots/,/}"

    create_metric "$metric" "$message" "$problems"
}

function metric_disk () {
    partitions=$(df | egrep -vi "loop|snap|shm|cgmfs|none|tmpfs|udev|Used|overlay|127.0.0.1" | awk '{print $NF}')
    for i in $(seq $(echo $partitions | wc -w)); do
        part=$(df | egrep -vi "loop|snap|shm|cgmfs|none|tmpfs|udev|Used|overlay|127.0.0.1" | sed -n ${i}p)
        inode=$(df -i | egrep -vi "loop|snap|shm|cgmfs|none|tmpfs|udev|Used|overlay|127.0.0.1" | sed -n ${i}p)
        mnt=$(echo $part | awk '{print $NF}')
        [[ "$mnt" == "/mnt/data/ipfs3" ]] && continue
        mnt_type=$(grep " $mnt " /etc/mtab | awk '{print $3}')
        if [[ -z "$mnt_type" ]] || [[ "$mnt_type" == "fuse.sshfs" ]] || [[ "$mnt_type" == "fuse.glusterfs" ]] || [[ "$mnt_type" == "fuse.s3fs" ]] || [[ "$mnt_type" == "nfs" ]] || [[ "$mnt_type" == "nfs4" ]]; then
            continue
        fi
        size_percentage=$(echo $part | awk '{print $5}') # with %
        size_free="$(echo $part | awk '{print $4}')000"
        size_total="$(echo $part | awk '{print $2}')000"
        inode_percentage=$(echo $inode | awk '{print $5}') # with %
        [[ "$inode_percentage" == "-" ]] && inode_percentage="0%"
        inode_free="$(echo $inode | awk '{print $4}')000"
        inode_total="$(echo $inode | awk '{print $2}')000"

        message_size=$(echo "$mnt - Total Space: $(size_addapter "$size_total"), Free Space: $(size_addapter "$size_free"), Used: $size_percentage")
        message_inode=$(echo "$mnt - Total Inode Space: $(size_addapter "$inode_total"), Free Inode Space: $(size_addapter "$inode_free"), Used: $inode_percentage")
        if [[ "${size_percentage//%/}" -lt 90 ]]; then
            total_messages="${total_messages}OK:       $message_size\n"
        elif [[ "${size_percentage//%/}" -lt 95 ]]; then
            total_messages="${total_messages}Warning:  $message_size\n"
            total_problems="${total_problems}PROBLEM:FS: $mnt - Disk Usage: $size_percentage\n"
        else
            total_messages="${total_messages}Critical: $message_size\n"
            total_problems="${total_problems}PROBLEM:FS: $mnt - Disk Usage: $size_percentage\n"
        fi
        if [[ "${inode_percentage//%/}" -lt 75 ]]; then
            total_messages="${total_messages}OK:       $message_inode\n"
        elif [[ "${inode_percentage//%/}" -lt 90 ]]; then
            total_messages="${total_messages}Warning:  $message_inode\n"
            total_problems="${total_problems}PROBLEM:FS: $mnt - Inode Usage: $inode_percentage\n"
        else
            total_messages="${total_messages}Critical: $message_inode\n"
            total_problems="${total_problems}PROBLEM:FS: $mnt - Inode Usage: $inode_percentage\n"
        fi
    done
    create_metric "$metric" "$total_messages" "$total_problems"
}

function metric_dns () {
    ns=$(grep -v "^#" /etc/resolv.conf |grep nameserver|head -n 1|awk '{ print $2 }')
    dc=$(timeout 2 curl -s http://$ns:8500/v1/agent/self|jq -r .Config.Datacenter)
    domain=$(timeout 2 curl -s http://$ns:8500/v1/agent/self|jq -r .DebugConfig.DNSDomain)

    [[ "$dc" ]] || dc=$site
    [[ "$domain" ]] || domain="catchmedia.com"

    consul="consul.service.$dc.$domain"
    node="$HOSTNAME.node.$dc.$domain"

    ping -c 1 $consul >/dev/null 2>&1
    if [[ $? -eq 0 ]]; then
        res1="OK: $consul"
    else
        res1="Warning: $consul failed"
        prb1="PROBLEM:$consul failed"
    fi

    ping -c 1 $node >/dev/null 2>&1
    if [[ $? -eq 0 ]]; then
        res2="OK: $node"
    else
        res2="Warning: $node failed"
        prb2="PROBLEM:$node failed"
    fi
    message="$res1\n$res2"
    problem="$prb1\n$prb2"
    create_metric "$metric" "$message" "$problem"
}

function metric_docker-mount () {
    data=$(/mnt/data/monitoring/bin/docker_mount_check.sh)
    problem=$(echo "$data" | grep "PROBLEM")
    create_metric "$metric" "$data" "$problem"
}

function metric_efs-load () {
    path="/mnt/etldata/csv/"
    files_count=$(ls $path | wc -l)
    war=20000
    crt=100000
    message="The amount of files in [$path] is [$files_count]"
    problem="PROBLEM:PATH:[$path]-Files:[$files_count]"
    create_metric "$metric" "$message" "$problem" $files_count $war $crt
}

function metric_integmon () {
    data=$(/mnt/common/opsfs/systools/bin/nagios/opsmonscripts_runner.sh $integmon_check 2>&1)
    problem=$(echo "$data" | grep "PROBLEM")
    create_metric "${metric}-${integmon_check}" "$data" "$problem"
}

function metric_load () {
    min1=$(uptime | awk '{print $(NF-2)}')
    min5=$(uptime | awk '{print $(NF-1)}')
    min15=$(uptime | awk '{print $NF}')
    cpus=$(lscpu | grep CPU | sed -n 2p | awk '{print $2}')
    let war=${cpus}*2
    let crt=${cpus}*4
    [[ $war -lt 5 ]] && war=5
    [[ $crt -lt 7 ]] && war=7
    message="$HOSTNAME -- 1-MIN: $min1 5-MIN: $min5 15-MIN: $min15"
    problem="PROBLEM:CPU(s)=$cpus --- 15 Min Load: $min15"
    create_metric "$metric" "$message" "$problem" "${min15%.*}" $war $crt
}

function metric_memory () {
    total=$(free -b | grep -i mem | awk '{print $2}')
    available=$(free -b | grep -i mem | awk '{print $NF}')
    let percent=($total-$available)*100/$total
    message="Total Memory: $(size_addapter "$total"), Available Memory: $(size_addapter "$available"), Used: $percent%"
    problem="PROBLEM:Used: $percent%"
    create_metric "$metric" "$message" "$problem" $percent 90 95
}

function metric_nfs () {
    server_or_client=$(showmount &>/dev/null && echo server || echo client)
    fs=$(mount | egrep -iw '/mnt/data|/mnt/infra|/mnt/common|/mnt/sys' | awk '{print $3}' | sort | uniq)
    check_lxc=$(grep --quiet "UNCONFIGURED FSTAB FOR BASE SYSTEM" /etc/fstab && echo lxc || echo vm)
    [[ "$check_lxc" == "lxc" ]] && fs=$(mount | egrep -iw '/mnt/data|/mnt/common' | awk '{print $3}' | sort | uniq)
    for i in $fs; do
        check_nfs=$(cat $i/.mounted 2>/dev/null)
        mnt_point=$(mount | grep $i | awk '{print $1}')
        if [[ "$check_nfs" ]]; then
            message="${message}$i - OK\n"
        else
            while true; do
                umount -f $mnt_point
                [[ $? -ne 0 ]] && break
            done
            mount $mnt_point
            if [[ "$check_nfs" ]]; then
                message="${message}$i - OK (was fixed after \"Stale file handle\")\n"
            else
                message="${message}$i - Warning: Not mounted properly\n"
                problem="${problem}PROBLEM: $i\n"
            fi
        fi
    done
    if [[ "$server_or_client" == "server" ]]; then
        amount=$(showmount -a | egrep '10\.' | wc -l)
        ips=$(showmount -a | egrep '10\.' | cut -d: -f1 | sort | uniq)
        counter=0
        for i in $(redis-cli -h $redis_host -p 12006 -n 10 KEYS "metrics:nfs_*"); do
            domain=$(echo $i|awk -F / '{print $NF}')
            ip=$(host $domain | grep address | awk '{print $NF}')
            [[ ! "$ips" =~ "$ip" ]] && continue
            let lines=$(cat $i | wc -l)-1
            for j in $(seq 2 $lines); do
                mnt=$(cat $i | sed -n ${j}p | awk '{print $1}' |rev| cut -d/ -f1 |rev)
                [[ "$mnt" == "_data" ]] && mnt="data"
                [[ -n "$(showmount -a | grep $ip | grep $mnt)" ]] && let counter++
            done
        done
        [[ "$counter" -eq "$amount" ]] && message="${message}OK: all mounts are present\n"
    fi
    create_metric "$metric" "$message" "$problem"
}

function metric_portworx-disk () {
    data=$(pxctl status -j | grep -B55 -A155 $HOSTNAME | sed -n '/^   {$/,/^   }$/p' | jq .)

    disk_size=$(echo "$data" | jq -r .Disks[].size)
    allocated_disk=$(echo "$data" | jq -r .NodeData.\"STORAGE-RUNTIME\".Usage.TotalAllocated)
    let allocated_percentage=$allocated_disk*100/$disk_size

    node_name="$HOSTNAME"
    node_id=$(echo "$data" | jq -r .Id)

    message="\nNode: $node_name\nNodeId: $node_id\nDisk Size: $(size_addapter "$disk_size"), Allocated Disk: $(size_addapter "$allocated_disk"); $allocated_percentage%"
    problem="PROBLEM:Node: $node_name - Use: $allocated_percentage%"

    create_metric "$metric" "$message" "$problem" $allocated_percentage 75 90
}

function metric_portworx-volume () {
    num_of_volumes=$(pxctl v l -j | jq -r .[].locator.name | wc -l)
    for i in $(seq $num_of_volumes); do
        volume_name=$(pxctl v l -j | jq -r .[$i-1].locator.name)
        volume_size=$(pxctl v l -j | jq -r .[$i-1].spec.size)
        volume_usage=$(pxctl v l -j | jq -r .[$i-1].usage)
        let volume_usage_percentage=$volume_usage*100/$volume_size
        message="Volume Name: $volume_name, Volume Size: $(size_addapter "$volume_size"), Allocated Volume: $(size_addapter "$volume_usage"); $volume_usage_percentage%"
        if [[ "$volume_usage_percentage" -le 80 ]]; then
            total_message="${total_message}OK:       $message\n"
        elif [[ "$volume_usage_percentage" -lt 90 ]]; then
            total_message="${total_message}Warning:  $message\n"
            problem="${problem}PROBLEM:Name: $volume_name; $volume_usage_percentage%\n"
        else
            total_message="${total_message}Critical: $message\n"
            problem="${problem}PROBLEM:Name: $volume_name; $volume_usage_percentage%\n"
        fi
    done
    create_metric "$metric" "$total_message" "$problem"
}

function metric_raid () {
    data=$(/mnt/data/monitoring/bin/publish_raid_metrics.sh)
    problem=$(echo "$data" | grep "PROBLEM")
    create_metric "$metric" "$data" "$problem"
}

function metric_raid-consistency () {
    data=$(/mnt/data/monitoring/bin/lsi_raid_consistency_checks.sh)
    problem=$(echo "$data" | grep "PROBLEM")
    create_metric "$metric" "$data" "$problem"
}

function metric_redis () {
    data=$(/mnt/data/monitoring/bin/redis_checks.sh)
    problem=$(echo "$data" | grep "PROBLEM")
    create_metric "$metric" "$data" "$problem"
}

function metric_shfp () {
    data=$(/opt/shfp/bin/nagios_output.sh)
    problem=$(echo "$data" | grep "PROBLEM")
    create_metric "$metric" "$data" "$problem"
}

function metric_ssh () {
    ip=$(host jump.$site.catchmedia.com | grep "address" | awk '{print $NF}')
    data=$(echo quit | timeout 5 telnet jump.$site.catchmedia.com 22 2>/dev/null | egrep -qi Connected ; echo $?)
    [[ -n "$(timeout 5 netstat 2>/dev/null| grep $ip:22)" ]] && data=0
    [[ "$(last -s $(date -d "3 days ago" +%Y%m%d%H%M%S) | wc -l)" -gt 1 ]] && data=0
    message="$HOSTNAME -- SSH status exit code: $data"
    problem="PROBLEM: exit code: $data"
    create_metric "$metric" "$message" "$problem" $data 1 200
}

function metric_swap () {
    total=$(free -b | grep -i swap | awk '{print $2}')
    used=$(free -b | grep -i swap | awk '{print $3}')
    [[ $total -eq 0 ]] && total=1
    let percent=$used*100/$total
    free=$(free -b | grep -i swap | awk '{print $4}')
    message=$(echo "$HOSTNAME -- Total Swap: $(size_addapter "$total"), Free Swap: $(size_addapter "$free"), Used: $percent%")
    problem="PROBLEM: Used: $percent%"
    create_metric "$metric" "$message" "$problem" $percent 85 90
}

function metric_swappiness () {
    data=$(/mnt/data/monitoring/bin/swappiness/swappiness_test.sh)
    problem=$(echo "$data" | grep "PROBLEM")
    create_metric "$metric" "$data" "$problem"
}

function metric_vertica-state () {
    data=$(/mnt/data/monitoring/bin/vertica_state.sh)
    problem=$(echo "$data" | grep "PROBLEM")
    create_metric "$metric" "$data" "$problem"
}

function metric_vertica-storage () {
    data=$(/mnt/data/monitoring/bin/vertica_storage.sh)
    problem=$(echo "$data" | grep "PROBLEM")
    create_metric "$metric" "$data" "$problem"
}

if [[ "$metric" =~ "integmon" ]]; then
    integmon_check=$(echo $metric | cut -d- -f2)
    metric="integmon"
fi

case $metric in
backups) metric_backups;;
backups-AWS-EBS) metric_backups-AWS-EBS;;
bare-metal-mem) metric_bare-metal-mem;;
disk) metric_disk;;
dns) metric_dns;;
docker-mount) metric_docker-mount;;
efs-load) metric_efs-load;;
integmon) metric_integmon;;
load) metric_load;;
memory) metric_memory;;
nfs) metric_nfs;;
portworx-disk) metric_portworx-disk;;
portworx-volume) metric_portworx-volume;;
raid) metric_raid;;
raid-consistency) metric_raid-consistency;;
redis) metric_redis;;
shfp) metric_shfp;;
ssh) metric_ssh;;
swap) metric_swap;;
swappiness) metric_swappiness;;
vertica-state) metric_vertica-state;;
vertica-storage) metric_vertica-storage;;
*) echo "ERROR: Unknown metric [$metric]" && exit 1;;
esac
