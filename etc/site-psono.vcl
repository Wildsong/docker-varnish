backend psono {
	.host = "[psono]";
}

sub vcl_recv {
    if (req.http.Host == "falco.wildsong.biz") {
        set req.backend_hint = psono;
        return (pipe);
    }
}