vcl 4.1;

# Let's Encrypt challenge server

backend certbot_challenge {
    .host = "[challenger]";
    .port = "8000";
}

sub vcl_recv {
    if (req.url ~ "^/\.well-known/acme-challenge/") {
        set req.backend_hint = certbot_challenge;
        return(pipe);
    }
}

sub vcl_pipe {
    if (req.backend_hint == certbot_challenge) {
        set req.http.Connection = "close";
        return(pipe);
    }
}