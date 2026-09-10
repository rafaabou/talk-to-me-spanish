# Architecture — Talk To Me Spanish

**Version 1.7.0** | By Mohamed Rafaa Tounekti

---

## Overview

Offline-first Flutter app for learning Spanish. Trilingual UI (ES/EN/AR), 72 CEFR lessons, 1,816 verbs, FSRS flashcards, quizzes, and TTS audio. 100% offline.

---

## Tech Stack

| Layer | Technology |
|-------|-----------|
| Framework | Flutter 3.29.3 / Dart 3.7.2 |
| State management | Provider (ChangeNotifier) |
| Audio | just_audio 0.9.46 |
| Persistence | SharedPreferences (all local) |
| Charts | fl_chart 0.68.0 |
| PDF generation | pdf 3.10.7 |
| Spaced repetition | Custom FSRS implementation |
| Native code | Kotlin (Android widgets, notifications) |
| CI/CD | GitHub Actions + GitLab CI |
| Docker | 9-stage multi-stage build |

---

## Project Structure

```
espanol-zero-to-hero/
├── app/                            # Flutter project
│   ├── lib/
│   │   ├── main.dart               # Entry point, theme, Provider, zoom
│   │   ├── models/
│   │   │   ├── course_models.dart   # TriText, Lesson, VocabWord, Exercise, etc.
│   │   │   └── verb_models.dart    # VerbInfo, TenseInfo, VerbData
│   │   ├── screens/                # 17 screens
│   │   │   ├── home_screen.dart    # Dashboard, progress, streak
│   │   │   ├── main_shell.dart     # Bottom navigation shell
│   │   │   ├── account_screen.dart # Account, backup, clear data
│   │   │   ├── onboarding_screen.dart # First-run wizard
│   │   │   ├── lesson_list_screen.dart # Level lesson list
│   │   │   ├── lesson_screen.dart  # Full lesson viewer
│   │   │   ├── lesson_exercise_tile.dart # 8 exercise types
│   │   │   ├── lesson_sections.dart # Reusable section components
│   │   │   ├── lesson_search_sheet.dart # In-lesson search
│   │   │   ├── flashcard_screen.dart # FSRS flashcards
│   │   │   ├── quiz_screen.dart    # Level quizzes
│   │   │   ├── verb_screen.dart    # Verb browser + detail + quiz
│   │   │   ├── grammar_screen.dart # Grammar reference
│   │   │   ├── search_screen.dart  # Global search
│   │   │   ├── favorites_screen.dart # Bookmarked words
│   │   │   └── stats_screen.dart   # Statistics + charts
│   │   ├── services/               # 13 services
│   │   │   ├── app_state.dart      # Global state (lang, theme, zoom, etc.)
│   │   │   ├── progress_service.dart # All progress tracking
│   │   │   ├── course_repository.dart # Level/lesson JSON loader
│   │   │   ├── content_index.dart  # Search index builder
│   │   │   ├── audio_service.dart  # MD5-keyed audio playback
│   │   │   ├── fsrs.dart           # FSRS spaced repetition algorithm
│   │   │   ├── verb_repository.dart # Verb JSON loader
│   │   │   ├── pdf_export_service.dart # PDF handout generator
│   │   │   ├── notification_service.dart # Native notifications
│   │   │   ├── home_widget_service.dart # Home screen widget
│   │   │   ├── achievement_service.dart # Achievement badges & tracking
│   │   │   ├── ui_text.dart        # i18n helper
│   │   │   ├── progress_file_helper.dart # Conditional export
│   │   │   ├── progress_file_helper_io.dart # Mobile file I/O
│   │   │   ├── progress_file_helper_stub.dart # Web file I/O
│   │   │   ├── pdf_file_helper.dart # Conditional PDF export
│   │   │   ├── pdf_file_helper_io.dart # Mobile PDF share
│   │   │   └── pdf_file_helper_stub.dart # Web PDF download
│   │   └── widgets/
│   │       ├── audio_button.dart   # Audio playback button
│   │       ├── credit_footer.dart  # Copyright footer
│   │       ├── tri_block.dart      # Trilingual text display
│   │       ├── tr_text.dart        # Translation text widget
│   │       └── app_selection_area.dart # Selection wrapper
│   ├── assets/
│   │   ├── course/
│   │   │   ├── levels/index.json   # Level metadata (A1-C2)
│   │   │   ├── levels/*.json       # 72 lesson files
│   │   │   ├── index.json          # Search index
│   │   │   └── verbs.json          # 1,816 verbs x 8 tenses
│   │   └── audio/                  # 5,932 .opus files (MD5-keyed)
│   └── test/                       # 55 unit + widget tests
├── tools/                          # Python content pipeline
├── .github/workflows/build.yml     # GitHub Actions CI/CD
├── .gitlab-ci.yml                  # GitLab CI
├── Dockerfile                      # 9-stage build
├── docker-compose.yml              # 7 services
├── build-all.sh                    # Local APK + web build script
├── index.html                      # Web launcher
├── start-server.sh                 # Web server launcher
├── CONTRIBUTING.md                 # Contribution guidelines
├── SECURITY.md                     # Security policy
├── USER_GUIDE.md                   # User guide
├── PRIVACY_POLICY.md               # Privacy policy
├── LICENSE                         # Apache-2.0
└── NOTICE                          # Attribution
```

