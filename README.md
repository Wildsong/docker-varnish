# docker-varnish

Varnish is used as a reverse proxy for Mapproxy. 
Hitch does the TLS part, it's a proxy between Varnish and the world.
Varnish and Hitch communicate using the "PROXY" protocol.
Certbot manages certificates from the host but there is a tiny web server
here to answer challenge requests.

## Prerequisites

For this to work, the firewall must route traffic for port 80 and 443 to the machine running Varnish.

### Network

Create the internal network, I happened to name it "proxy". This network is how Varnish and the backends talk to each other.
(Varnish can proxy any server anywhere but I did it this way.)

```bash
docker network create proxy
```

### Set up "Let's Encrypt"

Hitch needs certificates, and it's easiest to just install certbot on the host and run it once a month to keep them up to date. Mount the host certificate folder in hitch.

I use snap to install certbot, see Resources section. To install, I did this.

```bash
sudo snap install --classic certbot
sudo ln -s /snap/bin/certbot /usr/bin/certbot
```

The folder "acme-challenge" will be used by certbot to store "challenge" files.
The included web server will serve them at http://localhost/.well-known/acme-challenge/. (Put your own server name in there.) You should be able to see the index.html file there.

Varnish will proxy this page at whatever your FQDN is.
(Hmm, I still have to make it work for more than one FQDN.)

Testing, use your names not mine!

```
sudo certbot certonly --dry-run --webroot -w acme-challenge -d foxtrot.clatsopcounty.gov -m 
```

I can't choose which DNS service is used, that means I have to expose a web server for certbot to work. I did it using a python based server via the certbot-web service in the docker-compose.yml file. I want my projects as decoupled as possible so I don't really want to rely on some other docker set up to provide the web service.

I use a script called rewew_certs.sh to run certbot. Laucnh it from /etc/crontab
once a month. Sample crontab line:

```bash
0  0 1  * *     root    HOSTNAMES="my comma delimited list of domains" EMAIL=My_Email_Address /home/gis/docker/varnish/renew_certs.sh
```

*** I Broke The Rules And This Is Bad ***

I copied the PEM files from letsencrypt into ./certs.

** FIX ME **

Make a dockerized certbot that writes certs into a volume. 
Run the certbot once a week from crontab, maybe. Don't run it as a daemon.

### Set up Photos

If you keep media on CIFS filesystems you will need credentials.
I keep mine in /home/gis/.smbcredentials

1. Edit create_photo_volumes.sh as needed
2. Run it: ./create_photo_volumes.sh


## Set up Varnish

You have to build the certbot web server and hitch but currently
varnish uses standard images so no build there.

All this web server does is work with certbot to confirm you are really who you
say you are. It has a folder .well-known/acme-challenge that it serves.

```bash
docker buildx build -f Dockerfile.hitch -t cc/hitch .
docker buildx build -f Dockerfile.certbot-web -t cc/certbot-web .
```

### Proxy something

Customize default.vcl for your site.  Start by copying default.vcl.sample, then edit it.
Follow the [correct VCL syntax](http://varnish-cache.org/docs/7.2/users-guide/vcl-syntax.html)

First set up a backend, this will be the "origin" server, the place the content comes from.
Then add some code to the vcl_recv subroutine. This will direct traffic to a backend
based on rules you define. 

## Photos

Photos are served out of an nginx server because it has a nice
thumbnail add-on. I used to have a completely separate nginx project
but now it's built-in here. Partly to avoid a startup problem with its name.
(If it's not running when Varnish starts then the startup of Varnish fails.)

## Run

```bash
docker compose up -d
```

### How to reload just varnish

You can do this after editing the default.vcl file, so that you don't have to 
restart all the services.

```bash
   docker exec varnish varnishreload
```

### Streaming the logfile

You can watch all the extensive and detailed log messages by doing

```bash
    docker exec varnish varnishlog
```

## TESTS

There's a program included with Varnish called varnishtest and you should look at it!
See a demonstration of how it can be used here.
https://info.varnish-software.com/blog/rewriting-urls-with-varnish

### Certbot challenge web server test cases

Direct access
The first three should complete; the last one should throw a 404.

   curl http://localhost:8000/
   curl http://localhost:8000/.well-known/acme-challenge/
   curl http://localhost:8000/.well-known/acme-challenge/test.html
   curl -v http://localhost:8000/404Error

Through the proxy
   curl https://foxtrot.clatsopcounty.gov/
   curl https://foxtrot.clatsopcounty.gov/.well-known/acme-challenge/
   curl https://foxtrot.clatsopcounty.gov/.well-known/acme-challenge/test.html
   curl -v https://foxtrot.clatsopcounty.gov/404Error

### Test supported URLs

Use unittest.py to do all the testing.
Add more test cases if you add more stuff.

## Debugging

1. In terminal #1, watch the very detailed log,
2. In terminal #2, send a request and stand back.

```bash
docker exec -it varnish varnishlog
curl -v https://foxtrot.clatsopcounty.gov/
```

## Resources

See my Mediawiki project, which uses this proxy and runs a MediaWiki based wiki.
https://github.com/Wildsong/docker-caddy-mediawiki


Cloudflare API tokens, find them in your Cloudflare **profile** and look in the left bar for "API Tokens". 

https://dash.cloudflare.com/profile/api-tokens

Cloudflare plugin needs a token Zone - Zone - Read and Zone - DNS - Edit and I set one for map46.com only.

Certbot set up on Debian
https://certbot.eff.org/instructions?ws=nginx&os=debiantesting
