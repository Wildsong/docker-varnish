FROM varnish:stable
LABEL MAINTAINER Brian Wilson <bwilson@clatsopcounty.gov>

RUN apt-get update -y && \
    apt-get install -y \
        curl \
        iputils-ping

HEALTHCHECK CMD curl --fail http://localhost/ || exit 1
