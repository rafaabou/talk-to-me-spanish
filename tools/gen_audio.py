#!/usr/bin/env python3
"""Generate small Opus audio clips for the course using edge-tts.

Usage: python3 gen_audio.py <course_dir> <audio_out_dir>
Reads all lesson JSONs, generates audio for every marked text item.
Skips items already generated (cache in audio_out_dir).
"""
import asyncio
import json
import os
import subprocess
import sys
import hashlib

VOICES = {
    "es": "es-UY-ValentinaNeural",
    "en": "en-US-JennyNeural",
    "ar": "ar-EG-SalmaNeural",
}


def audio_key(text, lang):
    h = hashlib.md5(f"{lang}:{text}".encode("utf-8")).hexdigest()[:12]
    return f"{lang}_{h}.opus"


def text_items(lesson):
    items = []

    for i, v in enumerate(lesson.get("vocabulary", [])):
        es = v.get("es", "")
        if es:
            items.append((f"vocab-{i}-es", es, "es"))

    for gi, g in enumerate(lesson.get("grammar", [])):
        # Grammar explanation audio
        expl = g.get("explanation", {}).get("es", "")
        if expl:
            items.append((f"grammar-{gi}-expl", expl, "es"))
        for ei, ex in enumerate(g.get("examples", [])):
            es = ex.get("es", "")
            if es:
                items.append((f"grammar-{gi}-ex-{ei}", es, "es"))

    for li, line in enumerate(lesson.get("dialogue", {}).get("lines", [])):
        es = line.get("es", "")
        if es:
            items.append((f"dialogue-{li}-es", es, "es"))

    reading = lesson.get("reading", {})
    if reading.get("text_es"):
        items.append(("reading-es", reading["text_es"], "es"))

    for ei, e in enumerate(lesson.get("exercises", [])):
        answer = e.get("answer", "").split("/")[0].strip()
        if answer:
            items.append((f"exercise-{ei}-answer", answer, "es"))
        audio = e.get("audio")
        if audio:
            items.append((f"exercise-{ei}-audio", audio, "es"))

    return items


def verb_items(verbs_file):
    """Extract unique conjugated verb forms from verbs.json."""
    with open(verbs_file, encoding="utf-8") as fh:
        data = json.load(fh)
    forms = set()
    for v in data.get("verbs", []):
        for tense_name, tense_list in v.items():
            if isinstance(tense_list, list):
                for form in tense_list:
                    if form and isinstance(form, str):
                        forms.add(form)
    items = []
    for i, form in enumerate(sorted(forms)):
        items.append((f"verb-{i}", form, "es"))
    return items


def opus_from_mp3(mp3_path, out_path):
    subprocess.run(
        ["ffmpeg", "-y", "-i", mp3_path, "-c:a", "libopus", "-b:a", "16k",
         "-ac", "1", "-ar", "16000", out_path],
        capture_output=True,
    )


async def synth(edge, text, lang, mp3_path):
    from edge_tts import Communicate
    communicator = Communicate(text, VOICES[lang])
    await communicator.save(mp3_path)
    return mp3_path


async def main():
    course_dir = sys.argv[1]
    audio_out = sys.argv[2]
    os.makedirs(audio_out, exist_ok=True)

    lesson_files = sorted(
        f for f in os.listdir(course_dir)
        if f.endswith(".json") and f != "index.json"
    )

    pending = []
    for f in lesson_files:
        with open(os.path.join(course_dir, f), encoding="utf-8") as fh:
            lesson = json.load(fh)
        for label, text, lang in text_items(lesson):
            key = audio_key(text, lang)
            target = os.path.join(audio_out, key)
            if not os.path.exists(target):
                pending.append((f, label, text, lang, key, target))

    # Process verb forms
    verbs_file = os.path.join(os.path.dirname(course_dir), "verbs.json")
    if os.path.exists(verbs_file):
        for label, text, lang in verb_items(verbs_file):
            key = audio_key(text, lang)
            target = os.path.join(audio_out, key)
            if not os.path.exists(target):
                pending.append((verbs_file, label, text, lang, key, target))

    print(f"Lessons: {len(lesson_files)}  Audio items to generate: {len(pending)}")

    import edge_tts
    failed = 0
    import tempfile
    tmpdir = tempfile.mkdtemp(prefix="esaudio_")
    for i, (f, label, text, lang, key, target) in enumerate(pending):
        mp3_tmp = os.path.join(tmpdir, f"{key}.mp3")
        ok = False
        for attempt in range(3):
            try:
                await synth(edge_tts, text, lang, mp3_tmp)
                opus_from_mp3(mp3_tmp, target)
                os.remove(mp3_tmp)
                ok = True
                break
            except Exception as exc:
                if os.path.exists(mp3_tmp):
                    os.remove(mp3_tmp)
                if attempt == 2:
                    print(f"  FAILED ({exc.__class__.__name__}) {f} {label}: {text[:50]}")
                    failed += 1
                else:
                    await asyncio.sleep(1.0)
        if (i + 1) % 25 == 0:
            print(f"  {i+1}/{len(pending)} processed")
    print(f"Done generating audio. Failures: {failed}")


if __name__ == "__main__":
    asyncio.run(main())
