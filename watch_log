#!/usr/bin/bash
#
id=`docker ps | grep varnish_varnish | cut -b-12`

if [ "$id" == "" ]; then
  echo "Is varnish running?"
  exit 1
fi

docker exec $id varnishlog


