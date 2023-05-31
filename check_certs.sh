#!/bin/bash

docker run --rm -v $PWD/certs:/etc/letsencrypt:rw cc/certbot certificates
