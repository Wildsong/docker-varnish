vcl 4.1;

# Static content
backend default {
    .host = "192.168.123.2";
    .port = "88";
}

backend pihole {
   .host = "192.168.123.2";
   .port = "83";
}

# This is (currently) a copy of TARRA wiki
backend tarra {
   .host = "192.168.123.2";
   .port = "81";
}

sub vcl_recv {

    if (req.http.upgrade ~ "(?i)websocket") {
        return (pipe); # Don't cache websocket traffic
    }

    # remove port number
    set req.http.Host = regsub(req.http.Host, ":[0-9]+$", "");
	
    if (req.url ~ "^/ping") {
        # respond HTTP 200 to /ping requests, used by healtcheck in Docker
	# See https://serverfault.com/questions/599159/varnish-as-a-web-server
        return (synth(700, "Ping"));
    }

    # Everything here currently is supported via a host header, 
    # the path is just passed through to the service provider.

    if (req.http.Host == "pihole.wildsong.biz") {
        set req.backend_hint = pihole;

    } elseif (req.http.Host == "tarra.wildsong.biz") {
        set req.backend_hint = tarra;

    } else {
        # Everything else just gets a simple web page
        set req.backend_hint = default;
    }

    #return (pipe); # Uncomment this line to disable caching.
}


sub vcl_pipe {
    if (req.http.upgrade) {
        set bereq.http.upgrade = req.http.upgrade;
	set bereq.http.connection = req.http.connection;
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
}

sub vcl_backend_response {
    # Happens after we have read the response headers from the backend.
    #
    # Here you clean the response headers, removing silly Set-Cookie headers
    # and other mistakes your backend does.

    # https://info.varnish-software.com/blog/how-to-set-and-override-ttl
    set beresp.ttl = 20m;
}
