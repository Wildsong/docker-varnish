vcl 4.1;

backend ha {
    .host = "[bellman]";
    .port = "8123";
}

backend psono {
    .host = "[bellman]";
    .port = "81";
}

# Can't see why I need pihole access from the Internet right now
#backend pihole null;

sub vcl_recv {

    # Everything here currently is supported via a host header, 
    # the path is just passed through to the service provider.

    # remove port number
    set req.http.Host = regsub(req.http.Host, ":[0-9]+$", "");
	
    if (req.http.Host == "falco.wildsong.biz") {
        set req.backend_hint = psono;
    } elseif (req.http.Host == "homeassistant.wildsong.biz") {
        set req.backend_hint = ha;
    }

    #return (pipe); # Uncomment this line to disable caching.
}

