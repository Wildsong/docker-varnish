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

Hitch needs certificates. (That's why it exists after all, to do TLS.)

You should only have to create the dhparams.pem file one time.
It will be baked into the cc/certbot images; the deploy hook
script will copy dhparams.pem into the certificate bundle.

```bash
openssl dhparam 2048 > dhparams.pem
docker buildx build -f Dockerfile.hitch -t cc/hitch .
```

You can run a separate task to maintain certificates. You have to start certbot_challenge, 
then build and test with these commands.


```bash
docker compose up certbot_challenge -d
docker buildx build -f Dockerfile.certbot -t cc/certbot .
docker compose run --rm certbot
```

***When you are done testing, remember to comment out the "--dry-run" option in the compose file, so that it will really pull certificates (or renew them.)***

The folder "acme-challenge" is used by certbot to store "challenge" files.
The web server 'certbot_-_challenge' will serve them at
http://localhost/.well-known/acme-challenge/. (Put your own server name in there.
You should be able to see the index.html file there and one called test.html.

Varnish will proxy this page at whatever your FQDN is.
(Hmm, I still have to make it work for more than one FQDN.)

I can't always choose which DNS service is used, that means I have to expose a web server for certbot to work. Running a challenge web server that does nothing but handle
challenges decouples certificate management from serving web pages.

#### Existing certificates?? Copy them.

When I migrated to the containerized certbot I already had some certificates in the host, so
I did this. Mount the existing folder in a container and the new Docker volume,
then do a simple copy.

```bash
docker run --rm -v /etc/letsencrypt:/le:ro -v letsencrypt_certs:/certs:rw \
    debian cp -rp /le/ /certs
```

#### Run it periodically

Let's Encrypt certificates are good for 90 days, so run the certbot from crontab, 
but don't do it more than once a day or you will get banned. I could check to see
if the certificates changed, but it's easiest just to restart hitch every day, too.

```bash
crontab -e
# Renew certificates every morning and then restart hitch so it gets new certs, if any
23 4  * * *  cd $HOME/docker/varnish && docker compose run --rm certbot 
34 5  * * *  cd $HOME/docker/varnish && docker compose restart hitch 

### Volumes for static web content

The task "www" is a generic web server for serving static content.

I have mixed feelings about putting the photo content right here too,
but also I wanted a generic web server that could handle site landing page(s).

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

Photos are served out of the "www" server. I used nginx because it has a nice
thumbnail add-on. I used to have a completely separate nginx project
but now it's built-in here. Partly to avoid a startup problem with its name.
(If it's not running when Varnish starts then the startup of Varnish fails.)

Since I had already folded it into this project, I use it to serve landing pages too.

## Deployment

```bash
docker compose up -d
```

### How to reload just varnish

You can do this after editing the default.vcl file, so that you don't have to 
restart all the services.

```bash
   docker exec varnish varnishreload
```

### Streaming the Varnish logfile

You can watch all the extensive and detailed log messages by doing

```bash
    docker exec varnish varnishlog
```

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
