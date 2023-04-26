#!/bin/sh
# NOTE there is no bash installed here!!

# The certs volume is mounted /etc/letsencrypt on certbot
# This file needs to be copied from ./certs into a docker config
# when it changes.

TARGET_FILE="/etc/letsencrypt/hitch-bundle.pem"

# RENEWED_LINEAGE will be something like “/etc/letsencrypt/live/example.com/”
# RENEWED_DOMAINS will be a list “example.com www.example.com”

if [[ -d "${RENEWED_LINEAGE}" ]]; then
    cd ${RENEWED_LINEAGE}
fi

# pre-generated Diffie Hellman Parameters file
DHPARAMS=../../dhparams.pem

umask 022

# Glue the certificates all together in one file for hitch.
cat privkey.pem fullchain.pem ${DHPARAMS} > ${TARGET_FILE}
echo ${TARGET_FILE} created.
