#!/usr/bin/env python3
"""Extract all 'pt' strings from a content_<level>.py module into JSON.

Output: /tmp/opencode/es_translations/<level>.json
Format: list of {id, pt, en} — 'id' is a stable path used by apply_es.py.
"""
import importlib
import json
import os
import sys

LEVEL = sys.argv[1].upper()
OUT_DIR = "/tmp/opencode/es_translations"
os.makedirs(OUT_DIR, exist_ok=True)
os.sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))

mod = importlib.import_module(f"content_{LEVEL.lower()}")
lessons = mod.LESSONS

def walk(o, path):
    if isinstance(o, dict):
        for k, v in o.items():
            yield from walk(v, f"{path}/{k}")
    elif isinstance(o, list):
        for i, v in enumerate(o):
            yield from walk(v, f"{path}[{i}]")
    else:
        yield path, o

# Build list of all pt strings with their en sibling
items = []
paths = {}
def collect(o, path):
    if isinstance(o, dict):
        for k, v in o.items():
            if k == "pt" and isinstance(v, str):
                en = o.get("en", "")
                ar = o.get("ar", "")
                items.append({"id": f"{path}/pt", "pt": v, "en": en, "ar": ar})
            elif k == "text_pt" and isinstance(v, str):
                items.append({"id": f"{path}/text_pt", "pt": v, "en": o.get("text_en", ""), "ar": o.get("text_ar", "")})
            elif k == "speaker" and isinstance(v, str):
                items.append({"id": f"{path}/speaker", "pt": v, "en": "", "ar": ""})
            else:
                collect(v, f"{path}/{k}")
    elif isinstance(o, list):
        for i, v in enumerate(o):
            collect(v, f"{path}[{i}]")

for lid, lesson in sorted(lessons.items()):
    collect(lesson, lid)

# de-dup identical pt strings (keep first)
seen = {}
uniq = []
for it in items:
    key = it["pt"]
    if key in seen:
        seen[key].append(it["id"])
        continue
    seen[key] = []
    it["dups"] = []
    uniq.append(it)
for it in uniq:
    it["dups"] = seen[it["pt"]]

out = os.path.join(OUT_DIR, f"{LEVEL.lower()}.json")
with open(out, "w", encoding="utf-8") as f:
    json.dump(uniq, f, ensure_ascii=False, indent=1)
print(f"{LEVEL}: {len(uniq)} unique pt strings -> {out}")