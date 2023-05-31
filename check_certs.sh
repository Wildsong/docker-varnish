#!/bin/bash

source .env

docker run --rm -v $PWD/certs:/etc/letsencrypt:rw cc/certbot certificates --cert-name ${CERTNAME}

