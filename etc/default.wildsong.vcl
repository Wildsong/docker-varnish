vcl 4.1;
import std;

# Let's Encrypt challenge server
backend certbot_challenge {
    .host = "[challenger]";
    .port = "8000";
}

backend ha {
    .host = "[homeassistant]";
    .port = "8123";
}

backend psono {
    .host = "[psono]";
}

#sub vcl_init {
# You can do fancy load balancing things if you have the hardware.
# for more info, see https://github.com/nigoroll/libvmod-dynamic/blob/master/src/vmod_dynamic.vcc
#    new d = dynamic.director(port = "80");
#	new vdir = directors.round_robin();
#	vdir.add_backend(giscache);
#}

sub vcl_recv {

    # Everything here currently is supported via a host header, 
    # the path is just passed through to the service provider.

    # remove port number
    set req.http.Host = regsub(req.http.Host, ":[0-9]+$", "");
	
    # Logging - since this is catching unexpected things
    # I could easily set up a fail2ban rule here, huh?
    if (std.port(server.ip) == 443) {
	std.log("Client connected over TLS/SSL: " + server.ip);
	std.syslog(6,"Client connected over TLS/SSL: " + server.ip);
	std.timestamp("After std.syslog");
    }

    if (req.http.Host == "falco.wildsong.biz") {
        set req.backend_hint = psono;


    } elseif (req.http.Host == "homeassistant.wildsong.biz") {
        set req.backend_hint = ha;
    }

    if (req.method != "GET" && req.method != "HEAD") {
    	return (pass); # Don't cache
    }

    return (pipe); # Do no caching
}