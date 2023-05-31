#!/bin/bash
# This gets run from crontab to keep certificates up to date.
# Read options here https://eff-certbot.readthedocs.io/en/stable/using.html#configuration-file

source .env

# --cert-name will add or remove names using the certificate as named
# --expand will only add names to an existing cert

# "certonly" obtains certs without installing them (except in /etc/letsencrypt of course)
# Add this in case some domains aren't working: --allow-subset-of-names

docker run --rm -v $PWD/certs:/etc/letsencrypt:rw cc/certbot \
       certonly \
       --cert-name ${CERTNAME} \
       --expand \
       ${DOMAINS} \
       -m ${EMAIL} \
       --agree-tos \
       --deploy-hook=/etc/letsencrypt/renewal-hooks/deploy/bundle.sh \
       --disable-hook-validation \
       --max-log-backups=0 \
       --dns-cloudflare --dns-cloudflare-credentials /usr/local/lib/cloudflare.ini \
       --quiet --noninteractive

# Update hitch
# This should not be needed.
#docker stack deploy --with-registry-auth -c compose.yaml varnish 
