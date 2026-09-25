#!/usr/bin/env python3
"""Augment lesson JSONs with Writing / Listening / Fill-blank exercises
and a Speaking (listen-and-repeat) section, derived from existing content.

Reads every lesson JSON in the course assets dir, adds the new sections
in place, and prints a coverage audit including missing-audio checks.

Usage: python3 augment_content.py [course_dir] [audio_dir]
"""
import hashlib
import json
import os
import random
import sys

ROOT = os.path.dirname(os.path.abspath(__file__))
COURSE_DIR = sys.argv[1] if len(sys.argv) > 1 else os.path.join(
    ROOT, "..", "app", "assets", "course", "levels")
AUDIO_DIR = sys.argv[2] if len(sys.argv) > 2 else os.path.join(
    ROOT, "..", "app", "assets", "audio")


def audio_key(text, lang):
    h = hashlib.md5(f"{lang}:{text}".encode("utf-8")).hexdigest()[:12]
    return f"{lang}_{h}.opus"


def audio_ok(text, lang):
    return os.path.exists(os.path.join(AUDIO_DIR, audio_key(text, lang)))


def tt(pt, en, ar):
    return {"pt": pt, "en": en, "ar": ar}


def writing_from_vocab(vocab, count=2):
    """EN -> PT typing exercises derived from vocabulary."""
    out = []
    pool = [v for v in vocab if v.get("pt") and v.get("en")]
    if len(pool) < count:
        count = len(pool)
    for i, v in enumerate(pool[:count]):
        answer = v["pt"]
        en = v.get("en", answer)
        ar = v.get("ar", en)
        out.append({
            "type": "writing",
            "prompt": {
                "pt": f"Escreva em português: '{en}'",
                "en": f"Type in Portuguese: '{en}'",
                "ar": f"اكتب بالبرتغالية: '{ar}'",
            },
            "options": [],
            "answer": answer,
            "accepted": [answer],
            "explanation": {
                "pt": f"'{answer}' significa '{en}'.",
                "en": f"'{answer}' means '{en}'.",
                "ar": f"'${answer}' بالعربية: '${ar}'.",
            },
        })
    return out


def listening_from_dialogue(lines, count=2):
    """Play a dialogue line, pick what you heard (MCQ)."""
    out = []
    if len(lines) < 3:
        return out
    picked = lines[:count] if len(lines) >= count else lines
    for line in picked:
        correct = line["pt"]
        others = [l["pt"] for l in lines if l["pt"] != correct]
        random.shuffle(others)
        distractors = others[:2]
        options = [correct] + distractors
        random.shuffle(options)
        out.append({
            "type": "listening",
            "prompt": {
                "pt": "O que você ouviu?",
                "en": "What did you hear?",
                "ar": "ماذا سمعت؟",
            },
            "options": [tt(o, o, o) for o in options],
            "answer": correct,
            "accepted": [],
            "audio": correct,
            "explanation": {
                "pt": f"Você ouviu: '{correct}'",
                "en": f"You heard: '{correct}'",
                "ar": f"سمعت: '{correct}'",
            },
        })
    return out


def dictation_from_dialogue(lines, count=1):
    """Listen to a dialogue line and type it (listening + writing)."""
    out = []
    if len(lines) < 3:
        return out
    picked = lines[:count] if len(lines) >= count else lines
    for line in picked:
        correct = line["pt"]
        out.append({
            "type": "dictation",
            "prompt": {
                "pt": "Ouça e escreva o que você ouviu.",
                "en": "Listen and type what you hear.",
                "ar": "استمع واكتب ما سمعته.",
            },
            "options": [],
            "answer": correct,
            "accepted": [],
            "audio": correct,
            "explanation": {
                "pt": f"A frase correta: '{correct}'",
                "en": f"The correct sentence: '{correct}'",
                "ar": f"الجملة الصحيحة: '{correct}'",
            },
        })
    return out


