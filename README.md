# ACROS
Automatic Checks Registration & Orchestration System (ACROS)

## General description

ACROS system is build out of several components:
  * **Machines** to monitor
  * **Redis** server on every Site
  * **NRPE** container on every Site
  * **Nagios** container

![image](https://github.com/royg8791/Nagios_container/blob/main/components.jpg)

#### The way it works

1. every Site has a NRPE container and a Redis-server

2. all Machines (of this Site) store relevant data on the Redis-server

3. NRPE connects to the Redis-server to retrieve wanted data about a machine

4. Nagios then connects to NRPE to get the wanted data and uploads it to the browser

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
Every Machine is "listening" to specific changes in data insode the Redis-server
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
## Add New Farm
## Add New Site


