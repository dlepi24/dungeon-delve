#!/usr/bin/env python3
"""Serve the web build locally for testing.

Run: python3 tools/serve_web.py   ->  http://localhost:8060

Exists because double-clicking index.html cannot work: a file:// page has
origin 'null', so the browser blocks the engine's fetch of its own .wasm and
.pck as "cross-origin". Web builds require HTTP — itch.io provides it in
production; this provides it on your desk.

Sends the cross-origin-isolation headers (COOP/COEP) so the build also works
if threads are ever re-enabled. No dependencies.
"""

import os
from http.server import HTTPServer, SimpleHTTPRequestHandler

PORT = 8060
ROOT = os.path.join(os.path.dirname(__file__), "..", "build", "web")


class Handler(SimpleHTTPRequestHandler):
    def __init__(self, *args, **kwargs):
        super().__init__(*args, directory=ROOT, **kwargs)

    def end_headers(self):
        self.send_header("Cross-Origin-Opener-Policy", "same-origin")
        self.send_header("Cross-Origin-Embedder-Policy", "require-corp")
        self.send_header("Cache-Control", "no-store")
        super().end_headers()


if __name__ == "__main__":
    print(f"Serving {os.path.abspath(ROOT)}")
    print(f"Play at:  http://localhost:{PORT}")
    print("Ctrl+C to stop.")
    HTTPServer(("localhost", PORT), Handler).serve_forever()
