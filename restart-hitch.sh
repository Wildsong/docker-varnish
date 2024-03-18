#!/bin/bash
#
#   Update hitch _in swarm or not_
#
#   I should only do this if the hitch bundle changed,
#   but I just run it once a week after checking certs.
#   Does not hurt to restart, does it? Makes it easy too.
#

hitch=`docker stack services varnish | grep hitch | cut -b-12`
if [ -n "$hitch" ]; then
    docker service update --force $hitch
    echo "Updated"
else
    echo "Not running in swarm, try compose option."
    hitch=`docker ps | grep hitch | cut -b-12`
    if [ -n "$hitch" ]; then
	docker container restart $hitch
	echo "Restarted"
    else
	echo "Could not restart Varnish Hitch, is it running?"
    fi
fi
