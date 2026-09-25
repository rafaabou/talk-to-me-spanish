#!/usr/bin/env python3
"""Flutter web server: correct MIME types, immutable caching, gzip, Range.

Security properties (see tools/test_serve_web.py):
  * every request path is resolved with realpath and must stay inside the
    served directory, so `..` traversal and symlink escape cannot read files
    such as android/app/release.keystore;
  * directory listing is disabled;
  * responses carry conservative security headers;
  * Range and gzip reads are bounded, and concurrent connections are capped;
  * no wildcard CORS. The app is a single-origin static bundle, so
    cross-origin reads are refused unless --allow-origin is given.

LAN access stays the default so the site can be opened from a phone. Pass
--host 127.0.0.1 to serve this machine only.
"""
import argparse
import gzip
import http.server
import mimetypes
import os
import re
import socketserver
import sys
import threading
import urllib.parse

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
MAX_GZIP_BYTES = 16 * 1024 * 1024
MAX_RANGE_BYTES = 32 * 1024 * 1024
RANGE_RE = re.compile(r'^bytes=(\d*)-(\d*)$')
SOCKET_TIMEOUT = 30
MAX_CONCURRENT = 48

# CanvasKit needs eval/wasm compilation, so script-src keeps 'unsafe-eval' and
# 'wasm-unsafe-eval'. Everything else is same-origin only, and the microphone
# stays available to the app alone (it is needed for speech practice).
CSP = (
    "default-src 'self'; "
    "script-src 'self' 'unsafe-inline' 'unsafe-eval' 'wasm-unsafe-eval'; "
    "style-src 'self' 'unsafe-inline'; "
    "img-src 'self' data: blob:; "
    "media-src 'self' blob: data:; "
    "font-src 'self' data:; "
    "connect-src 'self' blob: data:; "
    "worker-src 'self' blob:; "
    "object-src 'none'; "
    "base-uri 'self'; "
    "frame-ancestors 'self'"
)
ALLOW_ORIGIN = None

_slots = threading.BoundedSemaphore(MAX_CONCURRENT)


class FlutterHandler(http.server.SimpleHTTPRequestHandler):
    # Flutter web nests audio/course under assets/assets/ while the
    # AssetManifest maps them to assets/. Serve both, and survive
    # copies that lost the assets/audio + assets/course symlinks.
    DOUBLE_NESTED = ('/assets/audio/', '/assets/course/')

    protocol_version = 'HTTP/1.1'
    timeout = SOCKET_TIMEOUT

    def _root(self):
        return os.path.realpath(getattr(self, 'directory', None) or os.getcwd())

    def translate_path(self, path):
        """Contain every request, including the plain GET/HEAD fallback.

        The base class drops `..` components but happily follows a symlink
        that points outside the served directory, which is enough to read
        files next to it. realpath plus the prefix check closes that.
        """
        resolved = os.path.realpath(super().translate_path(path))
        root = self._root()
        if resolved != root and not resolved.startswith(root + os.sep):
            return os.path.join(root, '.forbidden')
        return resolved

    def _resolve(self, url_path):
        """Map a URL path to a real file inside the served root, else None.

        realpath collapses `..` and follows symlinks before the containment
        check, so neither a crafted URL nor a planted symlink can escape.
        """
        root = self._root()
        try:
            path = urllib.parse.unquote(urllib.parse.urlsplit(url_path).path)
        except ValueError:
            return None
        if '\x00' in path:
            return None
        candidate = os.path.realpath(os.path.join(root, path.lstrip('/')))
        if candidate != root and not candidate.startswith(root + os.sep):
            return None
        return candidate if os.path.isfile(candidate) else None

    def _double_nested_path(self):
        if not self.path.startswith(self.DOUBLE_NESTED):
            return None
        return self._resolve('/assets/assets/' + self.path[len('/assets/'):])

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
        self.send_header('X-Content-Type-Options', 'nosniff')
        self.send_header('X-Frame-Options', 'SAMEORIGIN')
        self.send_header('Referrer-Policy', 'no-referrer')
        self.send_header('Content-Security-Policy', CSP)
        self.send_header(
            'Permissions-Policy', 'microphone=(self), camera=(), geolocation=()'
        )
        if ALLOW_ORIGIN:
            self.send_header('Access-Control-Allow-Origin', ALLOW_ORIGIN)
            self.send_header('Vary', 'Origin')
        super().end_headers()

    def list_directory(self, path):
        """Never enumerate the bundle; only index.html is served."""
        self.send_error(403, 'Directory listing is disabled')
        return None

    def _local_file(self):
        return self._resolve(self.path)

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

    def _send_416(self, size):
        self.send_response(416)
        self.send_header('Content-Range', f'bytes */{size}')
        self.send_header('Content-Length', '0')
        self._custom_response = True
        self.end_headers()

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
            self._send_416(size)
            return True
        end = min(end, size - 1)
        if end - start + 1 > MAX_RANGE_BYTES:
            self._send_416(size)
            return True
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
        size = os.path.getsize(full)
        if size < GZIP_MIN_BYTES or size > MAX_GZIP_BYTES:
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
            {
                'Content-Encoding': 'gzip',
                'Vary': 'Accept-Encoding',
                'Accept-Ranges': 'bytes',
            },
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

    def handle_one_request(self):
        """Refuse new work when every connection slot is busy."""
        if not _slots.acquire(blocking=False):
            self.send_error(503, 'Server busy')
            return
        try:
            super().handle_one_request()
        finally:
            _slots.release()

    def log_message(self, fmt, *args):
        # Thousands of asset hits per page load; keep the journal readable.
        pass


class ThreadedServer(socketserver.ThreadingMixIn, http.server.HTTPServer):
    daemon_threads = True
    allow_reuse_address = True
    request_queue_size = 32


def parse_args(argv):
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('legacy', nargs='*', help=argparse.SUPPRESS)
    parser.add_argument('--port', type=int, default=8002)
    parser.add_argument('--directory', default='.')
    parser.add_argument(
        '--host',
        default='0.0.0.0',
        help='0.0.0.0 keeps LAN access; 127.0.0.1 serves this machine only',
    )
    parser.add_argument(
        '--allow-origin',
        default=None,
        help='explicit CORS origin (off by default; the bundle is same-origin)',
    )
    args = parser.parse_args(argv)
    # Backwards compatibility with `serve_web.py <port> <directory>`.
    if args.legacy:
        args.port = int(args.legacy[0])
    if len(args.legacy) > 1:
        args.directory = args.legacy[1]
    return args


def main(argv=None):
    global ALLOW_ORIGIN
    args = parse_args(sys.argv[1:] if argv is None else argv)
    ALLOW_ORIGIN = args.allow_origin
    root = os.path.realpath(args.directory)
    if not os.path.isdir(root):
        raise SystemExit(f'Not a directory: {root}')
    os.chdir(root)
    handler = lambda *a, **k: FlutterHandler(*a, directory=root, **k)
    httpd = ThreadedServer((args.host, args.port), handler)
    shown = 'localhost' if args.host in ('0.0.0.0', '') else args.host
    print(f'Serving {root} on http://{shown}:{args.port}', flush=True)
    try:
        httpd.serve_forever()
    except KeyboardInterrupt:
        pass
    finally:
        httpd.server_close()


if __name__ == '__main__':
    main()
