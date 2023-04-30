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

sub vcl_recv {

    if (req.http.upgrade ~ "(?i)websocket") {
        # skip the cache
        return (pipe);
    }

 
    # Everything here currently is supported via a host header, 
    # the path is just passed through to the service provider.

    # remove port number
    set req.http.Host = regsub(req.http.Host, ":[0-9]+$", "");
	
    if (req.url ~ "^/ping") {
        # respond HTTP 200 to /ping requests, used by healtcheck in Docker
	# See https://serverfault.com/questions/599159/varnish-as-a-web-server
        return (synth(700, "Ping"));

    }

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

    return (deliver);
}

sub vcl_backend_response {
    # Happens after we have read the response headers from the backend.
    #
    # Here you clean the response headers, removing silly Set-Cookie headers
    # and other mistakes your backend does.
}
