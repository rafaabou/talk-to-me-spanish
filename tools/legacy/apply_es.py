#!/usr/bin/env python3
"""Apply Spanish translations to a content_<level>.py module.

Loads the (Portuguese) content module, renames every 'pt' key to 'es'
and replaces its value with the Spanish translation from
/tmp/opencode/es_translations/<level>.json, then overwrites the module.

Usage: python3 apply_es.py A1
"""
import importlib
import json
import os
import sys

LEVEL = sys.argv[1].upper()
HERE = os.path.dirname(os.path.abspath(__file__))
sys.path.insert(0, HERE)

BASE = f"/tmp/opencode/es_translations/{LEVEL.lower()}"
MAPF = f"{BASE}_map.json"
if os.path.exists(MAPF):
    with open(MAPF, encoding="utf-8") as f:
        LOOKUP = json.load(f)
else:
    with open(f"{BASE}.json", encoding="utf-8") as f:
        trans = json.load(f)
    LOOKUP = {t["pt"]: t.get("es", "") for t in trans}
MISSING = []

mod = importlib.import_module(f"content_{LEVEL.lower()}")
lessons = mod.LESSONS


def translate(o):
    if isinstance(o, dict):
        out = {}
        for k, v in o.items():
            if k == "pt":
                if v in LOOKUP and LOOKUP[v]:
                    out["es"] = LOOKUP[v]
                else:
                    MISSING.append(str(v))
                    out["es"] = v
            elif k in ("text_pt", "text_es") and isinstance(v, str):
                out["text_es"] = LOOKUP.get(v, v)
                if k == "text_pt" and v not in LOOKUP:
                    MISSING.append(str(v))
            elif k == "speaker" and isinstance(v, str):
                out["speaker"] = LOOKUP.get(v, v)
                if v not in LOOKUP:
                    MISSING.append(str(v))
            elif k == "answer" and isinstance(v, str):
                if v in LOOKUP and LOOKUP[v]:
                    out["answer"] = LOOKUP[v]
                else:
                    MISSING.append(str(v))
                    out["answer"] = v
            elif k in ("es",) and isinstance(v, str):
                out["es"] = LOOKUP.get(v, v)
                if v in LOOKUP:
                    MISSING.append(str(v))
            else:
                out[k] = translate(v)
        return out
    if isinstance(o, list):
        return [translate(v) for v in o]
    return o


new_lessons = {lid: translate(lesson) for lid, lesson in sorted(lessons.items())}

with open(os.path.join(HERE, f"content_{LEVEL.lower()}.py"), "w", encoding="utf-8") as f:
    f.write("# -*- coding: utf-8 -*-\n")
    f.write("LESSONS = ")
    f.write(json.dumps(new_lessons, ensure_ascii=False, indent=1))
    f.write("\n")

print(f"{LEVEL}: wrote content_{LEVEL.lower()}.py")
if MISSING:
    print(f"  MISSING translations ({len(MISSING)}):")
    for m in sorted(set(MISSING))[:20]:
        print("   -", m)