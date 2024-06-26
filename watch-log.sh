#!/usr/bin/bash
#
if [ `hostname`=="cc-testmaps" ]; then
    # we're running in compose
    service='varnish-varnish'
else
    # we're running in swarm
    service='varnish-varnish'
fi
id=`docker ps -f name=$service -q`

if [ "$id" == "" ]; then
  echo "Is varnish running?"
  exit 1
fi

docker exec $id varnishlog


