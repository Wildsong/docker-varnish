#!/bin/bash
# This gets run from crontab to keep certificates up to date.
# Read options here https://eff-certbot.readthedocs.io/en/stable/using.html#configuration-file

source .env
docker run --rm -v $PWD/certs:/etc/letsencrypt:rw \
    cc/certbot certonly --domains="${DOMAINS}" -m ${EMAIL} \
    --quiet --noninteractive \
    --agree-tos --expand \
    --deploy-hook=/etc/letsencrypt/renewal-hooks/deploy/bundle.sh \
    --disable-hook-validation \
    --max-log-backups=0 \
    --allow-subset-of-names \
    --dns-cloudflare --dns-cloudflare-credentials /usr/local/lib/cloudflare.ini

# Update hitch
docker stack deploy --with-registry-auth -c compose.yaml varnish 
