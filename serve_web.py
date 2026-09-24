#!/usr/bin/env python3
"""Flutter web server: correct MIME types, immutable caching, gzip, Range."""
import gzip
import http.server
import mimetypes
import os
import re
import socketserver
import sys

mimetypes.add_type('audio/ogg', '.opus')
mimetypes.add_type('audio/ogg; codecs=opus', '.opus')
mimetypes.add_type('font/woff2', '.woff2')
mimetypes.add_type('font/woff', '.woff')
mimetypes.add_type('application/wasm', '.wasm')

NO_CACHE_PATHS = {
    '/',
    '/index.html',
    '/flutter_service_worker.js',
    '/version.json',
}
IMMUTABLE_PREFIXES = ('/assets/', '/canvaskit/', '/icons/')
IMMUTABLE_FILES = (
    '/main.dart.js',
    '/flutter.js',
    '/flutter_bootstrap.js',
    '/favicon.png',
    '/manifest.json',
)
GZIP_EXTENSIONS = ('.js', '.wasm', '.json', '.html', '.css', '.svg', '.txt', '.xml', '.map')
GZIP_MIN_BYTES = 1024
RANGE_RE = re.compile(r'^bytes=(\d*)-(\d*)$')


class FlutterHandler(http.server.SimpleHTTPRequestHandler):
    # Flutter web nests audio/course under assets/assets/ while the
    # AssetManifest maps them to assets/. Serve both, and survive
    # copies that lost the assets/audio + assets/course symlinks.
    DOUBLE_NESTED = ('/assets/audio/', '/assets/course/')

    protocol_version = 'HTTP/1.1'

    def _double_nested_path(self):
        prefix = next(
            (p for p in self.DOUBLE_NESTED if self.path.startswith(p)), None)
        if prefix is None:
            return None
        alt = '/assets/assets/' + self.path[len('/assets/'):]
        full = os.path.normpath(os.path.join(os.getcwd(), alt.lstrip('/')))
        return full if os.path.isfile(full) else None

    def _rewire_double_nested(self):
        if self._double_nested_path() is not None:
            self.path = '/assets/assets/' + self.path[len('/assets/'):]

    def _cache_control(self):
        path = self.path.split('?', 1)[0]
        if path in NO_CACHE_PATHS:
            return 'no-cache'
        if path in IMMUTABLE_FILES or path.startswith(IMMUTABLE_PREFIXES):
            return 'public, max-age=31536000, immutable'
        return 'no-cache'

    def end_headers(self):
        if not getattr(self, '_custom_response', False):
            self.send_header('Cache-Control', self._cache_control())
            self.send_header('Vary', 'Accept-Encoding')
            self.send_header('Accept-Ranges', 'bytes')
        self.send_header('Access-Control-Allow-Origin', '*')
        super().end_headers()

    def _local_file(self):
        path = self.path.split('?', 1)[0].split('#', 1)[0]
        root = getattr(self, 'directory', None) or os.getcwd()
        full = os.path.normpath(os.path.join(root, path.lstrip('/')))
        return full if os.path.isfile(full) else None

    def _send_body(self, status, full, body, extra=None):
        self.send_response(status)
        self.send_header('Content-Type', self.guess_type(full))
        self.send_header('Content-Length', str(len(body)))
        self.send_header('Last-Modified', self.date_time_string(os.path.getmtime(full)))
        for key, value in (extra or {}).items():
            self.send_header(key, value)
        self._custom_response = True
        self.end_headers()
        if self.command != 'HEAD':
            self.wfile.write(body)

    def _serve_range(self):
        header = self.headers.get('Range')
        if not header:
            return False
        match = RANGE_RE.match(header.strip())
        if not match:
            return False
        full = self._local_file()
        if full is None:
            return False
        size = os.path.getsize(full)
        first, last = match.groups()
        if first:
            start = int(first)
            end = int(last) if last else size - 1
        else:
            if not last:
                return False
            start = max(0, size - int(last))
            end = size - 1
        if start >= size or start > end:
            self.send_response(416)
            self.send_header('Content-Range', f'bytes */{size}')
            self.send_header('Content-Length', '0')
            self._custom_response = True
            self.end_headers()
            return True
        end = min(end, size - 1)
        with open(full, 'rb') as handle:
            handle.seek(start)
            body = handle.read(end - start + 1)
        self._send_body(
            206,
            full,
            body,
            {
                'Content-Range': f'bytes {start}-{end}/{size}',
                'Accept-Ranges': 'bytes',
                'Vary': 'Accept-Encoding',
            },
        )
        return True

    def _serve_gzip(self):
        full = self._local_file()
        if full is None or not full.endswith(GZIP_EXTENSIONS):
            return False
        if 'gzip' not in (self.headers.get('Accept-Encoding') or ''):
            return False
        if os.path.getsize(full) < GZIP_MIN_BYTES:
            return False
        with open(full, 'rb') as handle:
            raw = handle.read()
        body = gzip.compress(raw, 6)
        if len(body) >= len(raw):
            return False
        self._send_body(
            200,
            full,
            body,
            {'Content-Encoding': 'gzip', 'Vary': 'Accept-Encoding', 'Accept-Ranges': 'bytes'},
        )
        return True

    def do_GET(self):
        self._custom_response = False
        self._rewire_double_nested()
        if self._serve_range() or self._serve_gzip():
            return
        super().do_GET()

    def do_HEAD(self):
        self._custom_response = False
        self._rewire_double_nested()
        super().do_HEAD()

    def log_message(self, fmt, *args):
        # Thousands of asset hits per page load; keep the journal readable.
        pass


class ThreadedServer(socketserver.ThreadingMixIn, http.server.HTTPServer):
    daemon_threads = True
    allow_reuse_address = True


if __name__ == '__main__':
    port = int(sys.argv[1]) if len(sys.argv) > 1 else 8002
    directory = sys.argv[2] if len(sys.argv) > 2 else '.'
    os.chdir(directory)
    httpd = ThreadedServer(('', port), FlutterHandler)
    print(f'Serving on http://localhost:{port}', flush=True)
    httpd.serve_forever()
