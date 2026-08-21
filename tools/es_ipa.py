#!/usr/bin/env python3
"""Rule-based Spanish (Latin American) IPA transcriber.

Produces phonemic IPA for Spanish words, marking stress with /ˈ/.
Uses seseo (z/ce/ci -> /s/), yeismo (ll/y -> /ʝ/), and approximant
allophones for intervocalic b/d/g (the standard phonemic treatment).
"""
import re


def vowel_ipa(c):
    base = c
    if base == "á":
        return "a"
    if base == "é":
        return "e"
    if base == "í":
        return "i"
    if base == "ó":
        return "o"
    if base == "ú":
        return "u"
    if base == "ü":
        return "w"
    return {"a": "a", "e": "e", "i": "i", "o": "o", "u": "u"}.get(base, base)


def is_vowel(c):
    return c in "aeiouáéíóúü"


def find_nuclei(chars):
    """Return list of (start,end) indices of vowel-group nuclei."""
    nuclei = []
    i = 0
    n = len(chars)
    while i < n:
        if is_vowel(chars[i]):
            j = i
            while j < n and is_vowel(chars[j]):
                j += 1
            nuclei.append((i, j))
            i = j
        else:
            i += 1
    return nuclei


def find_stress_index(nuclei, chars):
    """Return index of stressed nucleus (0-based)."""
    if len(nuclei) <= 1:
        return 0
    for idx, (s, e) in enumerate(nuclei):
        if any(c in "áéíóú" for c in chars[s:e]):
            return idx
    last = nuclei[-1]
    last_c = chars[-1]
    if last_c in "nsaeiou":
        return len(nuclei) - 2
    return len(nuclei) - 1


def consonant_seg(chars, i):
    """Return (ipa, consumed) for consonant cluster starting at i."""
    n = len(chars)
    two = "".join(chars[i:i + 2])
    if two == "ch":
        return "tʃ", 2
    if two == "ll":
        return "ʝ", 2
    if two == "rr":
        return "r", 2
    if two == "gu" and i + 2 < n and chars[i + 2] in "eií":
        return "g", 2
    if two == "qu":
        return "k", 2
    c = chars[i]
    if c == "b" or c == "v":
        prev_v = i > 0 and is_vowel(chars[i - 1])
        return ("β" if prev_v else "b"), 1
    if c == "c":
        if i + 1 < n and chars[i + 1] in "ei":
            return "s", 1
        if i + 1 < n and chars[i + 1] == "h":
            return "tʃ", 2
        return "k", 1
    if c == "d":
        prev_v = i > 0 and is_vowel(chars[i - 1])
        prev_nl = i > 0 and chars[i - 1] in "nl"
        return ("ð" if prev_v and not prev_nl else "d"), 1
    if c == "g":
        if i + 1 < n and chars[i + 1] in "ei":
            return "x", 1
        prev_v = i > 0 and is_vowel(chars[i - 1])
        return ("ɣ" if prev_v else "g"), 1
    if c == "h":
        return "", 1
    if c == "j":
        return "x", 1
    if c == "k":
        return "k", 1
    if c == "l":
        return "l", 1
    if c == "m":
        return "m", 1
    if c == "n":
        return "n", 1
    if c == "ñ":
        return "ɲ", 1
    if c == "p":
        return "p", 1
    if c == "r":
        prev = chars[i - 1] if i > 0 else ""
        if i == 0 or prev in "nls":
            return "r", 1
        return "ɾ", 1
    if c == "s":
        return "s", 1
    if c == "t":
        return "t", 1
    if c == "x":
        return "ks", 1
    if c == "y":
        return "ʝ", 1
    if c == "z":
        return "s", 1
    if c == "w":
        return "w", 1
    return c, 1


def to_ipa(word: str) -> str:
    words = re.findall(r"[a-záéíóúüñ]+", word.strip().lower())
    parts = []
    for w in words:
        parts.append(_word_ipa(w))
    return "/" + " ".join(parts) + "/"


def _word_ipa(w: str) -> str:
    chars = list(w)
    nuclei = find_nuclei(chars)
    stress = find_stress_index(nuclei, chars)
    # onset_start of stressed syllable = end of previous nucleus
    if stress == 0:
        onset_start = 0
    else:
        onset_start = nuclei[stress - 1][1]

    out = []
    marked = False
    i = 0
    n = len(chars)
    while i < n:
        if is_vowel(chars[i]):
            if i == onset_start and not marked:
                out.append("ˈ")
                marked = True
            j = i
            while j < n and is_vowel(chars[j]):
                out.append(vowel_ipa(chars[j]))
                j += 1
            i = j
        else:
            if i == onset_start and not marked:
                out.append("ˈ")
                marked = True
            seg, consumed = consonant_seg(chars, i)
            if seg:
                out.append(seg)
            i += consumed
    return "".join(out)


if __name__ == "__main__":
    import sys
    for w in sys.argv[1:]:
        print(w, "->", to_ipa(w))