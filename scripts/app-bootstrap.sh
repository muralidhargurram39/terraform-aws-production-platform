#!/bin/bash

set -euxo pipefail

dnf update -y

dnf install -y python3

mkdir -p /opt/dev-platform

cat > /opt/dev-platform/app.py <<'PYTHON'
from http.server import BaseHTTPRequestHandler, HTTPServer
import json
import socket


class Handler(BaseHTTPRequestHandler):

    def do_GET(self):
        if self.path == "/health":
            response = {
                "status": "healthy",
                "hostname": socket.gethostname()
            }

            body = json.dumps(response).encode()

            self.send_response(200)
            self.send_header("Content-Type", "application/json")
            self.send_header("Content-Length", str(len(body)))
            self.end_headers()
            self.wfile.write(body)

        elif self.path == "/":
            response = {
                "application": "AWS Production Platform",
                "environment": "dev",
                "hostname": socket.gethostname(),
                "status": "running"
            }

            body = json.dumps(response).encode()

            self.send_response(200)
            self.send_header("Content-Type", "application/json")
            self.send_header("Content-Length", str(len(body)))
            self.end_headers()
            self.wfile.write(body)

        else:
            self.send_response(404)
            self.end_headers()

    def log_message(self, format, *args):
        print("%s - %s" % (self.address_string(), format % args))


server = HTTPServer(("0.0.0.0", 8080), Handler)

print("Application listening on port 8080")

server.serve_forever()
PYTHON

cat > /etc/systemd/system/dev-platform.service <<'SYSTEMD'
[Unit]
Description=Dev Platform Demo Application
After=network-online.target
Wants=network-online.target

[Service]
Type=simple
User=root
WorkingDirectory=/opt/dev-platform
ExecStart=/usr/bin/python3 /opt/dev-platform/app.py
Restart=always
RestartSec=5

[Install]
WantedBy=multi-user.target
SYSTEMD

systemctl daemon-reload
systemctl enable dev-platform
systemctl start dev-platform

systemctl status dev-platform --no-pager
