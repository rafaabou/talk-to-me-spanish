#!/usr/bin/env python3
"""Schema for the PT-BR Zero-to-Hero course content.

Lesson JSON structure:
{
  "id": "A1-01",
  "level": "A1",
  "title": {"pt": "...", "en": "...", "ar": "..."},
  "objectives": [{"pt": "...", "en": "...", "ar": "..."}],
  "vocabulary": [
    {"pt": "...", "ipa": "...", "en": "...", "ar": "...",
     "example": {"pt": "...", "en": "...", "ar": "..."}}  # optional usage sentence
  ],
  "grammar": [
    {"title": {"pt": "...", "en": "...", "ar": "..."},
     "explanation": {"pt": "...", "en": "...", "ar": "..."},
     "examples": [{"pt": "...", "en": "...", "ar": "...", "audio_pt": "..."}]}
  ],
  "dialogue": {
    "title": {"pt": "...", "en": "...", "ar": "..."},
    "lines": [{"speaker": "...", "pt": "...", "en": "...", "ar": "...", "audio_pt": "..."}]
  },
  "reading": {
    "title": {"pt": "...", "en": "...", "ar": "..."},
    "text_pt": "...", "text_en": "...", "text_ar": "...",
    "audio_pt": "..."
  },
  "exercises": [
    {"type": "multiple_choice"|"fill_blank"|"translation"|"writing"|"listening"|"dictation",
     "prompt": {"pt": "...", "en": "...", "ar": "..."},
     "options": [{"pt": "...", "en": "...", "ar": "..."}],  # for multiple_choice/fill_blank/listening
     "answer": "...",
     "accepted": ["...", "..."],   # optional accepted variants for writing/translation
     "audio": "...",               # PT text to play for listening/dictation exercises
     "explanation": {"pt": "...", "en": "...", "ar": "..."}}
  ],
  "speaking": {
    "title": {"pt": "...", "en": "...", "ar": "..."},
    "phrases": [{"pt": "...", "en": "...", "ar": "..."}]
  }
}
"""
import json
import os
import sys

SCHEMA_VERSION = "1.0"


def empty_lesson(lesson_id, title_pt, title_en, title_ar):
    return {
        "schema_version": SCHEMA_VERSION,
        "id": lesson_id,
        "level": lesson_id.split("-")[0],
        "title": {"pt": title_pt, "en": title_en, "ar": title_ar},
        "objectives": [],
        "vocabulary": [],
        "grammar": [],
        "dialogue": {
            "title": {"pt": "", "en": "", "ar": ""},
            "lines": []
        },
        "reading": {
            "title": {"pt": "", "en": "", "ar": ""},
            "text_pt": "", "text_en": "", "text_ar": "",
            "audio_pt": None
        },
        "exercises": []
    }


def save_lesson(lesson, out_dir):
    os.makedirs(out_dir, exist_ok=True)
    path = os.path.join(out_dir, f"{lesson['id']}.json")
    with open(path, "w", encoding="utf-8") as f:
        json.dump(lesson, f, ensure_ascii=False, indent=2)
    return path


if __name__ == "__main__":
    print("Schema module loaded. Use build_content.py to generate course content.")