def sentence_reorder_from_dialogue(lines, count=1):
    """Reorder scrambled words from a dialogue line."""
    out = []
    if len(lines) < 3:
        return out
    picked = lines[:count] if len(lines) >= count else lines
    for line in picked:
        correct = line["pt"]
        words = correct.split()
        if len(words) < 4:
            continue
        scrambled = words.copy()
        random.shuffle(scrambled)
        # ensure it's actually scrambled
        if scrambled == words:
            random.shuffle(scrambled)
        en = line.get("en", correct)
        ar = line.get("ar", correct)
        out.append({
            "type": "sentence_reorder",
            "prompt": {
                "pt": "Reordene as palavras para formar a frase:",
                "en": "Reorder the words to form the sentence:",
                "ar": "أعد ترتيب الكلمات لتكوين الجملة:",
            },
            "options": [tt(w, w, w) for w in scrambled],  # scrambled words as options
            "answer": correct,
            "accepted": [correct],
            "explanation": {
                "pt": f"A ordem correta: '{correct}'",
                "en": f"The correct order: '{en}'",
                "ar": f"الترتيب الصحيح: '{ar}'",
            },
        })
    return out


def match_pairs_from_vocab(vocab, count=6):
    """Match PT↔EN pairs from vocabulary (6 pairs per exercise)."""
    out = []
    pool = [(v["pt"], v.get("en", ""), v.get("ar", "")) for v in vocab if v.get("pt") and v.get("en")]
    if len(pool) < 6:
        return out
    # Create one exercise with 6 pairs
    selected = pool[:count]
    random.shuffle(selected)
    pairs = [(p[0], p[1]) for p in selected]  # list of (pt, en)
    pt_list = [p[0] for p in pairs]
    en_list = [p[1] for p in pairs]
    random.shuffle(en_list)
    out.append({
        "type": "match_pairs",
        "prompt": {
            "pt": "Associe cada palavra em português ao seu significado em inglês:",
            "en": "Match each Portuguese word to its English meaning:",
            "ar": "قم بمطابقة كل كلمة برتغالية مع معناها بالإنجليزية:",
        },
        "options": [tt(pt, en, pt) for pt, en in zip(pt_list, en_list)],  # PT on left, shuffled EN on right
        "answer": "|".join([f"{pt}::{en}" for pt, en in zip(pt_list, en_list)]),
        "accepted": [],
        "explanation": {
            "pt": "Associe corretamente os pares.",
            "en": "Match the pairs correctly.",
            "ar": "قم بمطابقة الأزواج بشكل صحيح.",
        },
    })
    return out


def listening_mcq_from_dialogue(lines, count=2):
    """Play a dialogue line audio, pick the translation (MCQ)."""
    out = []
    if len(lines) < 3:
        return out
    picked = lines[:count] if len(lines) >= count else lines
    for line in picked:
        correct_pt = line["pt"]
        correct_en = line.get("en", correct_pt)
        correct_ar = line.get("ar", correct_pt)
        others = [l for l in lines if l["pt"] != correct_pt]
        random.shuffle(others)
        distractors = others[:2]
        options_pt = [correct_pt] + [d["pt"] for d in distractors]
        options_en = [correct_en] + [d.get("en", d["pt"]) for d in distractors]
        options_ar = [correct_ar] + [d.get("ar", d["pt"]) for d in distractors]
        random.shuffle(options_pt)
        random.shuffle(options_en)
        random.shuffle(options_ar)
        out.append({
            "type": "listening_mcq",
            "prompt": {
                "pt": "Ouça e escolha a tradução correta:",
                "en": "Listen and choose the correct translation:",
                "ar": "استمع واختر الترجمة الصحيحة:",
            },
            "options": [tt(o, e, a) for o, e, a in zip(options_pt, options_en, options_ar)],
            "answer": correct_pt,
            "accepted": [],
            "audio": correct_pt,
            "explanation": {
                "pt": f"Você ouviu: '{correct_pt}' — '{correct_en}'",
                "en": f"You heard: '{correct_pt}' — '{correct_en}'",
                "ar": f"سمعت: '{correct_pt}' — '{correct_ar}'",
            },
        })
    return out


