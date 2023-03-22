vcl 4.1;
import std;

# remember to reload if you make changes
# de varnish varnishreload

# import vmod_dynamic for better backend name resolution
#import dynamic;

##-###############################################################
## These are all part of the docker-compose for Varnish
## so you can use their Docker names.

# Let's Encrypt challenge server
backend certbot_challenge {
    .host = "[challenger]";
    .port = "8000";
}

##-###############################################################
## These are running in separate containers
## You can run them on separate machines
## and reference them with [cc-HOSTNAME] and it should resolve.
## I tried using [localhost] but that's not working.

# The main landing page and photo services (nginx)
backend www {
	.host = "[www]";
	.port = "81";
}

# separate mapproxy services
backend bulletin {
.host = "[cc-testmaps]";
	.port = "8884";
}
backend city_aerials {
	.host = "[cc-testmaps]";
	.port = "8885";
}
backend county_aerials {
	.host = "[cc-testmaps]";
	.port = "8886";
}
backend county_aerials_brief {
	.host = "[cc-testmaps]";
	.port = "8887";
}
backend lidar {
	.host = "[cc-testmaps]";
	.port = "8888";
}

##-###############################################################
## These are currently just here for testing, not deployed yet

backend arctic_monitor {
	.host = "[cc-testmaps]";
	.port = "5000";
}
backend arctic_geodatabase {
	.host = "[cc-testmaps]";
	.port = "5001";
}

# Web App Builder and Experience Builder
backend wabde {
	.host = "[cc-testmaps]";
	.port = "3344";
}
backend exb {
	.host = "[cc-testmaps]";
	.port = "3000";
}

#sub vcl_init {
# You can do fancy load balancing things if you have the hardware.
# for more info, see https://github.com/nigoroll/libvmod-dynamic/blob/master/src/vmod_dynamic.vcc
#        new d = dynamic.director(port = "80");
#	new vdir = directors.round_robin();
#	vdir.add_backend(giscache);
#}

sub vcl_recv {

	# I want my URLS to be like
	# https://foxtrot.clatsopcounty.gov/mapproxy/SERVICE
	# but my backend server has no "mapproxy" in it.
	# https://giscache.co.clatsop.or.us/SERVICE

#	if (req.http.host == "foxtrot.clatsopcounty.gov") {

# For MapProxy, each service has to add the service name part of the path back in
# Varnish strips the service name out and adds in the port number the service runs on
# in the backends. Using X-Script-Name in the request to MapProxy tells it to add
# the service name back in as it sends the response back to the client.
#
# If you get it wrong, the client will start asking for tiles
# with (for example) "/wms" instead of "/city-aerials/wms"
# and that will show up in the varnish logs as 404 BAD REQUEST
# because Varnish will use the default, backend_www

		if (req.url ~ "^/bulletin78_79/") {
			set req.url = regsub(req.url, "^/bulletin78_79/", "/");
			set req.backend_hint = bulletin;
			set req.http.X-Script-Name = "^/bulletin78_79";
		} elseif (req.url ~ "^/bulletin78_79$") {
			set req.url = regsub(req.url, "^/bulletin78_79", "/");
			set req.backend_hint = bulletin;
			set req.http.X-Script-Name = "/bulletin78_79";


		} elseif (req.url ~ "^/city-aerials/") {
			set req.url = regsub(req.url, "^/city-aerials/", "/");
			set req.backend_hint = city_aerials;
			set req.http.X-Script-Name = "/city-aerials";
		} elseif (req.url ~ "^/city-aerials$") {
			set req.url = regsub(req.url, "^/city-aerials", "/");
			set req.backend_hint = city_aerials;
			set req.http.X-Script-Name = "/city-aerials";
	

		} elseif (req.url ~ "^/county-aerials/") {
			set req.url = regsub(req.url, "^/county-aerials/", "/");
			set req.backend_hint = county_aerials;
			set req.http.X-Script-Name = "/county-aerials";
		} elseif (req.url ~ "^/county-aerials$") {
			set req.url = regsub(req.url, "^/county-aerials", "/");
			set req.backend_hint = county_aerials;
			set req.http.X-Script-Name = "/county-aerials";


		} elseif (req.url ~ "^/county-aerials-brief/") {
			set req.url = regsub(req.url, "^/county-aerials-brief/", "/");
			set req.backend_hint = county_aerials_brief;
			set req.http.X-Script-Name = "/county-aerials-brief";
		} elseif (req.url ~ "^/county-aerials-brief$") {
			set req.url = regsub(req.url, "^/county-aerials-brief", "/");
			set req.backend_hint = county_aerials_brief;
			set req.http.X-Script-Name = "/county-aerials-brief";


		} elseif (req.url ~ "^/lidar-2020/") {
			set req.url = regsub(req.url, "/lidar-2020/", "/");
			set req.backend_hint = lidar;
			set req.http.X-Script-Name = "/lidar-2020";
		} elseif (req.url ~ "^/lidar-2020$") {
			set req.url = regsub(req.url, "/lidar-2020", "/");
			set req.backend_hint = lidar;
			set req.http.X-Script-Name = "/lidar-2020";

    	} elseif (req.url ~ "^/\.well-known/acme-challenge/") {
        	set req.backend_hint = certbot_challenge;

		} elseif (req.url ~ "^/webappbuilder") {
			set req.backend_hint = wabde;

		} elseif (req.url ~ "^/builder") {
			set req.backend_hint = exb;
		} elseif (req.url ~ "^/page") {
			set req.backend_hint = exb;

		} elseif (req.url ~ "/arctic") {
			set req.url = regsub(req.url, "/arctic", "/");
			set req.backend_hint = arctic_monitor;
		} elseif (req.url ~ "/geodatabase") {
			set req.url = regsub(req.url, "/geodatabase", "/");
			set req.backend_hint = arctic_geodatabase;

		} else {
			# This handles the main landing page and the photos.
			set req.backend_hint = www;
		}

	# Logging
	if (std.port(server.ip) == 443) {
		std.log("Client connected over TLS/SSL: " + server.ip);
		std.syslog(6,"Client connected over TLS/SSL: " + server.ip);
		std.timestamp("After std.syslog");
	}

	# force the host header to match the backend (not all backends need it,
	# but example.com does)
#	set req.http.host = "foxtrot.clatsopcounty.gov";
	# set the backend
#	set req.backend_hint = d.backend("foxtrot.clatsopcounty.gov");

	return (pipe); # Do no caching
}


