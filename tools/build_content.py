#!/usr/bin/env python3
"""Build course content JSONs for a given level.

Each level has a data module (content_<level>.py) providing a LESSONS list.
This script merges the map + content and writes per-lesson JSON files.

Usage: python3 build_content.py A1
"""
import importlib
import json
import os
import sys

ROOT = os.path.dirname(os.path.abspath(__file__))
MAP_PATH = os.path.join(ROOT, "course_map.json")
OUT_DIR = os.path.join(ROOT, "..", "app", "assets", "course", "levels")


def load_map():
    with open(MAP_PATH, encoding="utf-8") as f:
        return json.load(f)


def main():
    level_id = sys.argv[1].upper() if len(sys.argv) > 1 else "A1"
    course_map = load_map()
    level = next(l for l in course_map["levels"] if l["id"] == level_id)
    mod = importlib.import_module(f"content_{level_id.lower()}")

    os.makedirs(OUT_DIR, exist_ok=True)
    for lesson_meta in level["lessons"]:
        lid = lesson_meta["id"]
        content = mod.LESSONS.get(lid)
        if content is None:
            print(f"  WARN: no content for {lid}, skipping")
            continue
        lesson = {
            "id": lid,
            "level": level_id,
            "level_name": {
                "es": level["name_es"],
                "en": level["name_en"],
                "ar": level["name_ar"],
            },
            "title": {
                "es": lesson_meta["title_es"],
                "en": lesson_meta["title_en"],
                "ar": lesson_meta["title_ar"],
            },
            "objectives": content["objectives"],
            "vocabulary": content["vocabulary"],
            "grammar": content["grammar"],
            "dialogue": content.get("dialogue"),
            "reading": content.get("reading"),
            "exercises": content.get("exercises", []),
        }
        path = os.path.join(OUT_DIR, f"{lid}.json")
        with open(path, "w", encoding="utf-8") as f:
            json.dump(lesson, f, ensure_ascii=False, indent=2)
        print(f"  wrote {lid} ({len(lesson['vocabulary'])} words)")

    # Rebuild full index.json in canonical map order (all levels).
    index = {"levels": {}}
    for lv in course_map["levels"]:
        index["levels"][lv["id"]] = {
            "name_es": lv["name_es"],
            "name_en": lv["name_en"],
            "name_ar": lv["name_ar"],
            "description_es": lv["description_es"],
            "description_en": lv["description_en"],
            "description_ar": lv["description_ar"],
            "lessons": [
                {"id": m["id"], "title": {
                    "es": m["title_es"], "en": m["title_en"], "ar": m["title_ar"],
                }} for m in lv["lessons"]
            ],
        }
    index_path = os.path.join(OUT_DIR, "index.json")
    with open(index_path, "w", encoding="utf-8") as f:
        json.dump(index, f, ensure_ascii=False, indent=2)
    print(f"Level {level_id}: done. Index at {index_path}")


if __name__ == "__main__":
    main()