def _is_alphabet_line(text):
    """Check if a line is an alphabet enumeration like 'A, B, C, D, E...'."""
    tokens = [t.strip(".,!?;:") for t in text.split()]
    if len(tokens) < 3:
        return False
    letter_count = sum(1 for t in tokens if len(t) == 1 and t.isalpha())
    return letter_count >= len(tokens) * 0.7


def example_sentences(vocab, dialogue_lines, grammar):
    """Pick a usage sentence for each vocab word from dialogue/grammar examples."""
    pool = []
    for line in dialogue_lines:
        if _is_alphabet_line(line["pt"]):
            continue
        pool.append((line["pt"], line["en"], line["ar"]))
    for g in grammar:
        for ex in g.get("examples", []):
            pt = ex.get("pt", "")
            if any(c in pt for c in "→←=*|—:"):
                continue
            pool.append((pt, ex.get("en", ""), ex.get("ar", "")))
    if not pool:
        return vocab
    for v in vocab:
        pt = v.get("pt", "")
        if not pt:
            continue
        base = pt.split()[0].lower()
        found = None
        for spt, sen, sar in pool:
            low = spt.lower()
            if any(token.strip(".,!?;:") == base for token in low.split()):
                found = (spt, sen, sar)
                break
        if found is None:
            found = pool[0] if pool else ("", "", "")
        v["example"] = {
            "pt": found[0], "en": found[1], "ar": found[2],
        }
    return vocab


def fill_blank_from_grammar(grammar, count=1):
    """Fill-the-blank MCQ from grammar example sentences."""
    out = []
    for g in grammar:
        for ex in g.get("examples", []):
            if len(out) >= count:
                break
            pt = ex.get("pt", "")
            words = pt.split()
            if len(words) < 4:
                continue
            # skip chart-like examples with symbols (arrows, equals, etc.)
            if any(c in pt for c in "→←=*|—:"):
                continue
            if any(any(sym in w for sym in "→←=*|") for w in words):
                continue
            # pick a content word to blank (not the first)
            idx = min(1 + random.randrange(len(words) - 2), len(words) - 1)
            target = words[idx]
            stem = words[:idx] + ["___"] + words[idx + 1:]
            prompt_pt = " ".join(stem)
            en = ex.get("en", pt)
            ar = ex.get("ar", pt)
            # distractors from other examples in same grammar section
            others = [
                e.get("pt", "").split() for e in g.get("examples", [])
                if e.get("pt") != pt
            ]
            flat = [w for wl in others for w in wl]
            random.shuffle(flat)
            flat = [w for w in flat if w.isalpha()]
            distractors = [w for w in flat if w.lower() != target.lower()][:2]
            options = [target] + distractors
            random.shuffle(options)
            out.append({
                "type": "fill_blank",
                "prompt": {
                    "pt": prompt_pt,
                    "en": prompt_pt,
                    "ar": prompt_pt,
                },
                "options": [tt(o, o, o) for o in options],
                "answer": target,
                "accepted": [],
                "explanation": {
                    "pt": f"A resposta é '{target}'. Frase completa: {pt}",
                    "en": f"The answer is '{target}'. Full sentence: {en}",
                    "ar": f"الإجابة الصحيحة: '{target}'. الجملة كاملة: {ar}",
                },
            })
        if len(out) >= count:
            break
    return out


def speaking_from_content(dialogue_lines, vocab):
    """Speaking phrases: dialogue lines + key vocabulary."""
    phrases = []
    for line in dialogue_lines:
        phrases.append({
            "pt": line["pt"],
            "en": line["en"],
            "ar": line["ar"],
        })
    key = vocab[:3] if len(vocab) >= 3 else vocab
    for v in key:
        phrases.append({
            "pt": v["pt"],
            "en": v.get("en", ""),
            "ar": v.get("ar", ""),
        })
    return phrases


