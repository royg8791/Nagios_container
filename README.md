# ACROS
Automatic Checks Registration & Orchestration System (ACROS)

## General description

ACROS system is build out of several components:
  * **Machines** to monitor
  * **Redis** server on every Site
  * **NRPE** container on every Site
  * **Nagios** container

#### The way it works

1. every Site has a NRPE container and a Redis-server

2. all Machines (of this Site) store relevant data on the Redis-server

3. NRPE connects to the Redis-server to retrieve wanted data about a machine

4. Nagios then connects to NRPE to get the wanted data and uploads it to the browser

![image](https://github.com/royg8791/Nagios_container/blob/main/components.jpg)

## Machines
Every machine in the system will have different checks to monitor accorfing to the machines characteristics and components.
The Idea was to create a system that checks what kind of checks need to be run on the machine and monitor them accordingly.

The way to do so is located in **__/opt/rolmin/nagios/register_checks.sh__**.

__To add a new machine to this system__: you simply have to run a script located in **__/mnt/common/rolmin/setup.sh__**

This script will add several things to the local machine:
  * /opt/rolmin/ directory (including nagios scripts in "nagios" directory)
  * cron that runs every minute (/etc/cron.d/rolmin) that initiates all relevant scripts
## Redis
Every Site has its own dedicated Redis-server:
```
NIF  - 10.3.14.38  - ops_sdemo       << redis-server
PROD - 10.3.8.133  - ops_clix        << redis-server
SLIV - 10.13.7.187 - ops_sonyliv     << redis-server
```
  * all Redis-servers use the same Ports and Database
  * Port = 12006
  * DB = 10
Every Machine is "listening" to specific changes in data inside the Redis-server
  * from a scrip - /opt/rolmin/nagios/subscribe_redis.sh
    * there is a method called subscribe in Redis that listens to a channel for given changes.
    * __run_checks:*__ - if the machine will see this inside the Redis-server it will delete all current checks and run /opt/rolmin/nagios/register_checks.sh that will populate new checks.
    * __run_metrics:*__ - will delete all current metrics and run /opt/rolmin/nagios/publish_metrics.sh that will populate new metrics.
    * __rechek:*__ - will run /opt/rolmin/nagios/register_checks.sh for a specific check.
    * __remetric:*__ - will run /opt/rolmin/nagios/publish_metrics.sh for a specific metric.
Example for seting a metric inside the Redis-server:
  * From evry machine **/opt/rolmin/nagios/publish_metrics.sh**
```
redis-cli -h 10.3.14.38 -p 12006 -n 10 SETEX "metrics:${mtrc}_${HOSTNAME}" 86400 "OK:       ${message}"
```
Another example for geting all data for a Site/Farm:
  * From NRPE **/opt/nrpe/bin/cmnrpe_gather_checks**
```
redis-cli -h 10.3.14.38 -p 12006 -n 10 MGET $checks
```
**Bonus** - how to get all Checks and Metrics from the Redis-server:
```
redis-cli -h 10.3.14.38 -p 12006 -n 10 KEYS \*
```
## NRPE
**N**agios **R**emote **P**lugin **E**xecutor

__To connect:__ (NIF Site)
```
ops@jump_nif:~$ docch nrpe
root@nrpe:/#
```
NRPE stores all its relevant components in 2 locations:
  * /opt/nrpe/bin
    * Here are all scripts that are executed by Nagios when connecting to NRPE and asking for data.
    * Script: cmnrpe_gather_checks - gathers data about what checks to run on every Site/Farm
    * Script: cmnrpe_gather_metrics - gathers data about individual checks that run on Nagios
    * Script: cmnrpe_script - runs specific scripts given from CLI input.
  * /etc/nagios/nrpe.d
    * inside you'll find a file, cm-nagios.cfg, that contains all available commands to use on this NRPE server.
__To add a new command:__
```
command[cmnrpe_gather_metrics]=/opt/nrpe/bin/cmnrpe_gather_metrics $ARG1$ $ARG2$ $ARG3$
```
  * add the command to /etc/nagios/nrpe.d/cm-nagios.cfg: (example for cmnrpe_gather_metrics)
    * command name = "cmnrpe_gather_metrics"
    * command script = "/opt/nrpe/bin/cmnrpe_gather_metrics"
    * add "$ARG1$ $ARG2$ $ARG3$" so you coul'd run 3 args from Nagios CLI if needed
  * After adding all of the abbove, you'll have to reload NRPE service:
```
/etc/init.d/nagios-nrpe-server reload
```
## Nagios
__To connect:__
```
ops@jump_nif:~$ docch nagios
root@nagios:/# 
```
Nagios Path which contains all Nagios components - **/opt/nagios/**.

1. /opt/nagios/etc/:
```
root@nagios:/opt/nagios/etc# ls
acros_init.sh  cgi.cfg  config  htpasswd.users  nagios.cfg  objects  resource.cfg  sites  tmp
```
  * __acros_init.sh__ - runs only on container startup to build the entire system using scripts from config/ Dir.
  * __cgi.cfg__, __nagios.cfg__, __resources.cfg__ - configuration files for Nagios system to read.
  * __config/__ - contains configuration file builders for all components needed for nagios.
    * every script will built a configuration file inside __tmp/__ Dir.
    * the file will be tested for broken data.
    * if the file is good, it will be transfered to the right location.
  * __objects/__, __sites/__ - directories containing all configuration files for all Sites/Farms/Machines/etc.
2. /opt/nagios/libexec/:
  * contains libraries, binaries and scripts crucial for Nagios.
  * Nagios uses **check_nrpe** to comunicate with all NRPE servers:
    * check_nrpe connects to a **Host** (NRPE DNS/IP(in this case NIF - nrpe.nif.catchmedia.com)) and runs a **command** (cmnrpe_gather_checks) on the Hosts NRPE with given **arguments** (nif atl)
```
/opt/nagios/libexec/check_nrpe -H nrpe.nif.catchmedia.com -t 600 -c cmnrpe_gather_checks -a nif atl
```
3. /opt/nagios/var/:
  * **nagios.log**:
    * read this to find out what causes the system to break.
    * you will know what scripts (from /opt/nagios/etc/config/) to run according to the log file.

## Add New Checks
In order to add a new check that checks only machines that qualify for the check, you'll need to do 3 things:

1. Create a Script that checks the wanted data, that includes:
  * Output of the script has to look like this: (look at Nagios alerts output on the browser)
```
OK:       $message
Warning:  $message
Critical: $message
```
  * For every problem (warning/critical), add a line that will output “PROBLEM:$message”:
    * (this will show up on the “Status Information” line on the Nagios Dashboard)
```
if [[ X =! Y ]]; then
    echo "Warning:  $message"
    echo "PROBLEM:$message"
```
  * ### use script from /mnt/common/rolmin/dev/nagios/bin/ for reference
2. Add a way to register the cehck only with relevant machines - /mnt/common/rolmin/dev/nagios/register_checks.sh
```
if [[ $(/opt/MegaRAID/MegaCli/MegaCli64 -v &>/dev/null;echo $?) -eq 0 ]]; then
    check_list "raid" 60 "cmnrpe_gather_metrics" "raid" "$HOSTNAME"
fi
```
  * Example: if the machine can run this “command” without fail then add thew check.
  * check name needs to replace “raid” (make sure the “check_name” is unique and isn't already used).
3. Publish metrics when needed - /mnt/common/rolmin/dev/nagios/publish_metrics.sh
  * add a Function that runs the script you wrote in section “1”:
```
function metric_raid () {
    data=$(/opt/rolmin/nagios/bin/publish_raid_metrics.sh)
    problem=$(echo "$data" | grep "PROBLEM")
    create_metric "$metric" "$data" "$problem"
}
```
  * Change “raid” to your unique “check_name”
  * Copy this function and just change the script it points to, to your script.
  * then add a “calling” for the function at the bottom of this script:
```
raid) metric_raid;;
```
  * again… change “raid” to your unique “check_name”
## Add New Farm
1. Make sure that all machines belonging to the farm have these things:
  * access to the parent Site's Redis-server and “redis-tools” installed for 'redis-cli' to work.
  * access to “/mnt/common/” for Nagios components instalation.
  * access to “/mnt/data/” for making sure Nagios will know this Farm is part of the Site's structure.
2. Install Nagios components by running /mnt/common/rolmin/setup.sh.

3. Add Farm name to the Structure in file - /mnt/data/monitoring/structure.yml
```
ops@jump_nif:~$ cat /mnt/data/monitoring/structure.yml 
nif:
  abp
  atl
  cmj
  nqa
```
4. Inside Nagios container run this script:
```
/opt/nagios/etc/acros_init.sh
```
## Add New Site
1. /mnt/data/ - create /mnt/data/monitoring/structure.yml including:
```
nif:
  abp
  atl
  cmj
  nqa
```
  * Site Name instead of “nif” and list of Farms accordingly.
  * Make sure all machines and Farms have access to this /mnt/data/ Directory (private per Site).
2. Create a dedicated Redis-server for Nagios.
  * Edit these scripts:
    * /mnt/common/rolmin/dev/nagios/register_checks.sh
    * /mnt/common/rolmin/dev/nagios/publish_metrics.sh
    * /mnt/common/rolmin/dev/nagios/subscribe_redis.sh
    * /mnt/common/rolmin/dev/every_1_minute.sh
  * Add the Redis-server with Site name to it:
```
[[ "$site" == "nif" ]] && redis_host="10.3.14.38"
[[ "$site" == "prod" ]] && redis_host="10.3.8.133"
[[ "$site" == "sliv" ]] && redis_host="10.13.7.187"
```
3. /mnt/common/ - mount /mnt/common from NIF so that you'll have access to /mnt/common/rolmin directory.
  * Make sure that all machines and farms have access too.
  * Run the script /mnt/common/rolmin/setup.sh on all machines inside the Site.
4. Create a NRPE container using the Gitlab Repo
  * Like in section “2” add the Redis-server and Site name to these scripts inside the NRPE container:
    * /opt/nrpe/bin/cmnrpe_gather_checks
    * /opt/nrpe/bin/cmnrpe_gather_metrics
  * Make sure the NRPE container has access to the Sites Redis-server
5. Go to the Nagios container: (inside)
```
ops@jump_nif:~$docch nagios
```
  * Edit /opt/nagios/etc/acros_init.sh - add the Sites name to the “site” list:
```
sites="nif prod sliv"
```
  * The run the script - /opt/nagios/etc/acros_init.sh
