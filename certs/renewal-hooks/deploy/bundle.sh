#!/bin/sh
# NOTE there is no bash installed here!!

# The certs volume is accessible on both certbot and hitch.
# It's mounted at /certs on hitch
# and at /etc/letsencrypt on certbot

# From what I've read, hitch will notice if the certificates
# change so I don't need to do anything special there.


# RENEWED_LINEAGE will be something like “/etc/letsencrypt/live/example.com/”
# RENEWED_DOMAINS will be a list “example.com www.example.com”

if [[ -d "${RENEWED_LINEAGE}" ]]; then
    cd ${RENEWED_LINEAGE}
fi

# pre-generated Diffie Hellman Parameters file
DHPARAMS=../../dhparams.pem

umask 022
# Glue the certificates all together in one file for hitch.
cat privkey.pem fullchain.pem ${DHPARAMS} > /etc/letsencrypt/hitch-bundle.pem
echo hitch-bundle.pem created
