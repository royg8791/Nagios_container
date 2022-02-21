#!/bin/bash
#
# run package setup.sh
#

# Populate /opt/package if needed
if [ ! -x /opt/package/setup.sh ];
then
  # /opt/package is empty, need to recreate
  if [ -x /opt/package_dist/setup.sh ];
  then
    mkdir -p /opt/package
    cd /opt/package_dist
    cp -ra * /opt/package/
  fi
else
  # /opt/package already exists, likely persistent from a shared NFS or portworx directory
  # Always copy setup.sh from package_dist/setup.sh
  chmod 775 /opt/package/setup.sh  # to remove 555 permission
  cp /opt/package_dist/setup.sh /opt/package/setup.sh
  chmod 555 /opt/package/setup.sh
fi

cd /opt/package
./setup.sh &>/tmp/setup.sh.log

[ $? -gt 0 ] && echo THERE WERE ERRORS IN /etc/my_init.d/99_package_setup.sh >> /etc/motd

exit 0
