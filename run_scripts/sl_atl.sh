#!/bin/bash

CNAME=salt-ng
IMAGE=gitregs.catchmedia.com/component/salt-ng:latest

docker pull ${IMAGE}

docker stop ${CNAME}; docker rm ${CNAME}

docker run -idt --name ${CNAME} --restart always \
  -p 8085:80 \
  -v /tmp:/tmp \
  --env PARTNERSITE_HOST="pa-atl.catchmedia.com" \
  --env REPORTS_HOST="reports-atl.catchmedia.com" \
  --env PA_HOST="pa-atl.catchmedia.com" \
  ${IMAGE}

