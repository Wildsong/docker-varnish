vcl 4.1;

backend ha {
    .host = "[homeassistant]";
    .port = "8123";
}

backend psono {
    .host = "192.168.123.2";
    .port = "81";
}

backend pihole {
   .host = "[pihole]";
   .port = "83";
}

sub vcl_recv {

    if (req.http.upgrade ~ "(?i)websocket") {
        return (pipe);
    }

    # Everything here currently is supported via a host header, 
    # the path is just passed through to the service provider.

    # remove port number
    set req.http.Host = regsub(req.http.Host, ":[0-9]+$", "");
	
    if (req.http.Host == "falco.wildsong.biz") {
        set req.backend_hint = psono;
	
    } elseif (req.http.Host == "homeassistant.wildsong.biz") {
        set req.backend_hint = ha;

    } elseif (req.http.Host == "pihole.wildsong.biz") {
        set req.backend_hint = pihole;
    }

    # Nothing we're doing here benefits from caching right now.
    return (pipe); # Uncomment this line to disable caching.
}


sub vcl_pipe {
    if (req.http.upgrade) {
        set bereq.http.upgrade = req.http.upgrade;
        set bereq.http.connection = req.http.connection;
    }
}
