#!/usr/bin/env python3
"""Guard the gitleaks configuration against becoming a no-op.

Run from the repository root:
    python3 tools/test_gitleaks_config.py
"""
import os
import re
import sys
import unittest

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
CONFIG = os.path.join(ROOT, '.gitleaks.toml')

# Extensions that must stay scannable: real secrets live in these files.
# pubspec.lock is deliberately excluded: it is a vendored checksum file.
MUST_SCAN = ('.dart', '.yaml', '.yml', '.json', '.md', '.xml', '.kts', '.properties',
             '.toml', '.py', '.sh', '.ps1', '.kt', '.gradle', '.txt', '.env')


def read_config():
    with open(CONFIG, encoding='utf-8') as handle:
        return handle.read()


class GitleaksConfigTest(unittest.TestCase):
    def setUp(self):
        self.text = read_config()

    def test_uses_default_rules(self):
        self.assertIn('useDefault = true', self.text)

    def test_no_blanket_extension_allowlist(self):
        """An earlier config allowlisted whole extensions, hiding real secrets."""
        for pattern in (r'\*\\\.json', r'\*\\\.ya?ml', r'\*\\\.md', r'\*\\\.lock',
                        r'\*\\\.xml', r'\*\\\.txt', r'\*\\\.toml'):
            self.assertIsNone(
                re.search(pattern, self.text),
                f'broad allowlist pattern {pattern} must not come back',
            )

    def test_no_blanket_term_allowlist(self):
        """Bare words such as "test" or "123" disable the scanner entirely."""
        entries = re.findall(r'^\s{4}"([^"]+)",\s*$', self.text, re.M)
        for word in ('test', 'example', 'sample', 'dummy', 'fake', 'mock',
                     'placeholder', '123', 'abc', 'build/', 'android/'):
            self.assertNotIn(word, entries, f'"{word}" must not be allowlisted')

    def test_source_extensions_are_not_path_allowlisted(self):
        paths = re.findall(r"'''([^']+)'''", self.text)
        for extension in MUST_SCAN:
            for path in paths:
                # Build/cache directories are fine; the check is about source files.
                if any(marker in path for marker in ('build/', '.dart_tool/', 'ephemeral/')):
                    continue
                self.assertNotIn(
                    extension, path,
                    f'{extension} sources must stay scannable ({path})',
                )


if __name__ == '__main__':
    sys.exit(0 if unittest.main(exit=False, verbosity=2).result.wasSuccessful() else 1)
