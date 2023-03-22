vcl 4.1;
import std;

##-###############################################################
## These are all part of the docker-compose for Varnish
## so you can use their Docker names.

# Let's Encrypt challenge server
backend certbot_challenge {
    .host = "[challenger]";
    .port = "8000";
}

#sub vcl_init {
# You can do fancy load balancing things if you have the hardware.
# for more info, see https://github.com/nigoroll/libvmod-dynamic/blob/master/src/vmod_dynamic.vcc
#        new d = dynamic.director(port = "80");
#	new vdir = directors.round_robin();
#	vdir.add_backend(giscache);
#}

sub vcl_recv {

	# Everything here currently is supported via a host header, 
	# the path is just passed through to the service provider.

	if (!req.http.Host) {
		# Everything else falls through to the base www handler
		# which also happens to handle the certbot challenges.
		# On this domain I happen to use Cloudflare so I will probably
		# set that up but here it is just in case I want to test with webroot.
		set req.backend_hint = certbot_challenge;

		# I could also handle rewriting URLs here, but, I don't
		# because it's so easy to make domain names on Cloudflare.
	}
	
	# remove port number
	set req.http.Host = regsub(req.http.Host, ":[0-9]+$", "");
	
	# Logging - since this is catching unexpected things
	# I could easily set up a fail2ban rule here, huh?
	if (std.port(server.ip) == 443) {
		std.log("Client connected over TLS/SSL: " + server.ip);
		std.syslog(6,"Client connected over TLS/SSL: " + server.ip);
		std.timestamp("After std.syslog");
	}

	error 404
}

include "site-homeassistant.vcl";
include "site-psono.vcl";
#include "site-bellman.vcl";
