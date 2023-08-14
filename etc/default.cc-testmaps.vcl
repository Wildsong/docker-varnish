vcl 4.1;
import std;

# This is the registry server for docker.
# It is required for the records app to work.
backend default {
    .host = "cc-testmaps";
    .port = "5000";
}

##-###############################################################
## These are running in separate containers
## You can even run them on separate machines if you want
## and reference them with [cc-HOSTNAME] and it should resolve.
## I tried using [localhost] but that's not working.

## Web App Builder and Experience Builder
#backend wabde {
#    .host = "cc-testmaps";
#    .port = "3344";
#
#backend exb {
#    .host = "cc-testmaps";
#    .port = "3000";
#}

#sub vcl_init {
# You can do fancy load balancing things if you have the hardware.
# for more info, see https://github.com/nigoroll/libvmod-dynamic/blob/master/src/vmod_dynamic.vcc
#        new d = dynamic.director(port = "80");
#    new vdir = directors.round_robin();
#    vdir.add_backend(cc-testmaps);
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

    if (req.http.host == "foxtrot.clatsopcounty.gov") {
       set req.backend_hint = default;
    }

    # Everything else for now just goes to the registry server


#  return (pipe); # Uncomment this line to disable caching.
  # Cache everything (that is, all GET and HEAD requests)
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
