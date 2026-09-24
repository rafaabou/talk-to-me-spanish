#!/usr/bin/env python3
"""Audit exercise duplication exactly the way the app now dedupes.

Mirrors app/lib/services/exercise_dedup.dart: per-lesson removal of repeated
work plus a report of exercises that repeat an earlier lesson of the same
level (those need a content change, not a render change).

Usage: python3 app/tools/audit_duplicate_exercises.py [pt|es]
"""
import json
import os
import re
import sys
import unicodedata
from collections import defaultdict

HERE = os.path.dirname(os.path.abspath(__file__))
LEVELS = os.path.join(HERE, '..', 'assets', 'course', 'levels')

ACCENTS = {
    'á': 'a', 'à': 'a', 'â': 'a', 'ã': 'a', 'ä': 'a', 'å': 'a',
    'ç': 'c', 'é': 'e', 'è': 'e', 'ê': 'e', 'ë': 'e',
    'í': 'i', 'ì': 'i', 'î': 'i', 'ï': 'i',
    'ñ': 'n', 'ý': 'y',
    'ó': 'o', 'ò': 'o', 'ô': 'o', 'õ': 'o', 'ö': 'o',
    'ú': 'u', 'ù': 'u', 'û': 'u', 'ü': 'u',
    'ß': 'ss', 'æ': 'ae', 'œ': 'oe',
}

CHOICE_DRILL_TYPES = {
    'multiple_choice', 'listening_mcq', 'fill_blank', 'match_pairs',
}


def norm(text):
    out = []
    for ch in str(text or '').lower():
        for c in ACCENTS.get(ch, ch):
            out.append(c if ('a' <= c <= 'z' or '0' <= c <= '9') else ' ')
    return re.sub(r'\s+', ' ', ''.join(out)).strip()


def tri_key(tri, lang):
    tri = tri or {}
    return '~'.join((norm(tri.get(lang)), norm(tri.get('en')), norm(tri.get('ar'))))


def options_key(ex, lang):
    return ';'.join(sorted(tri_key(o, lang) for o in (ex.get('options') or [])))


def work_key(ex, lang):
    return '{}|{}|{}|{}'.format(
        ex.get('type', ''),
        tri_key(ex.get('prompt'), lang),
        norm(ex.get('answer')),
        options_key(ex, lang),
    )


def choice_key(ex, lang):
    # A listening drill plays a clip: same clip + same answer is the same work.
    if ex.get('type') in ('listening_mcq', 'listening'):
        return '{}|{}'.format(ex.get('type'), norm(ex.get('answer')))
    if ex.get('type') not in CHOICE_DRILL_TYPES:
        return ''
    options = options_key(ex, lang)
    if not options:
        return ''
    return '{}|{}|{}'.format(ex.get('type'), options, norm(ex.get('answer')))


def dedupe(exercises, lang):
    seen_work, seen_choice, kept = set(), set(), []
    for i, ex in enumerate(exercises):
        if work_key(ex, lang) in seen_work:
            continue
        seen_work.add(work_key(ex, lang))
        choice = choice_key(ex, lang)
        if choice and choice in seen_choice:
            continue
        if choice:
            seen_choice.add(choice)
        kept.append((i, ex))
    return kept


def main():
    lang = sys.argv[1] if len(sys.argv) > 1 else "es"
    files = sorted(f for f in os.listdir(LEVELS) if f.endswith('.json'))
    index = json.load(
        open(os.path.join(HERE, '..', 'assets', 'course', 'index.json')))
    levels = defaultdict(list)
    for lesson in index['lessons']:
        levels[lesson['level']].append(lesson['id'])

    total = hidden = 0
    by_type = defaultdict(int)
    for path in files:
        exercises = json.load(open(os.path.join(LEVELS, path))).get('exercises', [])
        total += len(exercises)
        kept = dedupe(exercises, lang)
        hidden += len(exercises) - len(kept)
        raw = defaultdict(list)
        for i, ex in enumerate(exercises):
            raw[work_key(ex, lang)].append(i)
        for key, idxs in raw.items():
            if len(idxs) > 1:
                by_type[exercises[idxs[0]].get('type')] += len(idxs) - 1

    print('lang={} lessons={} exercises={}'.format(lang, len(files), total))
    print('  hidden as repeated work : {} ({:.1f}%)'.format(
        hidden, 100.0 * hidden / total if total else 0))
    print('  hidden by type          : {}'.format(
        dict(sorted(by_type.items(), key=lambda kv: -kv[1])) or '{}'))

    cross = []
    for level_id, lesson_ids in sorted(levels.items()):
        seen = {}
        for lesson_id in lesson_ids:
            path = os.path.join(LEVELS, lesson_id + '.json')
            if not os.path.exists(path):
                continue
            exercises = json.load(open(path)).get('exercises', [])
            for i, ex in enumerate(exercises):
                key = work_key(ex, lang)
                first = seen.get(key)
                if first is not None and first[0] != lesson_id:
                    cross.append((level_id, lesson_id, i,
                                  first[0], first[1], ex.get('type'),
                                  norm(ex.get('answer'))[:48]))
                elif first is None:
                    seen[key] = (lesson_id, i)
    print('  repeated across lessons : {}'.format(len(cross)))
    for row in cross[:12]:
        print('    {} idx {} repeats {} idx {} [{}] {}'.format(*row))
    return 0


if __name__ == '__main__':
    sys.exit(main())
