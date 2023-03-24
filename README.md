# docker-varnish

Varnish is used here mostly as a reverse proxy for Mapproxy.
Hitch does the TLS part, as a proxy between Varnish and the world.
Varnish and Hitch communicate using the "PROXY" protocol.

As a separate process certbot manages certificates from the host.
There is a tiny web server that answers challenge requests.

There is support for Cloudflare DNS as an option.

## Prerequisites

Your firewall must route traffic for port 80 and 443 to the machine running Varnish.
After that, it can proxy services that are behind the firewall. 

### Network

Create the internal network, I happened to name it "varnish".
This network is how Varnish and the backend services talk to each other
when they are on the same machine. (Varnish can proxy any server anywhere.)

```bash
docker network create varnish
```

(It is up to you to tell all your backend services to use this network.)

### Set up "Let's Encrypt"

Hitch needs certificates. (That's why it exists after all, to do TLS.)

You need to have a dhparams.pem file. It will be baked into the cc/certbot images;
the deploy hook script will copy dhparams.pem into the certificate bundle.
You should only have to create the dhparams.pem file one time, then add to your certs volume so that containers get get to it.

```bash
openssl dhparam 2048 > dhparams.pem
docker buildx build -f Dockerfile.hitch -t cc/hitch .
```

Maintaining certificates (including creating and renewing them) is done
as a separate process. If you don't use Cloudflare for DNS,
you have to start certbot_challenge,
then build and test with these commands.

I have three default.vcl files, when setting up new domains I leave it set to the
default (default.vcl) then when I am moving into deployment, I set DEFAULT_VCL_FILE
in the .env file based on what I am doing (testing, production, or at home testing)
Follow the [correct VCL syntax](http://varnish-cache.org/docs/7.2/users-guide/vcl-syntax.html) There are many many things you can do with Varnish, I have barely started learning it.

The default.vcl file just has the mininum needed to bootstrap getting certificates for hitch.

To use Cloudflare DNS challenges, you have to set up a cloudflare.ini file. See the sample.

```bash
# Create the volume, do this one time
docker volume create letsencrypt_certs

# Varnish and the challenge server both have to be running
# even if you don't have an certs yet.
docker compose up -d

# Install the DH PEM and "bundle" script files
docker cp dhparams.pem hitch:/certs/
docker exec hitch mkdir -p /certs/renewal-hooks/deploy/ 
docker cp bundle.sh hitch:/certs/renewal-hooks/deploy

# Check your work, you should see the files you added
docker run --rm -v letsencrypt_certs:/certs debian ls -Rl /certs
less 
# IF you use webroot auth
docker buildx build -f Dockerfile.certbot -t cc/certbot .
docker buildx build -f Dockerfile.challenge -t cc/challenge .
docker compose run --rm certbot
docker run --rm cc/certbot --version

# ELSE you use cloudflare plugin
docker buildx build -f Dockerfile.cloudflare -t cc/cloudflare .
docker compose run --rm cloudflare
docker run --rm cc/cloudflare --version
```

You have to build the certbot and hitch images but currently
varnish uses standard images so no build step required.

*At this point you should be ready to attempt to request some certificates.*

***When you are done testing, remember to comment out the "--dry-run" option in the compose file, so that it will really fetch certificates (or renew them.)***

The folder "acme-challenge" is used by certbot to store "challenge" files.
The web server 'certbot_-_challenge' will serve them at
http://YOURSERVERNAME/.well-known/acme-challenge/. (Put your own server name in there.
You should be able to see the index.html file there and one called test.html.

Varnish will proxy this page at your FQDN. (Whatever you set up in .env)

Cloudflare does not need the challenge server, which means it can run fully
isolated behind a firewall, but I can't always choose which DNS service is used.
Using webroot means I have to expose a web server for certbot to work. Normally
the challenge web server does nothing but handle challenges. 
Having one devoted to that decouples certificate management from serving web pages.

#### Existing certificates?? You can try to copy them.

It's not worth it. Get everything set up and switch over. Just test Certbot
with --dry-run until you are comfortable that it's pulling certificates correctly.

But if you want to try, you can do this. 
Mount the existing folder in a container and the new Docker volume, then do a simple copy.

```bash
docker run --rm -v /etc/letsencrypt:/le:ro -v letsencrypt_certs:/certs:rw \
    debian cp -rp /le/ /certs
```

### Checking on the status of certificates

You should be able to check the status of your certificates any time, note
that you have to allow read/write access for this to work

```bash
docker run --rm -v letsencrypt_certs:/etc/letsencrypt cc/certbot certificates
docker run --rm -v letsencrypt_certs:/etc/letsencrypt cc/certbot show_account
```

I trouble getting the Certbot container to run bundle.sh when it created
a new set of certificate files and had to run it manually, you can do that with

```bash
docker run --rm -v letsencrypt_certs:/etc/letsencrypt --entrypoint sh cc/certbot
cd /etc/letsencrypt/live/NEWDOMAINNAME
/etc/letsencrypt/renewal-hooks/deploy/bundle.sh

This process creates a hitch-bundle.pem file, which is used by Hitch.
It should run automatically now though.

#### Run it periodically

Let's Encrypt certificates are good for 90 days, so run the certbot from crontab, 
but don't do it more than once a day or you will get banned. I doubt restarting
hitch is required, it's supposed to see changes but I do it anyway.

```bash
crontab -e
# Renew certificates every morning and then restart hitch so it gets new certs, if any
23 4  * * *  cd $HOME/docker/varnish && docker compose run --rm certbot 
34 5  * * *  cd $HOME/docker/varnish && docker compose restart hitch 



## Deployment

In case you have not done it already, start it, and watch the logs to see
if it is working.

```bash
docker compose up -d
docker compose logs --follow
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

My unittest.py script is now in the "www" project.

### Debugging

1. In terminal #1, watch the very detailed log,
2. In terminal #2, send a request with curl and stand back.

```bash
docker exec -it varnish varnishlog
curl -v https://foxtrot.clatsopcounty.gov/
```

## Resources

### Cloudflare

Cloudflare API tokens, find them in your Cloudflare **profile** and look in the left bar for "API Tokens". 

https://dash.cloudflare.com/profile/api-tokens

Cloudflare plugin needs a token Zone - Zone - Read and Zone - DNS - Edit and I set one for map46.com only.

### Certbot

Certbot set up on Debian
https://certbot.eff.org/instructions?ws=nginx&os=debiantesting
