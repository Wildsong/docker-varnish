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

In Docker Compose, I used environment variables to control which files would be used in volumes in that does not work with Docker Stack.

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

Your firewall must route traffic for port 80 and 443 to the machine running Varnish. After that, it can proxy services that are behind the firewall.

### Set up "Let's Encrypt"

Hitch needs certificates. (That's why it exists after all, to do TLS.)

You need to have a dhparams.pem file. It will be baked into the certbot images;
the deploy hook script will copy dhparams.pem into the certificate bundle.
You should only have to create the dhparams.pem file one time, then add to your certs volume so that containers get get to it.

   openssl dhparam 2048 > dhparams.pem

#### Maintaining certificates

(including creating and renewing them) is done as a separate
workflow. If you don't use "DNS Made Easy" or Cloudflare for DNS, you
have to start certbot_challenge to respond to queries from Let's
Encrypt.

I have three default.vcl files, when setting up new domains I leave it set to the
default (default.vcl) then when I am moving into deployment, I set DEFAULT_VCL_FILE
in the .env file based on what I am doing (testing, production, or at home testing)
Follow the [correct VCL syntax](http://varnish-cache.org/docs/7.2/users-guide/vcl-syntax.html) 
There are many many things you can do with Varnish, I have barely started learning it.

* The default.vcl file just has the mininum needed to bootstrap getting certificates for hitch.
* To use DNS Made Easy challenges, you have to set up a dnsmadeeasy.ini file. See the sample.
* To use Cloudflare DNS challenges, you have to set up a cloudflare.ini file. See the sample.

Varnish (and the challenge server if you can't use DNSMadeEasy or CloudFlare)
even if you don't have any certs yet.

   docker stack deploy -c compose.yaml varnish

   docker cp dhparams.pem certs/

### Build certbot and create certificates

Build the correct Certbot image for your configuration. I use
DNSMadeEasy in this example.  **There are secrets in this image, so do
not send it to a public registry.**

Using DNSMadeEasy

   docker buildx build -f Dockerfile.dnsmadeeasy -t cc/certbot .
   docker run --rm cc/certbot --version
   ./run_certbot.sh

ELSE use Cloudflare API
   docker buildx build -f Dockerfile.cloudflare -t cc/certbot .
   docker run --rm cc/certbot --version
   ./run_cloudflare_certbot.sh

ELSE use the challenge server
    docker buildx build -f Dockerfile.challenge -t cc/certbot .
    ./run_certbot.sh
    
### Images for Varnish and Hitch

Hitch currently uses a standard image.
You have to build the image for Varnish.

   docker buildx build -t ghcr.io/clatsopcounty/varnish .
   docker push ghcr.io/clatsopcounty/varnish

(This relies on being logged in to github already.
"docker login ghcr.io -u bwilsoncc" for example)

## Note on combined "expanded" certificates

When I first started working with Let's Encrypt I was using one
certificate for each name, so for example I had one for
giscache.clatsopcounty.gov and one for giscache.co.clatsop.or.us. Then
I found the "--expand" option, which takes the full list of names and
returns one certificate that works for all of them. This made life
easier.

My .env file has this line:

DOMAINS="echo.clatsopcounty.gov,echo.co.clatsop.or.us,giscache.clatsopcounty.gov,giscache.co.clatsop.or.us"

Because "echo" is listed first, the live certificate will be listed under that name and
all the other names will be included. List all certifcates and see for yourself what you have.

```bash
docker run --rm -v ./certs:/etc/letsencrypt cc/certbot certificates
Saving debug log to /var/log/letsencrypt/letsencrypt.log

- - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -
Found the following certs:
  Certificate Name: echo.clatsopcounty.gov
    Serial Number: 3a8cc8c03449e1b27bc713c01175a017a91
    Key Type: ECDSA
    Domains: echo.clatsopcounty.gov echo.co.clatsop.or.us giscache.clatsopcounty.gov giscache.co.clatsop.or.us
    Expiry Date: 2023-06-27 14:24:03+00:00 (VALID: 89 days)
    Certificate Path: /etc/letsencrypt/live/echo.clatsopcounty.gov/fullchain.pem
    Private Key Path: /etc/letsencrypt/live/echo.clatsopcounty.gov/privkey.pem
- - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -
```

I just accidentally deleted certs/hitch-bundle.pem, oops. I recreated it, like this

```bash
docker run --rm -v ./certs:/etc/letsencrypt debian
cd /etc/letsencrypt/live/wildsong.biz
cat privkey.com fullchain.pem ../../dhparams.pem > ../../hitch-bundle.pem
```

TODO - If I was really diligent I'd script something to create the
hitch.conf file from that output.

Currently there are still some old certificate directories hanging
around on my servers but you can see which ones are in use by using
the "certbot certificates" command. You can delete the others, then
they will stop showing up in the output of the "certonly" command used
to renew everything.

If you have a reason to pull many certificates, remove the '--expand'
option in cerbot.yaml.

*At this point you should be ready to attempt to request some certificates.* (Or maybe just one, combined.)

***When you are done testing, remember to comment out the "--dry-run"
   option in the compose file, so that it will really fetch
   certificates (or renew them.)***

The folder "acme-challenge" is used by certbot to store "challenge"
files.  The web server 'certbot_-_challenge' will serve them at
http://YOURSERVERNAME/.well-known/acme-challenge/. (Put your own
server name in there.  You should be able to see the index.html file
there and one called test.html.

Varnish will proxy this page at your FQDN. (Whatever you set up in .env)

Cloudflare does not need the challenge server, which means it can run
fully isolated behind a firewall, but I can't always choose which DNS
service is used.  Using webroot means I have to expose a web server
for certbot to work. Normally the challenge web server does nothing
but handle challenges.  Having one devoted to that decouples
certificate management from serving web pages.

### What if I have existing certificates?

You can try to copy them but it's not worth it. Get everything set up and switch over. Just test Certbot with --dry-run until you are comfortable that it's pulling certificates correctly.

But if you want to try, you can do this.
Mount the existing folder in a container and the new Docker volume, then do a simple copy.

   docker run --rm -v /etc/letsencrypt:/le:ro -v letsencrypt_certs:/certs:rw \
      debian cp -rp /le/ /certs

### Checking on the status of certificates

You should be able to check the status of your certificates any time, note
that you have to allow read/write access for this to work

   docker run --rm -v ./certs:/etc/letsencrypt cc/certbot certificates
   docker run --rm -v ./certs:/etc/letsencrypt cc/certbot show_account

#### Run it periodically

Let's Encrypt certificates are good for 90 days, so run the certbot from crontab, 
but don't do it more than once a day or you will get banned. I doubt restarting
hitch is required, it's supposed to see changes but I do it anyway.

   crontab -e
   # Renew certificates every morning
   23 4  * * *  cd $HOME/docker/varnish && ./run_certbot.sh

## Deployment

   docker stack deploy --with-registry-auth -c compose.yaml varnish

Make sure both of the services are starting! But give it some time! (A minute is plenty)
Hitch will complain about not being able to find Varnish, and restart a few times before Varnish comes online.
You can watch the "REPLICAS" column here and eventually it should show "1/1".

   docker service ls

### Streaming the Varnish logfile

You can watch all the extensive and detailed log messages by doing
this. This is more useful on the development machine, since you will
have to sort out what traffic you are interested in on the production
machine.

   docker ps | grep varnish_varnish #find the id
   de <ID> varnishlog

## TESTS

There's a program included with Varnish called varnishtest and you should look at it!
See a demonstration of how it can be used here.
https://info.varnish-software.com/blog/rewriting-urls-with-varnish

### Certbot challenge web server test cases

As mentioned above, if you want to test the certbot, uncomment "--dry-run" and then
run it with "docker compose run -d certbot".

The challenge web server is just a tiny Python script.
These URLs are supported via varnish letsencrypt.vcl.
I read about it here
https://docs.varnish-software.com/tutorials/hitch-letsencrypt/

   curl http://localhost:8000/.well-known/acme-challenge/
   curl http://localhost:8000/.well-known/acme-challenge/test.html
   curl http://foxtrot.clatsopcounty.gov/.well-known/acme-challenge/
   curl http://foxtrot.clatsopcounty.gov/.well-known/acme-challenge/test.html
   curl https://foxtrot.clatsopcounty.gov/.well-known/acme-challenge/
   curl https://foxtrot.clatsopcounty.gov/.well-known/acme-challenge/test.html

### Test supported URLs

The unittest.py script is now in the "www" project.

### Debugging

#### Won't start?

Try running in docker compose, in foreground, it's chatty,

   docker compose up

#### Check varnishlog

1. In terminal #1, watch the very detailed log,
2. In terminal #2, send a request with curl and stand back.

   docker exec -it varnish varnishlog
   curl -v https://foxtrot.clatsopcounty.gov/

## Notes on WMS metadata etc...

When I do a get on a base URL with Esri I get a nice information page.
When I do that on Maproxy, I get a 404 error. How can I fix this?

First off, here is the URL I used as an example of an ESRI server.

Doing a get of this vector tile service returns a JSON file.
https://basemaps.arcgis.com/arcgis/rest/services/OpenStreetMap_v2/VectorTileServer

ESRI points right at the source for the Map version, centered on the US
https://www.openstreetmap.org/#map=5/38.007/-95.844

Here is a WNS service, which returns the classic ugly XML output
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

### Cloudflare

Cloudflare API tokens, find them in your Cloudflare **profile** and look in the left bar for "API Tokens". 

https://dash.cloudflare.com/profile/api-tokens

Cloudflare plugin needs a token Zone - Zone - Read and Zone - DNS - Edit and I set one for map46.com only.

### Certbot

Certbot set up on Debian
https://certbot.eff.org/instructions?ws=nginx&os=debiantesting

## TO DO LIST

* Add a healthcheck for Hitch
* Make a better healthcheck for Varnish
