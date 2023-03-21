vcl 4.1;

# Copy whatever your current default.vcl here then
# de varnish varnishreload

backend default {
    .host = "www.varnish-cache.org";
    .port = "80";
}