def main():
    files = sorted(
        f for f in os.listdir(COURSE_DIR)
        if f.endswith(".json") and f != "index.json"
    )
    total = {
        "writing": 0, "listening": 0, "fill_blank": 0, "dictation": 0,
        "speaking": 0, "sentence_reorder": 0, "match_pairs": 0, "listening_mcq": 0,
        "missing_audio": [], "vocab_no_example": 0,
    }
    for f in files:
        path = os.path.join(COURSE_DIR, f)
        with open(path, encoding="utf-8") as fh:
            lesson = json.load(fh)

        vocab = lesson.get("vocabulary", [])
        grammar = lesson.get("grammar", [])
        dialogue = lesson.get("dialogue", {}).get("lines", [])

        exercises = lesson.get("exercises", [])
        # drop any previously auto-augmented exercise types to stay idempotent
        # NOTE: we keep fill_blank to preserve manually added ones
        exercises = [
            e for e in exercises if e.get("type") not in
            ("writing", "listening", "dictation")
        ]

        writing = writing_from_vocab(vocab)
        listening = listening_from_dialogue(dialogue)
        has_fill_blank = any(e.get("type") == "fill_blank" for e in exercises)
        fill_blank = fill_blank_from_grammar(grammar) if not has_fill_blank else []
        dictation = dictation_from_dialogue(dialogue)
        sentence_reorder = sentence_reorder_from_dialogue(dialogue)
        match_pairs = match_pairs_from_vocab(vocab)
        listening_mcq = listening_mcq_from_dialogue(dialogue)
        vocab = example_sentences(vocab, dialogue, grammar)
        lesson["vocabulary"] = vocab

        exercises.extend(writing)
        exercises.extend(listening)
        exercises.extend(fill_blank)
        exercises.extend(dictation)
        exercises.extend(sentence_reorder)
        exercises.extend(match_pairs)
        exercises.extend(listening_mcq)
        lesson["exercises"] = exercises

        phrases = speaking_from_content(dialogue, vocab)
        lesson["speaking"] = {
            "title": {
                "pt": "Fale Agora — Ouça e Repita",
                "en": "Speak Now — Listen and Repeat",
                "ar": "تحدث الآن — استمع وكرر",
            },
            "phrases": phrases,
        }

        with open(path, "w", encoding="utf-8") as fh:
            json.dump(lesson, fh, ensure_ascii=False, indent=2)

        total["writing"] += len(writing)
        total["listening"] += len(listening)
        total["fill_blank"] += len(fill_blank)
        total["dictation"] += len(dictation)
        total["sentence_reorder"] += len(sentence_reorder)
        total["match_pairs"] += len(match_pairs)
        total["listening_mcq"] += len(listening_mcq)
        total["speaking"] += len(phrases)
        total["vocab_no_example"] += sum(
            1 for v in vocab if not v.get("example", {}).get("pt"))

        # audio audit for all new content + existing
        for e in writing + listening + dictation:
            txt = e.get("audio") or e.get("answer", "")
            if txt and not audio_ok(txt, "pt"):
                total["missing_audio"].append(f"{lesson['id']}: {txt[:40]}")
        for p in phrases:
            if p["pt"] and not audio_ok(p["pt"], "pt"):
                total["missing_audio"].append(f"{lesson['id']} speak: {p['pt'][:40]}")

    print(f"Lessons augmented: {len(files)}")
    print(f"  writing:         {total['writing']}")
    print(f"  listening:       {total['listening']}")
    print(f"  fill_blank:      {total['fill_blank']}")
    print(f"  dictation:       {total['dictation']}")
    print(f"  sentence_reorder: {total['sentence_reorder']}")
    print(f"  match_pairs:     {total['match_pairs']}")
    print(f"  listening_mcq:   {total['listening_mcq']}")
    print(f"  speaking phrases: {total['speaking']}")
    print(f"  vocab w/o example: {total['vocab_no_example']}")
    print(f"  missing audio: {len(total['missing_audio'])}")
    for m in total["missing_audio"][:20]:
        print(f"    MISSING: {m}")


if __name__ == "__main__":
    main()
