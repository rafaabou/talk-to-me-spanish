#!/usr/bin/env python3
"""Bring the Spanish course up to parity with the Portuguese one.

ES only had multiple_choice and translation, while PT has nine exercise types.
This adds listening, dictation, listening_mcq, sentence_reorder and fill_blank
to every lesson, built **only from sentences that already have audio** (the
dialogue lines, vocabulary examples and reading text of that same lesson), so
no new text-to-speech is needed and the audio lint stays at zero missing.

Every generated exercise is marked with `gen: "es-parity-v1"` and the script
refuses to touch a lesson that already has any marked exercise, so it is safe
to re-run.

Usage: python3 app/tools/generate_es_exercises.py [--dry-run]
"""
import argparse
import glob
import hashlib
import json
import os
import re
import sys
import unicodedata

HERE = os.path.dirname(os.path.abspath(__file__))
APP = os.path.dirname(HERE)
LEVELS = os.path.join(APP, 'assets', 'course', 'levels')
AUDIO = os.path.join(APP, 'assets', 'audio')
MARKER = 'es-parity-v1'

PROMPTS = {
    'listening': {
        'es': 'Escucha y escribe lo que oyes.',
        'en': 'Listen and type what you hear.',
        'ar': 'استمع واكتب ما سمعته.',
    },
    'dictation': {
        'es': 'Escucha y escribe la frase completa.',
        'en': 'Listen and write the whole sentence.',
        'ar': 'استمع واكتب الجملة كاملة.',
    },
    'listening_mcq': {
        'es': 'Escucha y elige la frase que oíste.',
        'en': 'Listen and choose the sentence you heard.',
        'ar': 'استمع واختر الجملة التي سمعتها.',
    },
    'sentence_reorder': {
        'es': 'Reordena las palabras para formar la frase:',
        'en': 'Reorder the words to form the sentence:',
        'ar': 'أعد ترتيب الكلمات لتكوين الجملة:',
    },
    'fill_blank': {
        'es': 'Completa la frase con la palabra correcta:',
        'en': 'Complete the sentence with the right word:',
        'ar': 'أكمل الجملة بالكلمة الصحيحة:',
    },
}

EXPLANATION = {
    'listening': ('La frase correcta: \'{sentence}\'', 'The correct sentence: \'{sentence}\'', 'الجملة الصحيحة: \'{sentence}\''),
    'dictation': ('La frase correcta: \'{sentence}\'', 'The correct sentence: \'{sentence}\'', 'الجملة الصحيحة: \'{sentence}\''),
    'listening_mcq': ('Escuchaste: \'{sentence}\'', 'You heard: \'{sentence}\'', 'سمعت: \'{sentence}\''),
    'sentence_reorder': ('La frase correcta: \'{sentence}\'', 'The correct sentence: \'{sentence}\'', 'الجملة الصحيحة: \'{sentence}\''),
    'fill_blank': ('La palabra completa: \'{word}\'', 'The complete word: \'{word}\'', 'الكلمة الكاملة: \'{word}\''),
}


def norm(text):
    decomposed = unicodedata.normalize('NFKD', str(text or ''))
    stripped = ''.join(c for c in decomposed if not unicodedata.combining(c))
    return re.sub(r'[^a-z0-9]+', ' ', stripped.lower()).strip()


def audio_key(text, lang='es'):
    return '{}_{}.opus'.format(lang, hashlib.md5(f'{lang}:{text.strip()}'.encode()).hexdigest()[:12])


def tri(es, en, ar):
    return {'es': es, 'en': en, 'ar': ar}


def word_tri(word):
    return tri(word, word, word)


class SentencePool:
    """Audio-backed sentences from one lesson, with English and Arabic."""

    def __init__(self, lesson):
        self.sentences = []
        for line in (lesson.get('dialogue') or {}).get('lines') or []:
            es = (line.get('es') or '').strip()
            if es and line.get('en') and line.get('ar'):
                self.sentences.append((es, line['en'], line['ar'], 'dialogue'))
        for word in lesson.get('vocabulary', []):
            example = word.get('example') or {}
            es = (example.get('es') or '').strip()
            if es and example.get('en') and example.get('ar'):
                self.sentences.append((es, example['en'], example['ar'], 'example'))
        reading = lesson.get('reading') or {}
        es = (reading.get('text_es') or '').strip()
        if es and reading.get('text_en') and reading.get('text_ar'):
            self.sentences.append((es, reading['text_en'], reading['text_ar'], 'reading'))
        # de-duplicate, keep the first occurrence
        seen = set()
        self.unique = []
        for item in self.sentences:
            key = norm(item[0])
            if key in seen:
                continue
            seen.add(key)
            self.unique.append(item)

    def with_audio(self):
        return [
            s for s in self.unique if os.path.isfile(os.path.join(AUDIO, audio_key(s[0])))
        ]


def shuffled_words(sentence, rng):
    words = [w for w in re.split(r'(\s+)', sentence) if w.strip()]
    if len(words) < 2:
        return words
    order = list(range(len(words)))
    for i in range(len(order) - 1, 0, -1):
        j = rng.randrange(i + 1)
        order[i], order[j] = order[j], order[i]
    if [words[i] for i in order] == words:
        order[0], order[1] = order[1], order[0]
    return [words[i] for i in order]


