#!/usr/bin/env python3
"""Build a single assets/course/index.json for fast in-app searching.

The index aggregates vocab, grammar titles, dialogue lines, and lesson
titles across all lessons so Search/Flashcards/GrammarHub can load one
small file instead of 72 JSONs. The lesson text still comes from the
per-lesson JSONs on demand.

Usage: python3 build_index.py [course_dir] [out_path]
"""
import json
import os
import sys

ROOT = os.path.dirname(os.path.abspath(__file__))
COURSE_DIR = sys.argv[1] if len(sys.argv) > 1 else os.path.join(
    ROOT, "..", "app", "assets", "course", "levels")
OUT = sys.argv[2] if len(sys.argv) > 2 else os.path.join(
    ROOT, "..", "app", "assets", "course", "index.json")


def main():
    files = sorted(
        f for f in os.listdir(COURSE_DIR)
        if f.endswith(".json") and f != "index.json"
    )
    lessons = []
    vocab = []
    grammar = []
    dialogue = []
    reading_list = []
    for f in files:
        with open(os.path.join(COURSE_DIR, f), encoding="utf-8") as fh:
            lesson = json.load(fh)
        lid = lesson["id"]
        lessons.append({
            "id": lid,
            "level": lesson.get("level", ""),
            "title": lesson.get("title", {}),
        })
        for i, v in enumerate(lesson.get("vocabulary", [])):
            vocab.append({
                "lesson": lid,
                "index": i,
                "es": v.get("es", ""),
                "en": v.get("en", ""),
                "ar": v.get("ar", ""),
                "ipa": v.get("ipa", ""),
                "example": v.get("example", {}),
            })
        for g in lesson.get("grammar", []):
            grammar.append({
                "lesson": lid,
                "title": g.get("title", {}),
                "explanation": g.get("explanation", {}),
                "examples": g.get("examples", []),
            })
        for line in lesson.get("dialogue", {}).get("lines", []):
            dialogue.append({
                "lesson": lid,
                "es": line.get("es", ""),
                "en": line.get("en", ""),
                "ar": line.get("ar", ""),
            })
        reading = lesson.get("reading", {})
        reading_list.append({
            "lesson": lid,
            "text": {
                "es": reading.get("text_es", ""),
                "en": reading.get("text_en", ""),
                "ar": reading.get("text_ar", ""),
            },
        })

    data = {
        "generated": __import__("datetime").datetime.now().isoformat(),
        "lessons": lessons,
        "vocab": vocab,
        "grammar": grammar,
        "dialogue": dialogue,
        "reading": reading_list,
    }
    os.makedirs(os.path.dirname(OUT), exist_ok=True)
    with open(OUT, "w", encoding="utf-8") as fh:
        json.dump(data, fh, ensure_ascii=False, separators=(",", ":"))
    print(f"Index: {len(lessons)} lessons, {len(vocab)} vocab, "
          f"{len(grammar)} grammar, {len(dialogue)} dialogue lines, "
          f"{len(reading_list)} reading texts -> {OUT}")


if __name__ == "__main__":
    main()