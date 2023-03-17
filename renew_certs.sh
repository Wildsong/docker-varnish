#!/bin/bash
#
# Use Let's Encrypt to create 90 day certificates for each set of services.
#


# Uncomment when testing, to avoid being banned for too many requests
#DRY="--dry-run"

# These should be defined in the environment.
#EMAIL="email_address_for_cert_administrator"
#HOSTNAMES="list,of,fqdns"

ACTION=certonly

if [[ "$EMAIL" != "" && "$HOSTNAMES" != "" ]]; then
    # This generates one certificate that works for all hosts in HOSTNAMES (See the "expand" option.)
    certbot $ACTION $DRY --noninteractive --agree-tos --expand \
    --webroot -w /home/gis/docker/varnish/webroot --domains $HOSTNAMES -m $EMAIL
else
  echo "You need to set the EMAIL and HOSTNAMES environment variables."
fi
