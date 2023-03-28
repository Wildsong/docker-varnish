vcl 4.1;

# Remember to reload if you make changes to this file, you can just do this
# de varnish varnishreload

# import vmod_dynamic for better backend name resolution, no idea how this works yet so it's commented out.
#import dynamic;

# Let's Encrypt challenge server
# Obsolete
#backend default {
#    .host = "[challenger]";
#    .port = "8000";
#}

##-###############################################################
## These are running in separate containers
## You can even run them on separate machines if you want
## and reference them with [cc-HOSTNAME] and it should resolve.
## I tried using [localhost] but that's not working.
##
## The danger is using an internal Docker name, like "www" or "matomo",
## because if those services are not running when you start Varnish then
## Varnish will block.

# The main landing page and some photo services (nginx)
backend www {
	.host = "[cc-giscache]";
	.port = "81";
}

# The Matomo services
backend matomo {
	.host = "[echo.clatsopcounty.gov]";
	.port = "80";
}

# -------------------------------------

# separate mapproxy services
backend bulletin {
.host = "[cc-giscache]";
	.port = "8884";
}
backend city_aerials {
	.host = "[cc-giscache]";
	.port = "8885";
}
backend county_aerials {
	.host = "[cc-giscache]";
	.port = "8886";
}
backend county_aerials_brief {
	.host = "[cc-giscache]";
	.port = "8887";
}
backend lidar {
	.host = "[cc-giscache]";
	.port = "8888";
}

#sub vcl_init {
# You can do fancy load balancing things if you have the hardware.
# for more info, see https://github.com/nigoroll/libvmod-dynamic/blob/master/src/vmod_dynamic.vcc
#        new d = dynamic.director(port = "80");
#	new vdir = directors.round_robin();
#	vdir.add_backend(giscache);
#}

sub vcl_recv {

  # remove port number
  set req.http.Host = regsub(req.http.Host, ":[0-9]+$", "");

  # I want my MapProxy URLs to be like
  # https://giscache.clatsopcounty.gov/mapproxy/SERVICE
  # but my backend server has no "mapproxy" in it.
  # I can change the backend or be more sophisticated here.
  # https://giscache.co.clatsop.or.us/SERVICE

  if (req.http.host == "giscache.clatsopcounty.gov"
   || req.http.host == "giscache.co.clatsop.or.us") # deprecated
  {

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

    } elseif (req.url ~ "^/$") {
	    set req.backend_hint = www;

    } elseif (req.url ~ "^/\.well-known/acme-challenge/") {
	    set req.backend_hint = default;

    } else {
	# This handles the main landing page and the photos.
  		set req.backend_hint = www;
    }

  } elseif (req.http.host == "echo.clatsopcounty.gov"
   		 || req.http.host == "echo.co.clatsop.or.us") # deprecated
  {
    set req.backend_hint = matomo;
  }


# force the host header to match the backend (not all backends need it)
#  set req.http.host = "giscache.clatsopcounty.gov";
#  set req.backend_hint = d.backend("giscache.clatsopcounty.gov");

  return (pipe); # Do no caching
}


