# Legacy content generators — do not run

These scripts are kept only as a record of how the original course data was
produced. **Running any of them will damage the current lesson JSON.**

| Script | Why it is retired |
|--------|-------------------|
| `build_content.py`, `augment_content.py` | Rewrite every lesson file in place and regenerate exercise types without stable markers. The Portuguese course is baked into them, so the Spanish lessons would be overwritten with Portuguese content. `build_content.py` also drops the `speaking` and `cultural_tips` sections. |
| `apply_es.py` | Its "missing translation" test is inverted: it appends to `MISSING` when a value *is* found. |
| `content_a1.py`, `content_a1_full.py`, `content_a1_rest.py`, `content_a2.py`, `content_b1.py`, `content_b2.py`, `content_c1.py`, `content_c2.py` | Large hardcoded lesson payloads that still contain the Portuguese course. |
| `course_map.json` | Snapshot of the course map as it was when those scripts ran. |

## What to use instead

- `app/tools/lint_audio_keys.py <levels dir> <pt|es>` — read-only audio key check.
- `app/tools/audit_duplicate_exercises.py <pt|es>` — read-only duplicate report.
- `app/tools/generate_es_exercises.py --dry-run` — idempotent (marker based), ES only.
- `tools/build_index.py` — regenerates `app/assets/course/index.json`, now byte-reproducible.

If new content is needed, edit the lesson JSON directly. Two invariants:

1. `json.dumps(obj, ensure_ascii=False, indent=2)` with **no trailing newline**.
2. Never delete or reorder entries in an `exercises` array: user progress is keyed
   `${lessonId}::${index}`. Change content in place, or hide duplicates at render time.
