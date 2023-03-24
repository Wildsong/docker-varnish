vcl 4.1;

# Set up your own default.DOMAINNAME.vcl
# and set DEFAULT_VCL_FILE in your .env file.
# Anytime you edit, reload with de varnish varnishreload


# This is the minimal service required to support certbot for bootstrapping your site.
# It responds to challenge requests. Anything that's not
# a challenge request will give an error.

backend default {
    .host = "[challenger]";
    .port = "8000";
}
