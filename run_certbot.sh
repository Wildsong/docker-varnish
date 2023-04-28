# This gets run from crontab to keep certificates up to date.

source .env
docker run --rm -v $PWD/certs:/etc/letsencrypt:rw \
    cc/certbot certonly --domains="${DOMAINS}" -m ${EMAIL} \
    --quiet --noninteractive \
    --agree-tos --expand \
    --deploy-hook=/etc/letsencrypt/renewal-hooks/deploy/bundle.sh \
    --disable-hook-validation \
    --max-log-backups=0 \
    --allow-subset-of-names \
    --dns-dnsmadeeasy --dns-dnsmadeeasy-credentials /usr/local/lib/dnsmadeeasy.ini

# Update hitch
docker stack deploy --with-registry-auth -c compose.yaml varnish 
