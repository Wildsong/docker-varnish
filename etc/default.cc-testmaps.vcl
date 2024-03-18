vcl 4.1;
import std;

backend pgadmin {
    .host = "cc-testmaps";
    .port = "8213";
}
backend property {
    .host = "cc-testmaps";
    .port = "8080";
}
backend property_api {
    .host = "cc-testmaps";
    .port = "4000";
}

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

    if (req.url ~ "^/property/") {
        set req.url = regsub(req.url, "^/property/", "/"); # remove the route
        set req.http.X-Script-Name = "/property"; # mark it in the header
        set req.backend_hint = property; # pick the right backend        
    }
    elseif (req.url ~ "^/api") {
        #set req.url = regsub(req.url, "^/api", "/"); # remove the route
        set req.http.X-Script-Name = "/api"; # mark it in the header
        set req.backend_hint = property_api; # pick the right backend        
    }
    else {
        set req.http.X-Script-Name = "/pgadmin"; # mark it in the header
        set req.backend_hint = pgadmin; # pick the right backend        
    }

    # Normally no caching on foxtrot, I want to hit the backends every time to test faster...
    return (pipe); # Uncomment to deactivate caching
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

