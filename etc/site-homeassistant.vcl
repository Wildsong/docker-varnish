backend ha {
	.host = "[homeassistant]";
}

sub vcl_recv {
    if (req.http.Host == "homeassistant.wildsong.biz") {
        set req.backend_hint = ha;
        return (pipe);
    }
}