---

## Data Flow

```
User opens app
  → main.dart initializes Provider<AppState>
  → Checks onboarding flag
  → Routes to OnboardingScreen or HomeScreen
  → HomeScreen loads CourseRepository, ProgressService
  → Displays dashboard with progress, streak, due cards
  → User navigates to lesson/flashcard/quiz/verb

Lesson flow:
  → LessonScreen loads lesson JSON from CourseRepository
  → Renders sections: objectives, vocabulary, grammar, dialogue, reading, speaking, exercises
  → Exercises use LessonExerciseTile (8 types)
  → Progress saved via ProgressService → SharedPreferences

Flashcard flow:
  → FlashcardScreen loads ContentIndexRepository
  → FSRS scheduler selects due cards + unseen cards
  → User rates cards → FSRS updates schedule
  → Progress saved via ProgressService

Verb flow:
  → VerbScreen loads VerbRepository
  → Verbs grouped by conjugation type
  → VerbDetailScreen shows tense selection + conjugation table
  → VerbQuizScreen generates quiz from verb conjugations
```

---

## Audio System

- Audio files named by MD5 hash: `md5("es:{text}")[:12].opus`
- `AudioService.audioKey(text, lang)` generates the hash
- Files stored in `app/assets/audio/`
- Generated by `tools/gen_audio.py` using Microsoft Edge TTS (es-UY-ValentinaNeural)
- Speed controlled by `AppState.speed` (0.5x-1.0x)
- Repeat count controlled by `AppState.repeat` (1-10)

---

## Spaced Repetition (FSRS)

Custom implementation of the Free Spaced Repetition Scheduler:
- 17 configurable weights (w0-w16)
- 4 ratings: Again (1), Hard (2), Good (3), Easy (4)
- Request retention: 90%
- Maximum interval: 365 days
- Cards serialized as JSON in SharedPreferences
- Automatic migration from old Leitner box format

---

## Platform Adaptation

| Feature | Mobile | Web |
|---------|--------|-----|
| Progress export | path_provider file | dart:html blob download |
| Progress import | File picker | dart:html file input |
| PDF export | share_plus native share | dart:html download |
| Notifications | Kotlin MethodChannel | Not available |
| Home widget | Kotlin MethodChannel | Not available |
| Audio | just_audio asset playback | Web audio player |

---

## Security Architecture

- No INTERNET permission — fully offline
- No analytics, no tracking, no data collection
- Keystore signing with Cosign keyless
- SBOM generated for every release
- Vulnerability scanning (Grype, Trivy, Dockle)
- Secret scanning (Gitleaks, TruffleHog)
- GDPR compliant (no personal data)

---

## CI/CD Pipeline

```
validate → build → package → release
```

| Stage | Duration | What It Does |
|-------|----------|--------------|
| validate | ~30m | Format, analyze, test, secrets, dependency audit |
| build | ~90m | APK build, Docker build, security scans |
| package | ~45m | SBOM, Grype scan, Cosign sign, upload artifacts |
| release | ~20m | Create tag, GitHub Release with APK + signatures + SBOMs |

---

**Maintainer**: Mohamed Rafaa Tounekti
**Repository**: https://github.com/rafaabou/talk-to-me-spanish
