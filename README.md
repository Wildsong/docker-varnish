# docker-varnish

This project wraps Varnish in Docker Swarm.
There are two services, Varnish and Hitch, so it's set up
as a Docker Stack.

Varnish is used here mostly as a reverse proxy for Mapproxy.
Hitch does the TLS part, as a proxy between Varnish and the world.
Varnish and Hitch communicate using the "PROXY" protocol.

There are options here for "DNS Made Easy", "Cloudflare", and nothing, which uses a local web server.
The challenge web server option is commented out right now since there is no reason to run it
if using one of the API options.

## Serving configuration files using "docker config"

In Docker Compose, I used environment variables to control which files
would be used in volumes in that does not work with Docker Stack.

I need this to work in Swarm, and I also need it to be customized
for my different configurations. The file that the Varnish
container sees at "/etc/varnishd/default.vcl" is loaded from
an external config that you set up.

### How do I install in the config space for Swarm?

Two of the configs are loaded from files when you deploy the stack,
etc/hitch.conf and certs/hitch-bundle.pem. 

The Varnish file /etc/varnish/default.vcl is loaded from the config you specify. Here are the options for
initial set up, cc-testmaps (testing), cc-giscache (production), and bellman (testing at home).

   docker config create varnish_config etc/default.vcl
   docker config create varnish_config etc/default.cc-testmaps.vcl
   docker config create varnish_config etc/default.giscache.vcl
   docker config create varnish_config etc/default.wildsong.vcl
   docker config create varnish_config etc/default.w6gkd.vcl
   docker config create varnish_config etc/default.bellman.vcl

The contents are encrypted, I just overwrite them to update it.

### How it works

   docker service create --name www-test --config varnish_config --replicas 1 --publish 8010:80 nginx:latest
   docker ps | grep www-test  # find ID
   docker exec -it <ID> bash

In the bash shell the "mount" command shows that the file
is mounted as a tmpfs on /varnish_config and I can "cat" it.

### How do I get the services to use the files?

The files will be available as files, I just have to teach the container to use them instead of the defaults. That's done with the config option, in my test, like this.

   docker service rm www-test
   docker service create --name www-test --config src=varnish_config,target="/etc/varnish/default.vcl" --replicas 1 --publish 8010:80 nginx:latest
   docker ps | grep www-test  # find ID
   docker exec -it <ID> bash

This is cool.

## Prerequisites

Firewall: Your firewall must route traffic for port 80 and 443 to the
machine running Varnish. After that, it can proxy services that are
behind the firewall.

Certificates: Hitch needs bundled Let's Encrypt certificates. I manage
them separately with https://github.com/Wildsong/docker-letsencrypt. 

### Restart hitch periodically

Let's Encrypt certificates are good for 90 days, so you should restart
hitch every time the certs change; it keeps them in memory, apparently.

It's easiest to just retsart hitch once a week after the entry that
does the Let's Encrypt thing.

   crontab -e
   # Restart hitch to load certificates
   30 4  * * 0  cd $HOME/docker/varnish && ./restart-hitch.sh

## Deployment

I use Compose at home and Swarm at work.

### Compose

   docker compose up -d

### Swarm

   docker stack deploy --with-registry-auth -c swarm.yaml varnish

Make sure both of the services are starting! But give it some time! (A minute is plenty)
Hitch will complain about not being able to find Varnish, and restart a few times before Varnish comes online.
You can watch the "REPLICAS" column here and eventually it should show "1/1".

   docker service ls

### Streaming the Varnish logfile

You can watch all the extensive and detailed log messages by doing
this. This is more useful on the development machine, since you will
have to sort out what traffic you are interested in on the production
machine.

   id=`docker ps | grep varnish_varnish | cut -b-12`
   de $id varnishlog

## TESTS

There's a program included with Varnish called varnishtest and you should look at it!
See a demonstration of how it can be used here.
https://info.varnish-software.com/blog/rewriting-urls-with-varnish

### Test supported URLs

My unittest.py script is now in the "www" project.

### Debugging

#### Won't start?

Try running in docker compose, in foreground, it's chatty,

   docker compose up

#### Check varnishlog

1. In terminal #1, watch the very detailed log,

   id=`docker ps | grep varnish_varnish | cut -b-12`
   docker exec -it $id varnishlog

2. In terminal #2, send a request with curl and stand back.

   curl -v https://foxtrot.clatsopcounty.gov/

## Notes on WMS metadata etc...

When I do a get on a base URL with Esri I get a nice information page.
When I do that on Mapproxy, I get a 404 error. How can I fix this?

First off, here is the URL I used as an example of an ESRI server.

Doing a get of this vector tile service returns a JSON file.
https://basemaps.arcgis.com/arcgis/rest/services/OpenStreetMap_v2/VectorTileServer

ESRI points right at the source for the Map version, centered on the US
https://www.openstreetmap.org/#map=5/38.007/-95.844

Here is a WMS service, which returns the classic ugly XML output
https://ch-osm-services.geodatasolutions.ch/geoserver/ows?service=wms&version=1.3.0&request=GetCapabilities&srsName=EPSG:2056
and the classic ugly "no service" XML page if you ask for https://ch-osm-services.geodatasolutions.ch/geoserver/ows without any parameters

http://imagery.oregonexplorer.info/arcgis/rest/services/NAIP_2009/NAIP_2009_WM/ImageServer
https://imagery.oregonexplorer.info/arcgis/services/NAIP_2009/NAIP_2009_WM/ImageServer/WMSServer?request=GetCapabilities&service=WMS

https://imagery.oregonexplorer.info/arcgis/rest/services/OSIP_2018/OSIP_2018_SL/ImageServer

## Flush the cache

You could just restart or you can look up the id and then use a varnishadm command. Something like this:

    docker ps | grep varnish_varnish
    de 9c9138e4e5ca varnishadm 'ban req.url ~ .'

## Resources

Future self: Go look up Varnish and Docker and put the links here

## TO DO LIST

* Add a healthcheck for Hitch
* Make a better healthcheck for Varnish
