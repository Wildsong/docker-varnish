# certs folder

This is bind mounted in the certbot container
when it runs from crontab.

Certbot will generate a new hitch-bundle.pem file,
and that needs to be loaded into docker config space.
