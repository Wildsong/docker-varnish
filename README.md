# docker-varnish

THIS IS COPIED FROM MY CADDY PROJECT AND I JUST STARTED REWRITING IT.

I use as a reverse proxy for Mapproxy.

## Use Docker to run a simple HTTP server.

## Prerequisites

Copy sample.env to .env and edit.

Create the internal network, I happen to name it "proxy" for historic reasons.

```bash
docker network create proxy
```

Create the volume for certificates and a link.
The link makes it easier to work with the certificates from other containers like svelte-template-app.
I tried using a normal Docker volume but hit permissions problems so now I just do "mkdir certs".

```bash
docker compose up -d
docker run -ti --rm \
  -v ./certs:/db
     alpine sh -c 'ln -s /db/caddy/certificates/acme-v02.api.letsencrypt.org-directory/ certificates'
```

For this to work, the firewall must route traffic for port 80 and 443 to this machine.

```bash
docker compose up -d
```

## Permissions

I decided to borrow the certificates generated here to test a Svelte
app (svelte-template-app) that needed authentication, so I wanted it
to use SSL. That means it needed to be able to read the certificates
that Caddy generates.

I changed this project to drop root permissions when it runs Caddy.
This is why you need to specify a USER_ID in the .env file.
Dropping root also means you need group read on the Docker socket,
so there is also GROUP_ID in the .env.
If you change these then you need to do another 'docker-compose build'.

To drop root, I had to change permissions on the caddy_data and config
folders. I created a user "caddy" and put it in the "docker" group so
that it could read the unix docker socket. Then I gave the volume
group write and set its group to "docker".  I moved the config folder
from /config, and it does not need to be in a separate volume, so it's
in /home/caddy/ now (in the container).

## Almost there

At this point you should probably do a build and see if everything works.

```bash
docker compose build
```

## Testing

There are two test servers COMMENTED OUT in the docker-compose.yml file, you
must provide "test.YOURDOMAIN" and "home.YOURDOMAIN" entries in your
DNS for the tests to work. You can remove the "#" in front of the lines
in docker-compose.yml and then restart it.

## Run

The usual

   docker compose up -d

### How to reload just the proxy

This is the clumsy way.

```bash
   docker exec caddy_caddy_1 caddy reload --config /etc/caddy/Caddyfile --adapter caddyfile
```

This is more elegant. Not sure if it works. TODO :-)

```bash
   docker exec caddy_caddy_1 curl http://localhost:2019/reload/
```

## TESTS

Solve these problems to determine if it is suitable.

* Support more than one FQDN (virtual hosts)
* Support static content on different paths
* Reverse proxy many services, on different virtual hosts
* Can it run in SWARM mode? This would allow me to run the proxy on one machine and have services on others.
For example, I could put webforms.co.clatsop.or.us on cc-giscache and put the actual Flask docker on cc-testmaps.
This is not essential but would be great to separate development from production.

I am going to use these services as my test.

* A service running in its own container falco.wildsong.biz
* A folder of static content underneath the same server at /static/
* Another docker service on a different path. home-assistant.wildsong.biz
* A service running on a different machine mapproxy.wildsong.biz

### Comprehensive list of supported URLs

For CC, test these URLs, they are the ones we need to have functional.

This is a flask microservice that uses SQL to find the location of photos, then serves them.
curl https://giscache.co.clatsop.or.us/photos/property/59210
curl https://giscache.co.clatsop.or.us/photos/tn/property/59210

#### This is mapproxy

curl https://giscache.co.clatsop.or.us/
curl https://giscache.co.clatsop.or.us/osip/demo/?srs=EPSG%3A3857&format=image%2Fjpeg&wms_layer=osip2018

#### nginx static content

Content served directly from a separate nginx server (in a docker, see docker-nginx in Wildsong git).

```bash
curl https://giscache.co.clatsop.or.us/precincts/Precinct_119.pdf
curl https://giscache.co.clatsop.or.us/precinct_tn/Precinct_119.png

The all require redirects, hence the -L
curl -L https://giscache.co.clatsop.or.us/photos/static
curl -L https://giscache.co.clatsop.or.us/photos/waterway/5114
curl -L https://giscache.co.clatsop.or.us/photos/tn/waterway/5114
curl -L https://giscache.co.clatsop.or.us/photos/bridges/604A
curl -L https://giscache.co.clatsop.or.us/photos/bridges/604A.jpg
curl -L https://giscache.co.clatsop.or.us/photos/tn/bridges/604A


This just redirects to a different server (Matomo)
https://echo.co.clatsop.or.us/
```

## Adding a new service

The service has to have labels defined in its docker-compose.yml file
to tell Caddy about it. Here is my Home Assistant for example,

```bash
   labels:
      caddy: homeassistant.${DOMAIN}
      caddy.reverse_proxy: "{{upstreams 8123}}"
      caddy.tls.protocols: "tls1.3"
      caddy.tls.dns: "cloudflare ${API_TOKEN}"
```

## Resources

See my Mediawiki project, which uses this proxy and runs a MediaWiki based wiki.
https://github.com/Wildsong/docker-caddy-mediawiki

https://blog.atkinson.cloud/posts/2021/02/running-caddy-as-a-reverse-proxy-with-cloudflare-dns/

Cloudflare API tokens, find them in your Cloudflare **profile** and look in the left bar for "API Tokens". 

https://dash.cloudflare.com/profile/api-tokens

Caddy cloudflare plugin needs a token Zone - Zone - Read and Zone - DNS - Edit and I set one for map46.com only.

## Other useful commands

Test a CaddyFile.

docker run --rm -v $PWD/Caddyfile:/etc/caddy/Caddyfile caddy:2.4.6 caddy fmt /etc/caddy/Caddyfile

List the current configuration

   CAD=`docker ps | grep caddy-reverse | cut -c 1-12`
   docker exec $CAD curl -s http://localhost:2019/config/ | jq

## Future work

Deal with config issues some more elegant way?

### Swarm

Make it all work under swarm. Currently what's holding me back is Home Assistant, 
which has to be able to access a USB device to talk Zigbee.
Until I work that out, I will be stuck in Compose.

