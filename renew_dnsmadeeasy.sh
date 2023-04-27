# Attempt to renew certificates
docker compose -f docker-compose-certbot.yml run --rm dnsmadeeasy

# The certificate file will be modified if this happened.
CERTIFICATE_BUNDLE=./certs/hitch-bundle.pem
#CERTIFICATE_BUNDLE=./sample.env # For testing

if [ -f "$CERTIFICATE_BUNDLE" ]; then 

    # If the file is less than a day old, tell hitch.
    age=$(stat -c %Y $CERTIFICATE_BUNDLE)
    now=$(date +"%s")
    if (( (now - age) < 86400 )); then
        echo "Certifcate has been updated, reloading hitch now!"

        # This will cause a new config file to be created
        docker stack rm varnish
        docker stack deploy -c docker-compose.yml varnish

        echo "Catching a quick nap."
        sleep 60
        docker config ls
        docker service ps varnish_hitch
        docker service ps varnish_varnish
    fi

else
    echo "ERROR; NO CERTIFICATE BUNDLE FOUND. \"${CERTIFICATE_BUNDLE}\""
    exit 1
fi