def mask_word(sentence, lesson_words):
    tokens = re.split(r'(\s+)', sentence)
    candidates = [
        i for i, t in enumerate(tokens) if len(t.strip()) >= 5 and t.strip().isalpha()
    ]
    if not candidates:
        return None
    index = candidates[len(candidates) // 2]
    word = tokens[index].strip().strip('.,!?;:¡¿"\'')
    if not word:
        return None
    tokens[index] = '___'
    return ' '.join(tokens), word


def build_exercises(lesson, pool, rng):
    """One exercise per type, each built from a different sentence."""
    audio_sentences = pool.with_audio()
    if len(audio_sentences) < 4:
        return []

    used_answers = {norm(e.get('answer', '')) for e in lesson.get('exercises', [])}
    free = [s for s in audio_sentences if norm(s[0]) not in used_answers]
    if len(free) < 4:
        return []

    lesson_words = [
        w['es'].strip()
        for w in lesson.get('vocabulary', [])
        if w.get('es') and len(w['es'].split()) <= 2
    ]
    out = []

    def prompt_tri(kind):
        p = PROMPTS[kind]
        return tri(p['es'], p['en'], p['ar'])

    def explanation(kind, sentence, word=''):
        es, en, ar = EXPLANATION[kind]
        return tri(
            es.format(sentence=sentence, word=word),
            en.format(sentence=sentence, word=word),
            ar.format(sentence=sentence, word=word),
        )

    # 1. listening - type what you hear
    es, en, ar, _ = free[0]
    out.append(
        {
            'type': 'listening',
            'prompt': prompt_tri('listening'),
            'options': [],
            'answer': es,
            'accepted': [],
            'audio': es,
            'explanation': explanation('listening', es),
            'gen': MARKER,
        }
    )

    # 2. dictation - same drill with a different sentence
    es, en, ar, _ = free[1]
    out.append(
        {
            'type': 'dictation',
            'prompt': prompt_tri('dictation'),
            'options': [],
            'answer': es,
            'accepted': [],
            'audio': es,
            'explanation': explanation('dictation', es),
            'gen': MARKER,
        }
    )

    # 3. listening_mcq - hear the clip, pick the sentence you heard
    target = free[2]
    distractors = [s for s in free[3:6]]
    if distractors:
        options = [target[0]] + [d[0] for d in distractors]
        rng.shuffle(options)
        out.append(
            {
                'type': 'listening_mcq',
                'prompt': prompt_tri('listening_mcq'),
                'options': [word_tri(o) for o in options],
                'answer': target[0],
                'accepted': [],
                'audio': target[0],
                'explanation': explanation('listening_mcq', target[0]),
                'gen': MARKER,
            }
        )

    # 4. sentence_reorder - rebuild the sentence from its words
    es, en, ar, _ = free[3]
    words = shuffled_words(es, rng)
    out.append(
        {
            'type': 'sentence_reorder',
            'prompt': prompt_tri('sentence_reorder'),
            'options': [word_tri(w) for w in words],
            'answer': es,
            'accepted': [],
            'explanation': explanation('sentence_reorder', es),
            'gen': MARKER,
        }
    )

    # 5. fill_blank - a cloze built from a long word, with lesson distractors
    for candidate in free[4:]:
        masked = mask_word(candidate[0], lesson_words)
        if not masked:
            continue
        cloze, word = masked
        wrong = [w for w in lesson_words if norm(w) != norm(word) and norm(w) != norm(cloze)]
        if len(wrong) < 2:
            break
        options = [word] + wrong[:3]
        rng.shuffle(options)
        out.append(
            {
                'type': 'fill_blank',
                'prompt': tri(cloze, cloze, cloze),
                'options': [word_tri(f"'{o}'") for o in options],
                'answer': f"'{word}'",
                'accepted': [],
                'explanation': explanation('fill_blank', cloze, word),
                'gen': MARKER,
            }
        )
        break

    return out


def main():
    parser = argparse.ArgumentParser()
    parser.add_argument('--dry-run', action='store_true')
    args = parser.parse_args()

    import random

    rng = random.Random(20260924)
    total_added = 0
    touched = 0

    for path in sorted(glob.glob(os.path.join(LEVELS, '*.json'))):
        with open(path, encoding='utf-8') as handle:
            source = handle.read()
        lesson = json.loads(source)
        if any(e.get('gen') == MARKER for e in lesson.get('exercises', [])):
            continue
        added = build_exercises(lesson, SentencePool(lesson), rng)
        if not added:
            continue
        # refuse to write if the round-trip is not byte-identical
        if json.dumps(lesson, ensure_ascii=False, indent=2) != source:
            sys.exit(f'round-trip mismatch, aborting before writing {path}')
        lesson['exercises'].extend(added)
        total_added += len(added)
        touched += 1
        if args.dry_run:
            print(f'{lesson["id"]}: would add {len(added)}')
        else:
            with open(path, 'w', encoding='utf-8') as handle:
                handle.write(json.dumps(lesson, ensure_ascii=False, indent=2))
    verb = 'would add' if args.dry_run else 'added'
    print(f'{verb} {total_added} exercises across {touched} lessons')


if __name__ == '__main__':
    main()
