"""
Web server primarily intended to serve the Let's Encrypt certbot challenges.
"""
import os, sys
import http.server
import socket

HOSTNAME = socket.gethostname()
PORT = 8000
DIRECTORY = '/www'

class Handler(http.server.SimpleHTTPRequestHandler):
    def __init__(self, *args, **kwargs):
        global HOSTNAME, PORT, DIRECTORY
        super().__init__(*args, directory=DIRECTORY, **kwargs)

    def do_GET(self):

        # We expect only Let's Encrypt requests here, anything else is probably a mistake in default.vcl
        if self.path.startswith('/.well-known/acme-challenge'):
            #super().do_GET() # This maps the request to a file
            path = '/www' + self.path
            #path = '/home/gis/docker/varnish/acme-challenge/test.html'
            with open(path, "r") as fp:
                text = '\n'.join(fp.readlines())
            self.send_response(200, message="OK")
            self.send_header("Content-type", "text/html")
            self.send_header("Content-Length", len(text))
            self.send_header('X-SERVICE','ACME')
            self.end_headers()
            self.wfile.write(bytes(text, 'utf-8'))
            return

        self.send_response(404, message='BAD REQUEST')
        self.send_header("Content-type", "text/html")
        self.end_headers()
        self.wfile.write(bytes(f"<html><body><h1>Challenge failed 404</h1>req=\"{self.path}\"</body></html>", "utf-8"))
        return

with http.server.HTTPServer(("", PORT), Handler) as httpd:
    print(f"Serving HTTP on port {PORT}.", file=sys.stderr)
    httpd.serve_forever()

