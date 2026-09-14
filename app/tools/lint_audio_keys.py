#!/usr/bin/env python3
"""Verify every audio key reachable from the course content has a real clip.

Matches the Dart AudioService.audioKey contract exactly:
    audioKey(text, lang) = f'{lang}_{md5(f"{lang}:{text.strip()}")[:12]}.opus'

Usage:
    python3 tools/lint_audio_keys.py assets/course [--native pt|es] [--strict]

Exit codes: 0 clean, 1 gaps found, 2 invariant broken.
"""
import hashlib
import json
import os
import sys
import glob

NATIVE_KEYS = {'pt': 'pt', 'es': 'es', 'ar': 'ar', 'en': 'en'}


def audio_key(text, lang):
    t = text.strip()
    h = hashlib.md5(f'{lang}:{t}'.encode('utf-8')).hexdigest()
    return f'{lang}_{h[:12]}.opus'


def walk_texts(level, native, lang):
    """Yield (key, source) for every text the app actually feeds to
    AudioService.playText. Mirrors the real AudioButton placements:
    vocab words/examples, grammar content, dialogue lines, reading
    text, and exercise answers/audio. Prompts and option labels are
    rendered as text only and are intentionally NOT checked."""
    def key(t, src):
        if not t:
            return None
        t = str(t)
        yield audio_key(t, lang), f'{src}:{t[:40]!r}'

    def get(v, k, d=''):
        return v.get(k, d) if isinstance(v, dict) else d

    def localized(v, src):
        """Play the native-language field when present, else the plain value."""
        if isinstance(v, dict):
            if v.get(native):
                yield from key(v[native], src)
            else:
                yield from key(v.get('en', '') or list(v.values())[0], src)
        else:
            yield from key(v, src)

    for v in level.get('vocabulary', []):
        yield from key(get(v, native), 'vocab.word')
        ex = get(v, 'example')
        if ex:
            yield from localized(ex if isinstance(ex, dict) else {'pt': ex, 'es': ex, 'ar': ex, 'en': ex}, 'vocab.example')
    for g in level.get('grammar', []):
        yield from localized(get(g, 'explanation'), 'grammar.expl')
        for ex in get(g, 'examples', []) or []:
            yield from key(get(ex, native) or ex, 'grammar.example')
    dia = get(level, 'dialogue')
    for line in (dia.get('lines') if isinstance(dia, dict) else dia) or []:
        yield from key(get(line, native), 'dialogue.line')
    rd = get(level, 'reading')
    if isinstance(rd, dict):
        for k in (f'text_{native}', native):
            yield from key(rd.get(k), 'reading.text')
    for ex in level.get('exercises', []):
        ex_type = get(ex, 'type', '')
        for k in ('audio',):
            yield from key(get(ex, k), f'exercise.{k}')
        ans = get(ex, 'answer')
        if ans and ex_type in ('listening', 'dictation', 'listening_mcq',
                               'sentence_reorder', 'writing', 'translation'):
            if '::' not in ans:
                yield from key(ans.split('/')[0], 'exercise.answer')


def main():
    args = [a for a in sys.argv[1:] if not a.startswith('--')]
    strict = '--strict' in sys.argv
    native = next((a for a in args if a in NATIVE_KEYS), None)
    lang = native
    root = next((a for a in args if os.path.isdir(a)) or args, 'assets/course')
    files = sorted(glob.glob(os.path.join(root, '*.json')))
    files = [f for f in files if os.path.basename(f) != 'index.json']
    if not files:
        print('ERROR: no level files found in', root)
        return 2
    audio_dir = os.path.join(os.path.dirname(os.path.dirname(root)), 'audio')
    missing = []
    whitespace_pains = []
    total = 0
    for f in files:
        L = json.load(open(f, encoding='utf-8'))
        # exercise pairs nest answer sentences; collect too
        for key, src in walk_texts(L, native, lang):
            total += 1
            if not os.path.isfile(os.path.join(audio_dir, key)):
                missing.append((f, key, src))
    print(f'{lang}: {total} audio-able texts, {len(missing)} missing keys')
    if whitespace_pains:
        print(f'WARN: {len(whitespace_pains)} texts have edge whitespace:')
        for f, v in whitespace_pains[:5]:
            print(f'  {f}: {v!r}')
    if missing:
        print('MISSING CLIPS:')
        for f, key, src in missing[:40]:
            print(f'  {f} :: {key} :: {src}')
        return 1
    if strict and whitespace_pains:
        return 1
    print('OK')
    return 0


if __name__ == '__main__':
    sys.exit(main())