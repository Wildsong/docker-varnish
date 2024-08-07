vcl 4.1;
import std;

###
###      -- NOTE --
###
###      in SWARM mode this is in a docker config,
###      to reload it,
###
###        docker config rm varnish_config
###        docker config create varnish_config etc/default.giscache.vcl
###

# The main landing page and some photo services (nginx)
backend default {
    .host = "cc-giscache";
    .port = "81";
}

##-###############################################################
## These are running in separate containers
## You can even run them on separate machines if you want
## and reference them with [cc-HOSTNAME] and it should resolve.
## I tried using [localhost] but that's not working.
##-###############################################################

# The Matomo services
backend matomo {
    .host = "echo.clatsopcounty.gov";
    .port = "82";
}

backend records_client {
    .host = "records.clatsopcounty.gov";
    .port = "8080";
}
backend records_api {
    .host = "records.clatsopcounty.gov";
    .port = "4000";
}

# -------------------------------------

# separate mapproxy services
backend bulletin {
    .host = "cc-giscache";
    .port = "8884";
}
backend city_aerials {
    .host = "cc-giscache";
    .port = "8885";
}
backend county_aerials {
    .host = "cc-giscache";
    .port = "8886";
}
backend county_aerials_brief {
    .host = "cc-giscache";
    .port = "8887";
}
backend lidar {
    .host = "cc-giscache";
    .port = "8888";
}
backend nhd {
    .host = "cc-giscache";
    .port = "8889";
}
backend wetlands {
    .host = "cc-giscache";
    .port = "8890";
}
backend water_system_management {
    .host = "cc-giscache";
    .port = "8891";
}
backend dsl_wetlands {
    .host = "cc-giscache";
    .port = "8892";
}

#sub vcl_init {
# You can do fancy load balancing things if you have the hardware.
# for more info, see https://github.com/nigoroll/libvmod-dynamic/blob/master/src/vmod_dynamic.vcc
#        new d = dynamic.director(port = "80");
#    new vdir = directors.round_robin();
#    vdir.add_backend(giscache);
#}

sub vcl_recv {

    if (req.http.upgrade ~ "(?i)websocket") {
        return (pipe); # Don't cache websocket traffic
    }

    # remove port number
    set req.http.Host = regsub(req.http.Host, ":[0-9]+$", "");

    if (req.url ~ "^/ping$") {
        # This responds to ANY URL ending in ping, including localhost
        # respond HTTP 200 to /ping requests, used by healtcheck in Docker
        # See https://serverfault.com/questions/599159/varnish-as-a-web-server
        return (synth(700, "Ping"));
    }

    # Everything here currently is supported via a host header.
    # The path is rewritten as required by the backend service provider.
    #
    # For MapProxy, each service has to add the service name part of
    # the path back in. Varnish strips the service name out and adds in
    # the port number the service runs on in the backends. Using
    # X-Script-Name in the request to MapProxy tells it to add the
    # service name back in as it sends the response back to the client.
    # If you get it wrong, the client will start asking for tiles with
    # (for example) "/wms" instead of "/city-aerials/wms" and that will
    # show up in the varnish logs as 404 BAD REQUEST because Varnish
    # will use the default backend

    if (req.http.host == "giscache.clatsopcounty.gov"
     || req.http.host == "giscache.co.clatsop.or.us") # deprecated
    {

        if (req.url ~ "^/bulletin78_79/") {
            set req.url = regsub(req.url, "^/bulletin78_79/", "/");
            set req.backend_hint = bulletin;
            set req.http.X-Script-Name = "^/bulletin78_79";
    
        } elseif (req.url ~ "^/city-aerials/") {
            set req.url = regsub(req.url, "^/city-aerials/", "/");
            set req.backend_hint = city_aerials;
            set req.http.X-Script-Name = "/city-aerials";
        
        } elseif (req.url ~ "^/county-aerials/") {
            set req.url = regsub(req.url, "^/county-aerials/", "/");
            set req.backend_hint = county_aerials;
            set req.http.X-Script-Name = "/county-aerials";
    
        } elseif (req.url ~ "^/county-aerials-brief/") {
            set req.url = regsub(req.url, "^/county-aerials-brief/", "/");
            set req.backend_hint = county_aerials_brief;
            set req.http.X-Script-Name = "/county-aerials-brief";
    
        } elseif (req.url ~ "^/lidar-2020/") { # DEPRECATED
            set req.url = regsub(req.url, "/lidar-2020/", "/");
            set req.backend_hint = lidar;
            set req.http.X-Script-Name = "/lidar-2020";
        } elseif (req.url ~ "^/lidar/") {
            set req.url = regsub(req.url, "/lidar/", "/");
            set req.backend_hint = lidar;
            set req.http.X-Script-Name = "/lidar";
    
        } elseif (req.url ~ "^/usgs-nhd/") {
            set req.url = regsub(req.url, "/usgs-nhd/", "/");
            set req.backend_hint = nhd;
            set req.http.X-Script-Name = "/usgs-nhd";
    
        } elseif (req.url ~ "^/wetlands/") {
            set req.url = regsub(req.url, "/wetlands/", "/");
            set req.backend_hint = wetlands;
            set req.http.X-Script-Name = "/wetlands";

        } elseif (req.url ~ "^/dsl_wetlands/") {
            set req.url = regsub(req.url, "/dsl_wetlands/", "/");
            set req.backend_hint = dsl_wetlands;
            set req.http.X-Script-Name = "/dsl_wetlands";

	} elseif (req.url ~ "^/water_system_management/") {
            set req.url = regsub(req.url, "/water_system_management/", "/");
            set req.backend_hint = water_system_management;
            set req.http.X-Script-Name = "/water_system_management";

        } else {
        # This handles the main landing page and the photos.
            set req.backend_hint = default;
        }

    } elseif (req.http.host == "records.clatsopcounty.gov") {
	if (req.url ~ "^/api") {
            set req.backend_hint = records_api;
	} else {
            set req.backend_hint = records_client;
        }

    } elseif (req.http.host == "echo.clatsopcounty.gov") {
        set req.backend_hint = matomo;
    }

    #return (pipe); # Uncomment to deactivate caching
    # Otherwise, cache everything (that is, all GET and HEAD requests)
}

sub vcl_synth {
    set resp.http.Retry-After = "5";
    if (resp.status == 700) {
        set resp.status = 200;
        set resp.reason = "OK";
        set resp.http.Content-Type = "text/plain;";
        synthetic( {"OK"} );
        return (deliver);
    }
    if (resp.status == 701) {
        set resp.status = 204;
        set resp.reason = "No Content";
        set resp.http.Content-Type = "text/plain;";
        synthetic( {""} );
        return (deliver);
    }
    if (resp.status == 751) {
        set resp.http.Location = resp.reason;
        set resp.status = 301;
        set resp.reason = "Moved Permanently";
        return (deliver);
    }

    if (resp.status == 752) {
        set resp.http.Location = resp.reason;
        set resp.status = 302;
        set resp.reason = "Found";
        return (deliver);
    }
}

sub vcl_backend_response {
    # Happens after we have read the response headers from the backend.
    #
    # Here you clean the response headers, removing silly Set-Cookie headers
    # and other mistakes your backend does.

    # https://info.varnish-software.com/blog/how-to-set-and-override-ttl
    set beresp.ttl = 20m;
}

