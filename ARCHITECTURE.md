# Architecture & Technical Reference

**Talk To Me Spanish** — Complete technical documentation.
By Mohamed Rafaa Tounekti.

---

## Table of Contents

1. [Architecture Overview](#1-architecture-overview)
2. [Project Structure](#2-project-structure)
3. [Data Models](#3-data-models)
4. [Services](#4-services)
5. [Screens](#5-screens)
6. [Widgets](#6-widgets)
7. [Android Native Layer](#7-android-native-layer)
8. [Audio Pipeline](#8-audio-pipeline)
9. [Content Pipeline](#9-content-pipeline)
10. [State Management](#10-state-management)
11. [FSRS Spaced Repetition](#11-fsrs-spaced-repetition)
12. [Trilingual System](#12-trilingual-system)
13. [Build & CI/CD](#13-build-cicd)
14. [Docker](#14-docker)
15. [Configuration Files](#15-configuration-files)
16. [Testing](#16-testing)

---

## 1. Architecture Overview

### Pattern: Provider + ChangeNotifier + Singletons

```
┌─────────────────────────────────────────────────┐
│                   main.dart                      │
│  ChangeNotifierProvider<AppState>                │
│  ┌──────────────────────────────────────────┐   │
│  │  _AppRoot (FutureBuilder)                │   │
│  │  ├── OnboardingScreen (first run)        │   │
│  │  └── HomeScreen (main dashboard)         │   │
│  │      ├── LessonListScreen                │   │
│  │      │   └── LessonScreen                │   │
│  │      ├── FlashcardScreen (SRS review)    │   │
│  │      ├── QuizScreen (level quiz)         │   │
│  │      ├── VerbScreen (conjugation ref)    │   │
│  │      ├── FavoritesScreen                 │   │
│  │      ├── GrammarScreen                   │   │
│  │      ├── SearchScreen                    │   │
│  │      └── StatsScreen                     │   │
│  └──────────────────────────────────────────┘   │
│                                                   │
│  Singleton Services:                              │
│  ├── CourseRepository (level/lesson JSON loader)  │
│  ├── VerbRepository (verb conjugation loader)     │
│  ├── ContentIndexRepository (search index)        │
│  ├── AudioService (TTS playback)                  │
│  ├── ProgressService (all persistence)            │
│  ├── AppState (global settings)                   │
│  ├── NotificationService (daily reminders)        │
│  ├── HomeWidgetService (Android widget)           │
│  └── PdfExportService (PDF generation)            │
└─────────────────────────────────────────────────┘
```

### Key Design Decisions

- **Offline-first**: All content bundled as JSON + .opus assets. No network required.
- **No backend**: Zero server dependencies. All state in SharedPreferences.
- **Trilingual**: Every UI string available in ES/EN/AR via `TriText` model.
- **Lazy loading**: Repositories load data on first access, cache in memory.
- **MD5 audio keys**: Deterministic file naming (`md5(lang:text)[:12]`) enables O(1) lookup.

---

## 2. Project Structure

```
espanol-zero-to-hero/
├── .dockerignore                    # Docker build context exclusions
├── .github/
│   ├── dependabot.yml               # Auto-dependency updates (pub, actions, docker)
│   └── workflows/
│       └── build.yml                # GitHub Actions: validate → build → package → release
├── .gitlab-ci.yml                   # GitLab CI: validate → build → package → release
├── .gitlab/
│   └── dependabot.yml               # GitLab Dependabot config
├── .gitignore                       # Git exclusions (140 lines)
├── .gitleaks.toml                   # Secret scanning rules (296 lines)
├── .pre-commit-config.yaml          # Pre-commit hooks (206 lines)
├── CONTRIBUTING.md                  # Contribution guidelines
├── docker-compose.yml               # 6 services: builder, scanner, scanner-ci, signer, runtime, dev
├── Dockerfile                       # 8-stage multi-stage build
├── LICENSE                          # Apache-2.0
├── NOTICE                           # Attribution notices
├── README.md                        # Project documentation
├── SECURITY.md                      # Security policy
├── tools/                           # Python content pipeline
│   ├── apply_es.py                  # Spanish-specific content adjustments
│   ├── augment_content.py           # Augment lesson content
│   ├── build_content.py             # Build course content
│   ├── build_index.py               # Build search index (index.json)
│   ├── build_verbs.py               # Build verb conjugations (verbs.json)
│   ├── content_a1.py                # A1 level content
│   ├── content_a1_full.py           # A1 full content
│   ├── content_a1_rest.py           # A1 remaining content
│   ├── content_a2.py                # A2 level content
│   ├── content_b1.py                # B1 level content
│   ├── content_b2.py                # B2 level content
│   ├── content_c1.py                # C1 level content
│   ├── content_c2.py                # C2 level content
│   ├── course_map.json              # Course structure mapping
│   ├── es_ipa.py                    # Spanish IPA pronunciation
│   ├── extract_es.py                # Spanish content extraction
│   ├── gen_audio.py                 # Audio generation (edge-tts)
│   ├── mobsf_scan.py                # MobSF security scanning
│   └── schema.py                    # JSON schema definitions
└── app/                             # Flutter project
    ├── .dockerignore                # App-level Docker exclusions
    ├── .gitignore                   # App-level Git exclusions
    ├── .metadata                    # Flutter metadata
    ├── .flutter-plugins             # Generated plugin list
    ├── .flutter-plugins-dependencies
    ├── analysis_options.yaml        # Dart linter config
    ├── Dockerfile                   # App-level Dockerfile (scan-only)
    ├── lic_ck.yaml                  # License checker config
    ├── pubspec.yaml                 # Flutter dependencies
    ├── README.md                    # App-level readme
    ├── .idea/                       # IntelliJ/Android Studio config
    │   ├── libraries/
    │   │   ├── Dart_SDK.xml
    │   │   └── KotlinJavaRuntime.xml
    │   ├── modules.xml
    │   ├── runConfigurations/
    │   │   └── main_dart.xml
    │   └── workspace.xml
    ├── android/                     # Android native code
    │   ├── .gitignore
    │   ├── build.gradle.kts         # Project-level Gradle config
    │   ├── gradle.properties
    │   ├── gradlew / gradlew.bat
    │   ├── local.properties
    │   ├── settings.gradle.kts
    │   ├── gradle/wrapper/
    │   │   └── gradle-wrapper.properties
    │   └── app/
    │       ├── build.gradle.kts     # App-level Gradle config
    │       ├── release.keystore     # LOCAL dev keystore (gitignored)
    │       └── src/
    │           ├── debug/AndroidManifest.xml
    │           ├── profile/AndroidManifest.xml
    │           └── main/
    │               ├── AndroidManifest.xml
    │               ├── java/io/flutter/plugins/GeneratedPluginRegistrant.java
    │               ├── kotlin/com/rafaabou/eszero_hero/
    │               │   ├── BootReceiver.kt
    │               │   ├── EszeroWidgetProvider.kt
    │               │   ├── MainActivity.kt
    │               │   ├── NotificationReceiver.kt
    │               │   ├── NotificationService.kt
    │               │   └── WidgetConfigureActivity.kt
    │               └── res/          # Android resources
    │                   ├── drawable/
    │                   ├── drawable-v21/
    │                   ├── layout/widget_layout.xml
    │                   ├── mipmap-*/   # App icons
    │                   ├── values/colors.xml, styles.xml
    │                   ├── values-night/styles.xml
    │                   └── xml/widget_info.xml
    ├── assets/
    │   ├── audio/                   # ~5,932 .opus TTS files
    │   └── course/
    │       ├── index.json           # Search index (vocab, grammar, dialogue, reading)
    │       ├── verbs.json           # 1,816 verbs × 8 tenses
    │       └── levels/
    │           ├── index.json       # Level metadata (A1-C2)
    │           ├── A1-01.json .. A1-12.json
    │           ├── A2-01.json .. A2-12.json
    │           ├── B1-01.json .. B1-12.json
    │           ├── B2-01.json .. B2-12.json
    │           ├── C1-01.json .. C1-12.json
    │           └── C2-01.json .. C2-12.json
    ├── lib/                         # Dart source code
    │   ├── main.dart
    │   ├── models/
    │   │   ├── course_models.dart
    │   │   └── verb_models.dart
    │   ├── screens/
    │   │   ├── favorites_screen.dart
    │   │   ├── flashcard_screen.dart
    │   │   ├── grammar_screen.dart
    │   │   ├── home_screen.dart
    │   │   ├── lesson_exercise_tile.dart
    │   │   ├── lesson_list_screen.dart
    │   │   ├── lesson_screen.dart
    │   │   ├── lesson_search_sheet.dart
    │   │   ├── lesson_sections.dart
    │   │   ├── onboarding_screen.dart
    │   │   ├── quiz_screen.dart
    │   │   ├── search_screen.dart
    │   │   ├── stats_screen.dart
    │   │   └── verb_screen.dart
    │   ├── services/
    │   │   ├── app_state.dart
    │   │   ├── audio_service.dart
    │   │   ├── content_index.dart
    │   │   ├── course_repository.dart
    │   │   ├── fsrs.dart
    │   │   ├── home_widget_service.dart
    │   │   ├── notification_service.dart
    │   │   ├── pdf_export_service.dart
    │   │   ├── progress_service.dart
    │   │   ├── ui_text.dart
    │   │   └── verb_repository.dart
    │   └── widgets/
    │       ├── app_selection_area.dart
    │       ├── audio_button.dart
    │       ├── credit_footer.dart
    │       ├── tri_block.dart
    │       ├── tr_text.dart
    │       └── word_tap_text.dart
    └── test/                        # 55 tests
        ├── course_repository_test.dart
        ├── fsrs_test.dart
        ├── pinch_test.dart
        ├── progress_service_test.dart
        ├── quiz_screen_test.dart
        ├── ui_text_test.dart
        └── widget_test.dart
```

**File count**: 34 Dart files (1 entry, 2 models, 11 services, 14 screens, 6 widgets).

### Key Differences from Portuguese App

| Aspect | Spanish | Portuguese |
|--------|---------|------------|
| Package ID | `com.rafaabou.eszero_hero` | `com.rafaabou.ptbr_zero_to_hero` |
| Widget Provider | `EszeroWidgetProvider.kt` | `PtbrWidgetProvider.kt` |
| MethodChannel | `com.rafaabou.eszero_hero` | `com.rafaabou.ptbr_zero_to_hero` |
| Verb count | 1,816 | 1,834 |
| Audio files | ~5,932 | ~5,041 |
| Audio voice | `es-UY-ValentinaNeural` | `pt-BR-FranciscaNeural` |
| Extra tools | `apply_es.py`, `es_ipa.py`, `extract_es.py` | (none) |
| Runner label | `spanish` | `portuguese` |
| GitHub repo | `rafaabou/talk-to-me-spanish` | `rafaabou/talk-to-me-portugues` |

---

## 3. Data Models

### `course_models.dart` — Course Content Models

#### `TriText` — Core trilingual container

```dart
class TriText {
  final String es;  // Spanish text
  final String en;  // English text
  final String ar;  // Arabic text
}
```

Every piece of user-facing text uses `TriText`. The `tr(lang)` method returns the appropriate string based on the selected UI language.

#### `VocabWord` — Vocabulary entry

```dart
class VocabWord {
  final String es;          // Spanish word
  final String ipa;         // IPA pronunciation
  final String en;          // English translation
  final String ar;          // Arabic translation
  final TriText? example;   // Optional example sentence
}
```

#### `GrammarSection` — Grammar rule

```dart
class GrammarSection {
  final TriText title;
  final TriText explanation;
  final List<TriText> examples;
}
```

#### `DialogueLine` — Dialogue entry

```dart
class DialogueLine {
  final String speaker;     // Speaker name
  final TriText text;       // What they said
}
```

#### `Exercise` — Interactive exercise

```dart
class Exercise {
  final String type;              // multiple_choice, fill_in_blank, reorder, true_false
  final TriText prompt;
  final List<String> options;     // Answer choices
  final String answer;            // Correct answer
  final List<String> accepted;    // Alternative correct answers
  final String? audio;            // Optional audio file
  final String? explanation;      // Why this is correct
}
```

#### `SpeakingItem` — Speaking practice

```dart
class SpeakingItem {
  final TriText text;
}
```

#### `Lesson` — Complete lesson

```dart
class Lesson {
  final String id;                              // e.g., "A1-01"
  final String level;                           // e.g., "A1"
  final TriText title;
  final List<TriText> objectives;
  final List<VocabWord> vocabulary;
  final List<GrammarSection> grammar;
  final DialogueSection dialogue;               // title + lines
  final ReadingSection reading;                 // title + text
  final List<SpeakingItem> speaking;
  final List<Exercise> exercises;
  final TriText? culturalTips;
}
```

#### `LevelInfo` — Level metadata

```dart
class LevelInfo {
  final String id;                              // e.g., "A1"
  final TriText name;
  final TriText description;
  final List<Map<String, dynamic>> lessons;     // List of {id, title} maps
}
```

### `verb_models.dart` — Verb Conjugation Models

#### `VerbInfo` — Single verb

```dart
class VerbInfo {
  final String infinitive;                      // e.g., "hablar"
  final String en;                              // English translation
  final String ar;                              // Arabic translation
  final String conjType;                        // -AR, -ER, -IR, -OR, irregular
  final bool hasFullAudio;                      // True if all tenses have audio
  final Map<String, List<String>> tenses;       // tense_id → [6 conjugations]
}
```

#### `TenseInfo` — Tense metadata

```dart
class TenseInfo {
  final String id;                              // e.g., "present"
  final TriTextLabel name;                      // Trilingual tense name
}
```

#### `TriTextLabel` — Trilingual label

```dart
class TriTextLabel {
  final String es;                              // "Presente"
  final String en;                              // "Present"
  final String ar;                              // "الحاضر"
}
```

#### `VerbData` — Aggregate verb container

```dart
class VerbData {
  final List<TenseInfo> tenses;                 // 8 tenses
  final List<String> persons;                   // ["yo", "tu", "el/ella", "nosotros", "ustedes", "ellos/ellas"]
  final Map<String, List<String>> conjugationGroups;  // conjType → [verb1, verb2, ...]
  final List<VerbInfo> verbs;                   // All 1,816 verbs
}
```

---

## 4. Services

### `app_state.dart` — Global Settings

```dart
class AppState extends ChangeNotifier {
  String _lang = 'en';           // UI language: en, es, ar
  double _speed = 1.0;          // Audio playback speed (0.5–2.0)
  int _repeat = 1;              // Audio repeat count (1–10)
  ThemeMode _themeMode = ThemeMode.system;  // system, light, dark
  double _zoom = 1.0;           // Pinch zoom level (0.8–2.0)

  bool get isRtl => _lang == 'ar';
}
```

All settings persist to `SharedPreferences` on change.

### `audio_service.dart` — TTS Audio Playback

```dart
class AudioService {
  static final instance = AudioService._();
  AudioPlayer? _player;

  // Deterministic audio key: md5("es:hablar")[:12] → "es_abc123def456"
  static String audioKey(String lang, String text) {
    final hash = md5.convert(utf8.encode('$lang:$text'));
    return '${lang}_${hash.toString().substring(0, 12)}';
  }

  Future<void> playText(String text, String lang) async {
    final key = audioKey(lang, text);
    await playAsset('assets/audio/$key.opus');
  }

  Future<void> playAsset(String assetPath) async {
    // Verifies asset exists, sets speed, plays with repeat count
    // Waits for ProcessingState.completed with 60s timeout
    // Error handling: disposes broken player, sets _player = null
  }
}
```

### `course_repository.dart` — Lesson Loader

```dart
class CourseRepository {
  static final instance = CourseRepository._();
  Map<String, LevelInfo>? _levels;
  final Map<String, Lesson?> _cache = {};

  Future<Map<String, LevelInfo>> loadLevels() async {
    // Parses assets/course/levels/index.json
    // Returns map of level_id → LevelInfo
  }

  Future<Lesson?> loadLesson(String id) async {
    // Loads assets/course/levels/$id.json
    // Caches result in _cache
  }
}
```

### `verb_repository.dart` — Verb Conjugation Loader

```dart
class VerbRepository {
  static final instance = VerbRepository._();
  VerbData? _data;

  Future<VerbData> load() async {
    // Parses assets/course/verbs.json
    // Extracts tenses, persons, conjugation groups
    // Caches result
  }
}
```

### `content_index.dart` — Search Index

```dart
class ContentIndex {
  final List<IndexVocab> vocab;
  final List<IndexGrammar> grammar;
  final List<IndexDialogue> dialogue;
  final List<IndexReading> reading;
  final Map<String, String> lessonTitles;  // lesson_id → title
}

class ContentIndexRepository {
  static final instance = ContentIndexRepository._();
  // Lazy-loads and caches ContentIndex from assets/course/index.json
}
```

### `progress_service.dart` — Central Persistence (419 lines)

The largest service. Manages ALL user data via SharedPreferences:

| Key | Type | Purpose |
|-----|------|---------|
| `completed_lessons` | `List<String>` | Completed lesson IDs |
| `completed_exercises` | `Map<String, List<int>>` | Lesson → exercise indices |
| `favorite_words` | `List<String>` | Bookmarked vocabulary |
| `streak` | `int` | Current study streak |
| `last_study` | `String` | Last study date |
| `study_days` | `List<String>` | All study dates |
| `srs_fsrs` | `List<Map>` | FSRS flashcard data |
| `last_opened_lesson` | `String` | Resume point |
| `lesson_notes` | `Map<String, String>` | Per-lesson notes |
| `onboarding_done` | `bool` | First-run flag |
| `accessibility_settings` | `Map` | Accessibility prefs |
| `repeat_count` | `int` | Audio repeat setting |

Key methods:
- `markCompleted(lessonId)` / `isCompleted(lessonId)`
- `toggleExerciseDone(lessonId, exerciseIndex)`
- `toggleFavorite(word)` / `getFavorites()`
- `markSrs(word, rating)` — FSRS review
- `getDueFsrsCards()` — Flashcard due list
- `_bumpStreak()` — Daily streak logic
- `exportData()` / `importData()` — JSON backup/restore
- `resetAll()` — Wipe everything

### `fsrs.dart` — Spaced Repetition Algorithm

```dart
class FsrsCard {
  final String key;
  DateTime due;
  double stability;
  double difficulty;
  DateTime? lastReview;
  int reviews;
  int lapses;
}

class FsrsScheduler {
  FsrsCard firstReview(String key, DateTime now) {
    // Create new card with initial stability/difficulty
  }

  FsrsCard reviewCard(FsrsCard card, int rating, DateTime now) {
    // rating: 1=Again, 2=Hard, 3=Good, 4=Easy
    // Updates stability, difficulty, due date
    // Uses DSR (Difficulty, Stability, Retrievability) model
  }
}
```

### `notification_service.dart` — Daily Reminders

```dart
class NotificationService {
  static final instance = NotificationService._();
  // Platform MethodChannel: com.rafaabou.eszero_hero/notification
  // Manages daily study reminders
  // Handles permissions on Android 13+
}
```

### `home_widget_service.dart` — Android Home Widget

```dart
class HomeWidgetService {
  // Sends data to native Android widget via MethodChannel
  // Displays: due review count, streak, completed lessons
  // Triggers flashcard screen from widget tap
}
```

### `pdf_export_service.dart` — PDF Export

```dart
class PdfExportService {
  static final instance = PdfExportService._();
  // Generates PDF from lesson data using 'pdf' package
  // Exports: vocabulary, grammar, dialogue, exercises
  // Shares via share_plus
}
```

### `ui_text.dart` — Localization Helper

```dart
String uiText(String lang, {String? ar, String? es, String? en, required String other}) {
  // Returns the string for the given language
  // Falls back to `other` if no match
}
```

---

## 5. Screens

### Navigation Flow

```
OnboardingScreen (first run only)
  └─→ HomeScreen
        ├── LessonListScreen (per level)
        │     └── LessonScreen
        │           └── LessonSearchSheet (bottom sheet)
        ├── FlashcardScreen (SRS review)
        ├── QuizScreen (level quiz)
        ├── VerbScreen
        │     └── VerbConjugationSheet
        ├── FavoritesScreen
        ├── GrammarScreen
        ├── SearchScreen
        └── StatsScreen
```

### Screen Details

| Screen | File | Purpose |
|--------|------|---------|
| `HomeScreen` | `home_screen.dart` | Main dashboard. Level cards, progress stats, navigation to all features. Shows streak, due flashcard count, last opened lesson. |
| `LessonListScreen` | `lesson_list_screen.dart` | Lists lessons for a level. Shows completion checkmarks. |
| `LessonScreen` | `lesson_screen.dart` | Full lesson view: objectives, vocabulary, grammar, dialogue, reading, speaking, exercises, cultural tips. PDF export. |
| `FlashcardScreen` | `flashcard_screen.dart` | SRS flashcard review. Pulls due cards from FSRS. Swipe/button to mark known/unknown. |
| `QuizScreen` | `quiz_screen.dart` | Level quiz. Randomized questions from all exercises. Tracks best score. |
| `VerbScreen` | `verb_screen.dart` | Verb conjugation reference. 1,816 verbs, filterable by type. Conjugation tables with audio. |
| `FavoritesScreen` | `favorites_screen.dart` | Bookmarked vocabulary words with audio playback. |
| `GrammarScreen` | `grammar_screen.dart` | Aggregated grammar browser. Filterable by level. Examples with audio. |
| `SearchScreen` | `search_screen.dart` | Global content search across all lessons. |
| `StatsScreen` | `stats_screen.dart` | Charts (fl_chart): lessons, exercises, streak, study calendar, FSRS stats. Data export/import/reset. |
| `OnboardingScreen` | `onboarding_screen.dart` | First-run wizard. Language selection, intro pages. |
| `LessonSearchSheet` | `lesson_search_sheet.dart` | Bottom sheet for in-lesson search. |
| `LessonSections` | `lesson_sections.dart` | Section builders: VocabularySection, GrammarSection, DialogueSection, etc. |
| `ExerciseTile` | `lesson_exercise_tile.dart` | Interactive exercise widget: multiple choice, fill-in-blank, reorder, true/false. |

---

## 6. Widgets

| Widget | File | Purpose |
|--------|------|---------|
| `AudioButton` | `audio_button.dart` | Playable speaker icon. Takes text + lang, plays TTS audio. Shows loading spinner. |
| `WordTapText` | `word_tap_text.dart` | Tappable text. Individual words trigger popup dictionary with translation + IPA + audio. |
| `TriBlock` | `tri_block.dart` | Displays ES/EN/AR translations vertically. Optional audio button. |
| `TrText` | `tr_text.dart` | Simple trilingual text renderer. |
| `CreditFooter` | `credit_footer.dart` | Author credit footer. Multi-language. |
| `AppSelectionArea` | `app_selection_area.dart` | SelectionArea wrapper with Material text selection controls. |

---

## 7. Android Native Layer

### Kotlin Files (6 files)

| File | Purpose |
|------|---------|
| `MainActivity.kt` | Main activity. Registers MethodChannel for widget communication. |
| `BootReceiver.kt` | Receives BOOT_COMPLETED broadcast. Reschedules notifications. |
| `NotificationService.kt` | Manages notification channels and daily reminders. |
| `NotificationReceiver.kt` | Receives notification intents. Shows study reminders. |
| `EszeroWidgetProvider.kt` | Android AppWidget. Displays streak, due count, completed lessons. |
| `WidgetConfigureActivity.kt` | Configuration activity for home screen widget. |

### AndroidManifest.xml

- Permissions: `RECEIVE_BOOT_COMPLETED`, `SCHEDULE_EXACT_ALARM`, `POST_NOTIFICATIONS`
- No `INTERNET` permission (offline-first)
- Components: BootReceiver, NotificationReceiver, WidgetProvider, WidgetConfigureActivity

### build.gradle.kts

- `applicationId`: `com.rafaabou.eszero_hero`
- `minSdk`: 24 (Android 7.0)
- `ndkVersion`: 27.0.12077973
- `isMinifyEnabled = true` for release
- `.opus` files excluded from compression (`noCompress += listOf("opus")`)
- Signing: env vars or fallback to `release.keystore` with password `release123`

---

## 8. Audio Pipeline

### How Audio Works

1. **Generation**: `tools/gen_audio.py` uses `edge-tts` to generate `.opus` files
2. **Key scheme**: `md5(f'{lang}:{text}')[:12]` — same as `AudioService.audioKey()`
3. **File format**: `.opus` (Ogg Opus, ~10-50KB per file)
4. **Bundling**: Files in `app/assets/audio/`, declared in `pubspec.yaml`
5. **Playback**: `AudioService.playText()` → looks up asset by MD5 key → `just_audio` player

### Audio Key Generation

```python
# gen_audio.py
import hashlib

def audio_key(lang: str, text: str) -> str:
    h = hashlib.md5(f"{lang}:{text}".encode()).hexdigest()[:12]
    return f"{lang}_{h}"
```

```dart
// audio_service.dart
static String audioKey(String lang, String text) {
  final hash = md5.convert(utf8.encode('$lang:$text'));
  return '${lang}_${hash.toString().substring(0, 12)}';
}
```

### Audio Stats

- **Spanish**: ~5,932 .opus files
- **Voice**: `es-UY-ValentinaNeural` (Microsoft Edge TTS)
- **Speed**: Configurable 0.5x–2.0x
- **Repeat**: Configurable 1–10 times

---

## 9. Content Pipeline

### tools/ Scripts

| Script | Purpose |
|--------|---------|
| `build_verbs.py` | Generates `verbs.json` from verb conjugation data |
| `build_index.py` | Generates `index.json` from lesson JSONs |
| `build_content.py` | Builds course content from scripts |
| `gen_audio.py` | Generates .opus audio files via edge-tts |
| `augment_content.py` | Augments existing content |
| `apply_es.py` | Spanish-specific content adjustments |
| `es_ipa.py` | Spanish IPA pronunciation data |
| `extract_es.py` | Spanish content extraction |
| `content_a1.py` .. `content_c2.py` | Level-specific content generators |
| `schema.py` | JSON schema definitions |
| `course_map.json` | Course structure mapping |
| `mobsf_scan.py` | MobSF security scanning |

### JSON Schemas

#### `assets/course/levels/index.json`

```json
{
  "levels": [
    {
      "id": "A1",
      "name": { "es": "A1", "en": "A1", "ar": "A1" },
      "description": { "es": "...", "en": "...", "ar": "..." },
      "lessons": [
        { "id": "A1-01", "title": { "es": "...", "en": "...", "ar": "..." } }
      ]
    }
  ]
}
```

#### `assets/course/levels/A1-01.json` (Lesson)

```json
{
  "id": "A1-01",
  "level": "A1",
  "title": { "es": "Saludos", "en": "Greetings", "ar": "التحيات" },
  "objectives": [{ "es": "...", "en": "...", "ar": "..." }],
  "vocabulary": [
    { "es": "hola", "ipa": "/ˈola/", "en": "hello", "ar": "مرحبا" }
  ],
  "grammar": [
    {
      "title": { "es": "...", "en": "...", "ar": "..." },
      "explanation": { "es": "...", "en": "...", "ar": "..." },
      "examples": [{ "es": "...", "en": "...", "ar": "..." }]
    }
  ],
  "dialogue": {
    "title": { "es": "...", "en": "...", "ar": "..." },
    "lines": [{ "speaker": "Maria", "text": { "es": "...", "en": "...", "ar": "..." } }]
  },
  "reading": { "title": { "es": "...", "en": "...", "ar": "..." }, "text": { "es": "...", "en": "...", "ar": "..." } },
  "speaking": [{ "text": { "es": "...", "en": "...", "ar": "..." } }],
  "exercises": [
    {
      "type": "multiple_choice",
      "prompt": { "es": "...", "en": "...", "ar": "..." },
      "options": ["hola", "adios", "gracias"],
      "answer": "hola",
      "accepted": ["hola"],
      "explanation": { "es": "...", "en": "...", "ar": "..." }
    }
  ],
  "culturalTips": { "es": "...", "en": "...", "ar": "..." }
}
```

#### `assets/course/verbs.json`

```json
{
  "tenses": [
    { "id": "present", "name": { "es": "Presente", "en": "Present", "ar": "الحاضر" } }
  ],
  "persons": ["yo", "tu", "el/ella", "nosotros", "ustedes", "ellos/ellas"],
  "conjugationGroups": {
    "-AR": ["hablar", "cantar", ...],
    "-ER": ["comer", "beber", ...],
    "-IR": ["abrir", "escribir", ...],
    "irregular": ["ser", "estar", "ir", ...]
  },
  "verbs": [
    {
      "infinitive": "hablar",
      "en": "to speak",
      "ar": "يتحدث",
      "conjType": "-AR",
      "hasFullAudio": true,
      "present": ["hablo", "hablas", "habla", "hablamos", "hablan", "hablan"],
      "preterite": ["hable", "hablaste", ...],
      "imperfect": ["hablaba", "hablabas", ...],
      "future": ["hablare", "hablaras", ...],
      "conditional": ["hablaria", "hablarias", ...],
      "subjunctive": ["hable", "hables", ...],
      "subjunctive_past": ["hablara", "hablaras", ...],
      "imperative": ["habla", "hable", ...]
    }
  ]
}
```

---

## 10. State Management

### Data Flow

```
User Action
  → Screen (StatefulWidget)
    → Service (Singleton)
      → SharedPreferences (Disk)
    → AppState (ChangeNotifier)
      → Widget Rebuild
```

### Provider Setup (main.dart)

```dart
void main() {
  runApp(
    ChangeNotifierProvider(
      create: (_) => AppState(),
      child: const SpanishApp(),
    ),
  );
}
```

### Persistence Flow

```
App Start
  → ProgressService.instance (singleton init)
    → SharedPreferences.getInstance()
    → Load: completed_lessons, streak, srs_fsrs, favorites, ...

User Studies
  → ProgressService.markCompleted(id)
    → _completed.add(id)
    → _prefs.setStringList('completed_lessons', _completed.toList())
    → _bumpStreak()
    → HomeWidgetService.updateWidget()

User Reviews Flashcard
  → ProgressService.markSrs(word, rating)
    → FsrsScheduler.reviewCard(card, rating, now)
    → card.due = new_due_date
    → _prefs.setString('srs_fsrs', jsonEncode(cards))
```

---

## 11. FSRS Spaced Repetition

### Algorithm Overview

FSRS (Free Spaced Repetition Scheduler) uses three factors:

- **D** (Difficulty): How hard the card is (0–10)
- **S** (Stability): How long until the card is forgotten
- **R** (Retrievability): Current recall probability

### Card Lifecycle

```
New Card
  → firstReview() → initial S=1, D=5, due=now+1day
  → review(rating=3) → S grows, D adjusts, due = now + S
  → review(rating=1) → S resets (lapse), due = now + 1min
  → review(rating=5) → S grows faster
```

### Ratings

| Rating | Label | Effect |
|--------|-------|--------|
| 1 | Again | Lapse. Card resets. |
| 2 | Hard | Small S increase. |
| 3 | Good | Normal S increase. |
| 4 | Easy | Large S increase. |

### Leitner Migration

Old Leitner boxes are automatically migrated to FSRS on first access.

---

## 12. Trilingual System

### Language Codes

| Code | Language | Direction |
|------|----------|-----------|
| `es` | Spanish | LTR |
| `en` | English | LTR |
| `ar` | Arabic | RTL |

### UI Language Selection

- Set via `AppState.lang` (persisted to SharedPreferences)
- `uiText()` function returns the appropriate string
- `TriText.tr(lang)` method on data models
- RTL support via `Directionality` widget when `ar` is selected

### Example

```dart
TriText es = TriText('Hola', 'Hello', 'مرحبا');
es.tr('es')  // 'Hola'
es.tr('en')  // 'Hello'
es.tr('ar')  // 'مرحبا'
```

---

## 13. Build & CI/CD

### Local Build

```bash
cd app
flutter pub get
JAVA_HOME=/home/antix/android-toolchain/jdk17 \
  flutter build apk --release --target-platform android-arm64
# Output: build/app/outputs/flutter-apk/app-release.apk
```

### GitHub Actions Pipeline (`.github/workflows/build.yml`)

4 stages, runs on self-hosted runner with labels `[self-hosted, linux, X64, spanish]`:

| Stage | Job | Time | What It Does |
|-------|-----|------|--------------|
| 1. validate | `validate` | 30m | Format check, analyze, test, license check, gitleaks, TruffleHog, dependency audit |
| 2. build | `build` | 90m | Keystore restore, obfuscated APK, size check, Hadolint, Docker build, Grype, Syft, Trivy, Dockle |
| 3. package | `package` | 45m | Keystore restore, APK rebuild, SBOM generation, Grype APK scan, Cosign signing, GitHub release upload |
| 4. release | `release` | 20m | Tag creation, GitHub Release with all artifacts |

### GitLab CI Pipeline (`.gitlab-ci.yml`)

4 stages, runs on runner with tag `[spanish]`:

| Stage | Jobs | Notes |
|-------|------|-------|
| validate | `validate`, `hadolint` | Format, analyze, test, secrets, dependency audit |
| build | `build` | APK + Docker image + security scans |
| package | `package` | SBOM + Cosign signing + GitLab release |
| release | `release` | GitLab Release creation |

### Required Secrets

| Secret | Platform | Required |
|--------|----------|----------|
| `RELEASE_KEYSTORE_BASE64` | Both | Optional (ephemeral if absent) |
| `GITHUB_TOKEN` | GitHub | Automatic |
| `MOBSF_API_KEY` | GitLab | Optional (MobSF job) |

---

## 14. Docker

### Dockerfile (8-Stage Build)

| Stage | Base | Purpose |
|-------|------|---------|
| 1. base | ubuntu:22.04 | Common deps (JDK 17, Python 3, curl, git) |
| 2. flutter-sdk | base | Flutter 3.29.3 + Android SDK 11076708 + NDK 27.0.12077973 |
| 3. security-tools | flutter-sdk | Grype, Syft, Trivy, Cosign, gitleaks |
| 4. builder | security-tools | Flutter APK build (obfuscated, arm64) |
| 5. scanner | security-tools | SBOM generation, vulnerability scanning |
| 6. signer | security-tools | Cosign keyless signing, APK verification |
| 7. artifacts | scratch | Final artifact image (APK, signatures, SBOMs) |
| 8. runtime | base | Testing image (APK + minimal tools) |

### docker-compose.yml (6 Services)

| Service | Profile | Purpose |
|---------|---------|---------|
| `builder` | default | Compiles APK with Flutter + Android SDK |
| `scanner` | default | Security scanning (Grype, Trivy, MobSF) |
| `scanner-ci` | ci | CI-mode scanner with `--fail-on high` |
| `signer` | release | Signs APKs and SBOMs with Cosign |
| `runtime` | test | Testing on device/emulator (KVM passthrough) |
| `dev` | dev | Hot-reload development (web server on port 5001) |

### Volumes

- `flutter-cache`: `/root/.pub-cache`
- `gradle-cache`: `/root/.gradle`
- `artifacts`: Build outputs
- `signatures`: Cosign signatures
- `sbom`: SBOM files
- `sarif`: SARIF scan reports

---

## 15. Configuration Files

### `.gitignore` (140 lines)

Excludes:
- Security scan reports (`*grype-report*.json`, `*trivy-results*.sarif`, etc.)
- SBOMs (`sbom*.cdx.json`)
- Cosign signatures (`*.sig`, `*.pem`, `*.key`)
- Keystores (`*.keystore`, `*.jks`)
- Docker artifacts (`.docker/`, `docker-compose.override.yml`)
- Environment files (`.env*`)
- IDE files (`.vscode/`, `.idea/`)
- Flutter/Dart build artifacts (`.dart_tool/`, `.flutter-plugins`, `/build/`)
- Python tooling (`__pycache__/`, `.venv/`)
- Generated code (`*.g.dart`, `*.freezed.dart`)
- Secrets (`secrets.yaml`, `*.secret`)

### `.dockerignore` (147 lines)

Excludes everything except `app/assets/` (course content + audio must ship in image).
Also keeps `pubspec.lock` for reproducible `--enforce-lockfile` installs.

### `.gitleaks.toml` (296 lines)

Extensive allowlist for lock files, config files, markdown, JSON, YAML, XML, Gradle.
False positive patterns for Flutter/Dart, test values, common placeholders.
Rules for: API keys, secrets, Google/Firebase/AWS/GitHub/GitLab keys, JWT tokens, SSH/PGP keys.

### `.pre-commit-config.yaml` (206 lines)

Hooks:
1. `dart-format` — Format Dart code
2. `flutter-analyze` — Static analysis
3. `gitleaks` — Secret detection
4. `trufflehog` — Secret detection (deep)
5. `license-check` — License compliance
6. `pub-outdated` — Dependency freshness
7. `dart-linter` — Dart linter
8. Standard hooks: trailing-whitespace, end-of-file-fixer, check-yaml/json/toml/xml, large files, merge conflicts, private keys

### `.github/dependabot.yml` (80 lines)

Three ecosystems:
1. **pub** (Dart/Flutter): Weekly, ignores semver-major
2. **github-actions**: Weekly
3. **docker**: Weekly

### `app/pubspec.yaml`

```yaml
name: talk_to_me_spanish
version: 1.4.3+6
environment:
  sdk: ^3.7.2
dependencies:
  flutter, cupertino_icons, just_audio, shared_preferences,
  provider, crypto, path_provider, timezone, pdf, fl_chart, share_plus
assets:
  - assets/course/levels/
  - assets/course/index.json
  - assets/course/verbs.json
  - assets/audio/
```

### `app/analysis_options.yaml`

```yaml
include: package:flutter_lints/flutter.yaml
```

### `app/lic_ck.yaml`

```yaml
permittedLicenses:
  - MIT, BSD-3-Clause, BSD-2-Clause, Apache-2.0, ISC, MPL-2.0, Unicode-TOU, BSD-3-Clause-Clear
omitDisclaimer:
  - flutter_lints
```

### `app/android/app/build.gradle.kts`

- `applicationId`: `com.rafaabou.eszero_hero`
- `minSdk`: 24, `ndkVersion`: 27.0.12077973
- Signing from env vars or fallback defaults
- `isMinifyEnabled = true` for release
- `.opus` files excluded from compression

---

## 16. Testing

### Test Files (55 tests total)

| File | Tests |
|------|-------|
| `course_repository_test.dart` | Level/lesson loading, caching |
| `fsrs_test.dart` | FSRS algorithm, card lifecycle |
| `pinch_test.dart` | Pinch-to-zoom gesture handling |
| `progress_service_test.dart` | Persistence, streaks, favorites, SRS |
| `quiz_screen_test.dart` | Quiz logic, scoring |
| `ui_text_test.dart` | Localization helper |
| `widget_test.dart` | Widget rendering |

### Running Tests

```bash
cd app
flutter test          # Run all 55 tests
flutter test -j 1     # Single-threaded (CI)
```

---

**Last updated**: 2026-09-01
**Version**: 1.4.2
**Maintainer**: Mohamed Rafaa Tounekti
