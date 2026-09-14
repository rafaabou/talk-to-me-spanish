#!/usr/bin/env python3
"""Flutter web server with correct MIME types for .opus, .woff2, etc."""
import http.server
import mimetypes
import sys
import os

mimetypes.add_type('audio/ogg', '.opus')
mimetypes.add_type('audio/ogg; codecs=opus', '.opus')
mimetypes.add_type('font/woff2', '.woff2')
mimetypes.add_type('font/woff', '.woff')
mimetypes.add_type('application/wasm', '.wasm')

class FlutterHandler(http.server.SimpleHTTPRequestHandler):
    # Flutter web nests audio/course under assets/assets/ while the
    # AssetManifest maps them to assets/. Serve both, and survive
    # copies that lost the assets/audio + assets/course symlinks.
    DOUBLE_NESTED = ('/assets/audio/', '/assets/course/')

    def _double_nested_path(self):
        prefix = next(
            (p for p in self.DOUBLE_NESTED if self.path.startswith(p)), None)
        if prefix is None:
            return None
        alt = '/assets/assets/' + self.path[len('/assets/'):]
        full = os.path.normpath(os.path.join(os.getcwd(), alt.lstrip('/')))
        return full if os.path.isfile(full) else None

    def do_GET(self):
        alt = self._double_nested_path()
        if alt is not None:
            self.path = '/assets/assets/' + self.path[len('/assets/'):]
        return super().do_GET()

    def end_headers(self):
        self.send_header('Cache-Control', 'no-cache')
        self.send_header('Access-Control-Allow-Origin', '*')
        super().end_headers()

if __name__ == '__main__':
    port = int(sys.argv[1]) if len(sys.argv) > 1 else 8002
    directory = sys.argv[2] if len(sys.argv) > 2 else '.'
    os.chdir(directory)
    httpd = http.server.HTTPServer(('', port), FlutterHandler)
    print(f'Serving on http://localhost:{port}')
    httpd.serve_forever()
