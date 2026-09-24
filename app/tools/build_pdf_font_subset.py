#!/usr/bin/env python3
"""Build the font subset embedded in exported PDFs.

The `pdf` package defaults to Helvetica, which has no IPA glyphs, so lesson
exports dropped characters like ˈ ɾ ʁ ʃ. This produces a small subset of
Noto Sans containing exactly what the export can render: printable ASCII,
Latin-1, Latin Extended, the IPA Extensions block and combining diacritics.

Arabic is deliberately excluded: the `pdf` package performs no complex-script
shaping, so Arabic would come out unshaped and disconnected no matter which
font is embedded.

Usage: python3 app/tools/build_pdf_font_subset.py
"""
import os
import subprocess
import sys

HERE = os.path.dirname(os.path.abspath(__file__))
APP = os.path.dirname(HERE)
OUT_DIR = os.path.join(APP, 'assets', 'fonts')
SOURCE_REGULAR = '/usr/share/fonts/truetype/noto/NotoSans-Regular.ttf'
SOURCE_BOLD = '/usr/share/fonts/truetype/noto/NotoSans-Bold.ttf'

# Printable ASCII, Latin-1, Latin Extended, the IPA Extensions block, spacing
# modifiers, Greek (a few IPA transcriptions use χ), combining diacritics, Latin
# Extended Additional, and the general punctuation block used by labels.
UNICODES = ','.join(
    [
        'U+0020-007E',  # printable ASCII
        'U+00A0-00FF',  # Latin-1 supplement
        'U+0100-017F',  # Latin Extended-A
        'U+0180-024F',  # Latin Extended-B
        'U+0250-02FF',  # IPA Extensions + spacing modifiers (ˈ = U+02C8)
        'U+0300-036F',  # combining diacritical marks
        'U+0370-03FF',  # Greek (χ appears in the IPA data)
        'U+1E00-1EFF',  # Latin Extended Additional
        'U+2000-206F',  # general punctuation
        'U+20AC,U+2122',  # euro, trademark
    ]
)


def build(source: str, target: str) -> None:
    if not os.path.isfile(source):
        sys.exit(f'missing source font: {source}')
    os.makedirs(OUT_DIR, exist_ok=True)
    cmd = [
        sys.executable,
        '-m',
        'fontTools.subset',
        source,
        f'--unicodes={UNICODES}',
        f'--output-file={target}',
        '--layout-features=kern,liga,calt,ccmp,locl',
        '--no-hinting',
        '--desubroutinize',
        '--name-IDs=1,2,3,4,6',
        '--drop-tables+=DSIG',
    ]
    subprocess.run(cmd, check=True)
    size = os.path.getsize(target)
    print(f'{os.path.basename(target)}: {size / 1024:.1f} KB')


if __name__ == '__main__':
    build(SOURCE_REGULAR, os.path.join(OUT_DIR, 'NotoSansPdf-Regular.ttf'))
    build(SOURCE_BOLD, os.path.join(OUT_DIR, 'NotoSansPdf-Bold.ttf'))
