#!/bin/bash


# The certs volume is accessible on both certbot and hitch.
# It's mounted at /certs on hitch
# and at /etc/letsencrypt on certbot

# I still need a way to send a message to hitch to tell it to reload.

# Full path to pre-generated Diffie Hellman Parameters file
DHPARAMS=/usr/local/lib/dhparams.pem

# RENEWED_LINEAGE will be something like “/etc/letsencrypt/live/example.com/”
# RENEWED_DOMAINS will be a list “example.com www.example.com”

if [[ "${RENEWED_LINEAGE}" == "" ]]; then
    echo "RENEWED_LINEAGE not set." >&2
    exit 1
fi

umask 077

# GLue the certificates all together in one file for hitch.

cd ${RENEWED_LINEAGE}
cat privkey.pem fullchain.pem ${DHPARAMS} > hitch-bundle.pem
