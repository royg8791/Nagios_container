#!/bin/bash -l
#
# The script is run inside of each started container
#
# DO NOT MODIFY LOCALLY: It is always overwritten by container, for custom changes use setup_custom.sh
#

echo "setup.sh started on [$PARENT_HOST]" >/tmp/setup.log

# Replace stock check_nrpe as it has hardcoded limit of 1024 bytes on NRPE server reply
cp /opt/package_dist/check_site /opt/nagios/libexec/check_site

cd /opt/package
if [ -f .mounted ];
then
  echo "/opt/package is persistent, setting up etc symlink" >> /tmp/setup.log
  rm -rf /opt/nagios/etc/sites
  ln -s /opt/package/etc/sites /opt/nagios/etc/sites
  rm -rf /opt/nagios/etc/objects
  ln -s /opt/package/etc/objects /opt/nagios/etc/objects
  rm -rf /opt/nagios/var/
  ln -s /opt/package/var /opt/nagios/var
  # returning all permissions
  usermod -a -G nagios www-data # www-data is apache2 user
  chmod 666 /usr/local/nagios/var/rw/nagios.cmd
  chmod 2774 /usr/local/nagios/var/rw

  runsv /etc/service/nagios/ &

  sv restart nagios
  sv restart apache2
else
  # configure nagios container from scratch, should never be needed as we want sites to sit on persistent volume
  echo Error: nagios always must run with persistent volume on /opt/package
  echo Error: nagios always must run with persistent volume on /opt/package > /etc/motd
  exit 0
fi
mkdir -p /opt/nagios/etc/tmp
chown -R nagios:nagios /opt/nagios/
rm -f /opt/nagios/etc/objects/windows.cfg

# apache and nagios into sudoers.d
rm -rf /etc/sudoers.d/[^R]*
echo "ops ALL:(ALL) NOPASSWD:ALL" > /etc/sudoers.d/ops
echo "nagios ALL:(ALL) NOPASSWD:ALL" > /etc/sudoers.d/nagios

if [ -x setup_custom.sh ];
then
  echo "Detected ./setup_custom.sh, starting..." >> /tmp/setup.log
  ./setup_custom.sh &>> /tmp/setup.log
fi

# hotfix for cmapache
rm -f /etc/cron.d/cmcron-pa-expire_idle_sessions 

# Run acros_init.sh to populate templates,objects and sites
nohup /opt/nagios/etc/acros_init.sh &
# reloads nagios every 30 minutes to make sure new checks are added to the system
echo "# error.log abd problem.log monitoring
*/15 * * * * root /opt/nagios/etc/config/nagios_error_log.sh

# save data from /opt/nagios/var/ in case of failover
0 * * * * root cp -rf /opt/nagios/var/ /opt/package/var
" > /etc/cron.d/nagios_reload
