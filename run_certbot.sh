#!/bin/bash
# This gets run from crontab to keep certificates up to date.

source .env
docker run --rm -v $PWD/certs:/etc/letsencrypt:rw cc/certbot certonly \
       --cert-name ${CERTNAME} \
       --expand \
       ${DOMAINS} \
       -m ${EMAIL} \
       -q -n \
       --agree-tos \
       --deploy-hook=/etc/letsencrypt/renewal-hooks/deploy/bundle.sh \
       --disable-hook-validation \
       --max-log-backups=0 \
       --allow-subset-of-names \
       --dns-dnsmadeeasy --dns-dnsmadeeasy-credentials /usr/local/lib/dnsmadeeasy.ini

# Update hitch
# I should only do this if the hitch bundle changed.
hitch="certs/hitch-bundle.pem"
age=$(stat -c %Y $hitch)
now=$(date +"%s")
if (( ($now - $age) < (60 * 60) )); then
    echo $hitch changed
    docker stack deploy --with-registry-auth -c compose.yaml varnish 
fi
