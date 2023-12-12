# You probably don't need to rebuild, this is for development only
docker compose build
# If you get a login failure, try
#docker login ghcr.io -u GITHUBNAMEHERE
docker push ghcr.io/wildsong/varnish
# https://docs.github.com/en/packages/working-with-a-github-packages-registry/working-with-the-container-registry
# You have regenerate a token every 30 days to use this.

# Edits to the VCL file are not enough!! You have to create a new config for Docker Swarm to work.

# You have to stop varnish to unlock the config
docker stack rm varnish

# You can't overwrite an existing config, you have to delete the old one first.
docker config rm varnish_config

# Now create a new config using your config file
docker config create varnish_config etc/default.giscache.vcl

# You have to restart varnish now
docker stack deploy -c swarm.yaml varnish

echo "If you got an error about a network just run this deploy command again."
echo "docker stack deploy -c swarm.yaml varnish"
