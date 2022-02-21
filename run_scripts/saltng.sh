#!/bin/bash

CNAME=salt-ng
IMAGE=gitregs.catchmedia.com/component/salt-ng:latest

print_usage()
{
  echo "saltng.sh --farm=<[qa|spa|ais|atl]>"
}

farm=qa

parms=$#

print_params=$@

if [ $parms -le 1 ];
then
  print_usage
fi

while [ $# -ge 1 ]
do
  parm=$1;
  shift
  case $parm in
    --farm=*) farm=`sed 's/[^=]*=//' <<< "$parm"`
    ;;
    *)
    echo "!!!! Unknown parameter: [$parm]"
    print_usage
    ;;
  esac
done

farm=${farm,,}

docker pull ${IMAGE}

docker stop ${CNAME}; docker rm ${CNAME}

docker run -idt --name ${CNAME} --restart always \
  -p 8085:80 \
  -v /tmp:/tmp \
  --env PARTNERSITE_HOST="pa-${farm}.catchmedia.com" \
  --env REPORTS_HOST="reports-${farm}.catchmedia.com" \
  --env PA_HOST="pa-${farm}.catchmedia.com" \
  ${IMAGE}

