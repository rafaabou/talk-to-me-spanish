#!/usr/bin/env python3
"""Security tests for serve_web.py (stdlib only, no dependencies).

Run from the repository root:
    python3 tools/test_serve_web.py
"""
import gzip
import os
import shutil
import sys
import tempfile
import threading
import unittest
import urllib.error
import urllib.request

sys.path.insert(0, os.path.dirname(os.path.dirname(os.path.abspath(__file__))))
import serve_web  # noqa: E402


class ServeWebTest(unittest.TestCase):
    @classmethod
    def setUpClass(cls):
        cls.tmp = tempfile.mkdtemp(prefix='serve-web-test-')
        web = os.path.join(cls.tmp, 'web')
        os.makedirs(os.path.join(web, 'assets', 'assets', 'audio'))
        # A secret that lives outside the web root, like release.keystore does.
        with open(os.path.join(cls.tmp, 'secret.txt'), 'w') as handle:
            handle.write('TOPSECRET')
        with open(os.path.join(web, 'index.html'), 'w') as handle:
            handle.write('<html><body>ok</body></html>')
        with open(os.path.join(web, 'main.dart.js'), 'w') as handle:
            handle.write('console.log(1);' * 400)
        with open(
            os.path.join(web, 'assets', 'assets', 'audio', 'pt_1.opus'), 'wb'
        ) as handle:
            handle.write(b'OggS' + b'\0' * 64)
        # The relative in-root symlink the double-nested fix creates.
        os.symlink('assets/audio', os.path.join(web, 'assets', 'audio'))
        # A symlink that tries to escape the root.
        os.symlink(
            os.path.join(cls.tmp, 'secret.txt'),
            os.path.join(web, 'escape.txt'),
        )

        serve_web.main.__globals__['ALLOW_ORIGIN'] = None
        cls.server = serve_web.ThreadedServer(
            ('127.0.0.1', 0), lambda *a, **k: serve_web.FlutterHandler(
                *a, directory=web, **k
            )
        )
        cls.port = cls.server.server_address[1]
        cls.thread = threading.Thread(target=cls.server.serve_forever, daemon=True)
        cls.thread.start()

    @classmethod
    def tearDownClass(cls):
        cls.server.shutdown()
        cls.server.server_close()
        shutil.rmtree(cls.tmp, ignore_errors=True)

    def url(self, path, headers=None):
        request = urllib.request.Request(
            f'http://127.0.0.1:{self.port}{path}', headers=headers or {}
        )
        return urllib.request.urlopen(request, timeout=10)

    def status(self, path, headers=None):
        try:
            with self.url(path, headers) as response:
                return response.status, response.read()
        except urllib.error.HTTPError as error:
            return error.code, error.read()

    def test_serves_index(self):
        status, body = self.status('/index.html')
        self.assertEqual(200, status)
        self.assertIn(b'ok', body)

    def test_rejects_dot_dot_traversal(self):
        for attempt in (
            '/../secret.txt',
            '/assets/../../secret.txt',
            '/%2e%2e/secret.txt',
            '/..%2fsecret.txt',
            '/assets/../../../../etc/passwd',
        ):
            with self.subTest(attempt=attempt):
                self.assertIn(self.status(attempt)[0], (400, 403, 404))

    def test_rejects_symlink_escape(self):
        status, body = self.status('/escape.txt')
        self.assertIn(status, (403, 404))
        self.assertNotIn(b'TOPSECRET', body)

    def test_directory_listing_disabled(self):
        status, _ = self.status('/assets/')
        self.assertIn(status, (403, 404))

    def test_security_headers_present(self):
        with self.url('/index.html') as response:
            self.assertEqual('nosniff', response.headers['X-Content-Type-Options'])
            self.assertEqual('SAMEORIGIN', response.headers['X-Frame-Options'])
            self.assertEqual('no-referrer', response.headers['Referrer-Policy'])
            self.assertIn("default-src 'self'", response.headers['Content-Security-Policy'])
            self.assertIn(
                'microphone=(self)', response.headers['Permissions-Policy']
            )
            self.assertIsNone(response.headers.get('Access-Control-Allow-Origin'))

    def test_range_request_works(self):
        status, body = self.status(
            '/index.html', headers={'Range': 'bytes=0-4'}
        )
        self.assertEqual(206, status)
        self.assertEqual(5, len(body))

    def test_oversized_range_refused(self):
        original = serve_web.MAX_RANGE_BYTES
        serve_web.MAX_RANGE_BYTES = 2
        try:
            status, _ = self.status('/index.html', headers={'Range': 'bytes=0-100'})
            self.assertEqual(416, status)
        finally:
            serve_web.MAX_RANGE_BYTES = original

    def test_gzip_for_large_text(self):
        with self.url(
            '/main.dart.js', headers={'Accept-Encoding': 'gzip'}
        ) as response:
            body = response.read()
            self.assertEqual(200, response.status)
            self.assertEqual('gzip', response.headers['Content-Encoding'])
            self.assertTrue(body.startswith(b'\x1f\x8b'))
            # Smaller than the original, and it really is the same file.
            self.assertLess(len(body), 4800)
            self.assertEqual(
                'console.log(1);' * 400, gzip.decompress(body).decode()
            )

    def test_double_nested_audio_alias(self):
        status, body = self.status('/assets/audio/pt_1.opus')
        self.assertEqual(200, status)
        self.assertTrue(body.startswith(b'OggS'))


if __name__ == '__main__':
    unittest.main(verbosity=2)
