#!/bin/bash
#
#   You can run this to either start or update Varnish.
#
cd $HOME/docker/varnish/
docker stack deploy --with-registry-auth -c compose.yaml varnish
docker service ls
