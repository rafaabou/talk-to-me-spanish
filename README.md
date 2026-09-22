# Talk To Me Spanish

**Latest release: v1.10.0** | By Mohamed Rafaa Tounekti

Offline-first **Spanish** learning app (Flutter, Android). 72 CEFR lessons (A1-C2), 1,816 verbs with 8 tenses, FSRS flashcards, quizzes, trilingual UI (ES/EN/AR), TTS audio, verb conjugation browser, **voice conversation practice (roleplay + free Q&A)**, and full DevSecOps CI/CD pipeline — 100% offline.

- Package: `com.rafaabou.eszero_hero`
- Min SDK: 24 (Android 7.0) | Target: arm64 release APK (~60 MB)
- Course content: `app/assets/course/` (72 lessons + index.json + verbs.json)
- Audio: `app/assets/audio/` (7,857 offline .opus clips, MD5-keyed, 100% coverage)

---

## Speak offline — one-time setup

Conversation practice uses the phone's speech recognizer. Lessons, audio, and scoring are fully offline; only the **system STT engine** needs an offline language pack if you want zero network during speaking exercises:

1. **Download the offline speech pack** (once, while online):
   - **Settings → Google → Search, Assistant & Voice → Voice → Offline speech recognition** → tab **All** → install **Spanish (Spain)**
   - Or: **Google app → profile picture → Settings → Voice → Offline speech recognition**
   - If the menu moved (Gemini era), search **"Offline speech"** in the phone Settings search bar
   - Alternate paths on some devices: `Settings → System → Languages & input → Voice input` or `Gboard → Voice typing → Offline speech recognition`
2. **Keep Speech Services by Google enabled and updated** (Settings → Apps → show system → *Speech Services by Google*).
3. **Default voice input** = *Speech services by Google*: Settings → Apps → Default apps → Digital assistant app → Voice input.
4. **Grant the app the microphone**: Settings → Apps → *Talk To Me Spanish* → Permissions → Microphone → **Allow**. The app also shows a rationale dialog the first time you tap **Speak**.
5. **No TTS voice download is needed** — all lesson audio is bundled `.opus` files.
6. Optional check: enable airplane mode and speak once. If it fails with *language unavailable*, the offline pack from step 1 is missing.

> The app itself declares **no INTERNET permission** and makes no network calls. Speech recognition runs inside Google's system service; with the offline pack installed it stays on-device.

---

## Conversation mode

Open any lesson → **Practice conversation** (under the dialogue):

- **Roleplay**: the partner's lines auto-play (bundled audio + ES/EN/AR text); tap **Your turn** and answer with the mic.
- **Free Q&A**: when the partner asks a question, speak a natural answer — scored against the scripted reply *and* related exercise answers (short answers like *"¡Claro!"* still pass via containment scoring).
- **Score tiers**: ≥90 pass (green) · 50–89 retry (orange) · &lt;50 try again (red). Expected vs heard shown on the score card.
- **Manual fallback**: if the mic or STT is unavailable, use *Hablé / I spoke* self-grading, **Retry microphone**, or **Settings** (opens app permissions).
- **Offline**: works without internet when the offline speech pack is installed (see above). Web build: browser STT only; local voice recording is hidden.

---

## Run anywhere (portable, no install)

Copy this whole folder to any PC (USB, cloud drive, network share). No Flutter, no dependencies — **Python 3** (or just Windows PowerShell for the built-in server) — works fully offline (CanvasKit + all 7,857 audio clips are bundled; the service worker even pre-caches them on first run):

- **Linux/macOS**: open a terminal in this folder and run `bash RUN.sh`
- **Windows**: double-click `RUN.bat` (uses Python; falls back to a built-in PowerShell server when Python is not installed)

It serves the prebuilt web app (`app/build/web`) and opens your browser automatically. Use Chrome or Edge (Safari cannot play .opus audio).

---

## Features

- 72 CEFR lessons (A1-C2) with vocabulary, grammar, dialogue, reading, exercises
- **Voice conversation practice**: turn-based roleplay, free spoken Q&A, offline STT scoring (≥90/50 tiers), manual fallback
- 1,816 Spanish verbs with 8 tenses (present, preterite, imperfect, future, conditional, subjunctive, subjunctive past, imperative)
- Verb conjugation browser with type grouping (-AR/-ER/-IR/-OR/irregular)
- Audio filter toggle (All / With Audio) on verb screen
- Bottom navigation bar (Inicio / Cartas / Verbos / Estadisticas / Cuenta)
- 17 achievement badges with unlock tracking
- Common Verbs filter with color-coded conjugation type badges (-AR/-ER/-IR)
- Enhanced verb detail screen with summary header
- Speaking exercises with progress bar and redo option
- Account screen with export/import/share/clear data
- Trilingual display: Spanish + English + Arabic (RTL support)
- TTS audio via Microsoft Edge voices (es-UY-ValentinaNeural)
- FSRS spaced repetition flashcard system
- Level-based quizzes with best score tracking
- Pinch-to-zoom everywhere
- Dark/Light/System theme
- Home screen widget (streak, due count)
- PDF export of lessons
- Favorites/bookmarks
- Global content search
- Data export/import (JSON backup)
- Web support — run in browser
- `build-all.sh` — one command builds APK + web
- 79/79 tests passing, 0 analyze issues

---

## 1. Repository Layout

```
espanol-zero-to-hero/
├── app/                        # Flutter project
│   ├── lib/                    # Dart code (37 files)
│   │   ├── main.dart           # Entry point
│   │   ├── models/             # Data models (TriText, Lesson, VerbInfo, etc.)
│   │   ├── screens/            # 17 screens (Home, Lesson, Flashcard, Quiz, Verb, etc.)
│   │   ├── services/           # 13 services (Audio, Progress, FSRS, etc.)
│   │   └── widgets/            # 6 reusable widgets (AudioButton, TriBlock, etc.)
│   ├── assets/
│   │   ├── course/             # JSON lesson data + verbs.json
│   │   └── audio/              # ~5,932 .opus TTS files
│   ├── android/                # Android native (Kotlin, Gradle)
│   │   └── app/
│   │       ├── build.gradle.kts
│   │       ├── release.keystore    # LOCAL dev keystore (gitignored)
│   │       └── src/main/kotlin/    # 6 Kotlin files (widget, notifications)
│   └── test/                   # 55 unit + widget tests
├── tools/                      # Python content pipeline (19 scripts)
│   ├── gen_audio.py            # Audio generation (edge-tts)
│   ├── build_verbs.py          # Verb conjugation builder
│   ├── build_index.py          # Search index builder
│   ├── apply_es.py             # Spanish content adjustments
│   ├── es_ipa.py               # Spanish IPA pronunciation
│   ├── extract_es.py           # Spanish content extraction
│   └── content_a1.py .. c2.py  # Level content generators
├── .github/workflows/build.yml # GitHub Actions DevSecOps pipeline
├── .gitlab-ci.yml              # GitLab CI DevSecOps pipeline
├── Dockerfile                  # 8-stage multi-stage build
├── docker-compose.yml          # 6 services (builder, scanner, signer, etc.)
├── .gitignore                  # 140 lines (Flutter + security + Docker)
├── .dockerignore               # 147 lines (keeps app/assets/ for build)
├── .gitleaks.toml              # Secret scanning rules (296 lines)
├── .pre-commit-config.yaml     # Pre-commit hooks (206 lines)
├── .github/dependabot.yml      # Auto-dependency updates
├── CONTRIBUTING.md             # Contribution guidelines
├── SECURITY.md                 # Security policy
├── LICENSE                     # Apache-2.0
└── NOTICE                      # Attribution
```

---

## 2. Local Development from 0

### Prerequisites

| Tool | Version | Install |
|------|---------|---------|
| **Flutter SDK** | 3.29.3 | https://docs.flutter.dev/get-started/install/linux |
| **JDK** | 17 | `sudo apt install openjdk-17-jdk` |
| **Android SDK** | cmdline-tools | https://developer.android.com/studio#command-line-tools-only |
| **Git** | latest | `sudo apt install git` |

> **IMPORTANT**: JDK 25 breaks the Kotlin Gradle plugin. Always use JDK 17.

### Step-by-step

```bash
# 1. Install Flutter SDK
cd /opt
curl -sL "https://storage.googleapis.com/flutter_infra_release/releases/stable/linux/flutter_linux_3.29.3-stable.tar.xz" | tar xJ
export PATH="/opt/flutter/bin:$PATH"
flutter doctor -v

# 2. Install JDK 17
sudo apt update && sudo apt install -y openjdk-17-jdk
export JAVA_HOME=/usr/lib/jvm/java-17-openjdk-amd64

# 3. Install Android SDK
mkdir -p ~/android-sdk/cmdline-tools
cd ~/android-sdk/cmdline-tools
curl -sL "https://dl.google.com/android/repository/commandlinetools-linux-11076708_latest.zip" -o tools.zip
unzip tools.zip && mv cmdline-tools latest
export ANDROID_HOME=~/android-sdk
export PATH="$ANDROID_HOME/cmdline-tools/latest/bin:$ANDROID_HOME/platform-tools:$PATH"
yes | sdkmanager --licenses
sdkmanager "platforms;android-34" "build-tools;34.0.0" "ndk;27.0.12077973"

# 4. Clone and build
git clone https://github.com/rafaabou/espanol-zero-to-hero.git
cd espanol-zero-to-hero/app
flutter pub get
flutter analyze              # Must be 0 issues
flutter test                 # Must pass 79 tests

# 5. Build release APK
JAVA_HOME=/usr/lib/jvm/java-17-openjdk-amd64 \
  flutter build apk --release --obfuscate --split-debug-info=build/debug-info --target-platform android-arm64
# Output: build/app/outputs/flutter-apk/app-release.apk

# 6. Install on phone via ADB
adb install build/app/outputs/flutter-apk/app-release.apk
```

### Development commands

```bash
cd app
flutter pub get              # Install dependencies
flutter run                  # Run on device/emulator
flutter analyze              # Static analysis (must be 0 issues)
flutter test                 # Run 79 tests
dart format --set-exit-if-changed --output=none .  # Format check
```

---

## 3. Self-Hosted GitHub Runner from 0

### Step 1: Prepare the machine

```bash
# Ubuntu 22.04+ recommended
sudo apt update && sudo apt install -y curl git unzip xz-utils zip \
  openjdk-17-jdk libglu1-mesa

# Install Flutter
cd /opt
curl -sL "https://storage.googleapis.com/flutter_infra_release/releases/stable/linux/flutter_linux_3.29.3-stable.tar.xz" | tar xJ
export PATH="/opt/flutter/bin:$PATH"
flutter doctor -v

# Install Android SDK
mkdir -p /opt/android-sdk/cmdline-tools
cd /opt/android-sdk/cmdline-tools
curl -sL "https://dl.google.com/android/repository/commandlinetools-linux-11076708_latest.zip" -o tools.zip
unzip tools.zip && mv cmdline-tools latest
export ANDROID_HOME=/opt/android-sdk
export PATH="$ANDROID_HOME/cmdline-tools/latest/bin:$ANDROID_HOME/platform-tools:$PATH"
yes | sdkmanager --licenses
sdkmanager "platforms;android-34" "build-tools;34.0.0" "ndk;27.0.12077973"

# Install Docker (for security scanning)
curl -fsSL https://get.docker.com | sh
```

### Step 2: Download GitHub Actions runner

```bash
mkdir -p ~/actions-runner && cd ~/actions-runner
curl -sL "https://github.com/actions/runner/releases/download/v2.321.0/actions-runner-linux-x64-2.321.0.tar.gz" -o runner.tar.gz
tar xzf runner.tar.gz
```

### Step 3: Configure with labels

```bash
./config.sh \
  --url https://github.com/rafaabou/espanol-zero-to-hero \
  --token <YOUR_TOKEN> \
  --labels "self-hosted,linux,X64,spanish" \
  --name "espanol-runner" \
  --work ~/actions-runner-work
```

### Step 4: Install as service

```bash
sudo ./svc.sh install
sudo ./svc.sh start
sudo ./svc.sh status
```

### Step 5: Set repository secrets

Go to GitHub repo → Settings → Secrets and variables → Actions → New repository secret:

| Secret | Value |
|--------|-------|
| `RELEASE_KEYSTORE_BASE64` | `base64 -w0 release.keystore` (optional, ephemeral if absent) |

### Step 6: Test

Push to `main` or create a PR. The pipeline should trigger on the self-hosted runner.

---

## 4. Self-Hosted GitLab Runner from 0

### Step 1: Install runner

```bash
# Download GitLab Runner binary
curl -L "https://packages.gitlab.com/install/repositories/runner/gitlab-runner/script.deb.sh" | sudo bash
sudo apt install gitlab-runner

# Or manual install
curl -sL "https://gitlab-runner-downloads.s3.amazonaws.com/latest/binaries/gitlab-runner-linux-amd64" -o /usr/local/bin/gitlab-runner
chmod +x /usr/local/bin/gitlab-runner
```

### Step 2: Register with tags

```bash
sudo gitlab-runner register \
  --non-interactive \
  --url "https://gitlab.com/" \
  --registration-token "<YOUR_TOKEN>" \
  --executor "shell" \
  --shell "bash" \
  --tag-list "spanish" \
  --run-untagged="true" \
  --locked="false"
```

### Step 3: Set CI/CD variables

Go to GitLab repo → Settings → CI/CD → Variables → Add:

| Variable | Value | Protected | Masked |
|----------|-------|-----------|--------|
| `RELEASE_KEYSTORE_BASE64` | `base64 -w0 release.keystore` | No | Yes |
| `MOBSF_API_KEY` | (optional) | No | Yes |

### Step 4: Test

Push to `main`. The pipeline should trigger on the `spanish`-tagged runner.

---

## 5. GitHub Actions Pipeline

**File**: `.github/workflows/build.yml`
**Triggers**: push/PR to `main`, `develop`; tag `v*`; manual dispatch
**Runner**: ubuntu-latest (validate/build/package/release) + matrix ubuntu/windows/macos (desktop)

### Pipeline Stages

```
┌──────────┐    ┌──────────┐    ┌──────────┐    ┌──────────┐
│ validate │───→│  build   │───→│ package  │───→│ release  │
│   (30m)  │    │   (90m)  │    │   (45m)  │    │   (20m)  │
└────┬─────┘    └──────────┘    └──────────┘    └──────────┘
     │         ┌──────────┐
     └────────→│ desktop  │───→│ release  │
               │ (90m ×3) │    │          │
               └──────────┘    └──────────┘
```

| Stage | Job | What It Does |
|-------|-----|--------------|
| **validate** | `validate` | Format check, `flutter analyze --fatal-infos`, `flutter test`, license check, gitleaks, TruffleHog, dependency audit |
| **build** | `build` | Restore keystore (or ephemeral), build obfuscated arm64 APK, size check, Hadolint Dockerfile lint, Docker image build, Grype scan, Syft SBOM, Trivy scan, Dockle scan |
| **desktop** | `desktop` (matrix) | Build Linux (ubuntu-latest), Windows (windows-2022), macOS (macos-latest); upload bundles as artifacts. Heavy steps run only with `[desktop]` in push message or on `v*` tags — normal pushes skip them (~150 billed min saved) |
| **package** | `package` | Restore keystore, rebuild APK, generate SBOMs (project + APK), Grype APK scan (`--fail-on high`), Cosign keyless signing, upload to GitHub Release |
| **release** | `release` | Create git tag, create GitHub Release with APK, signatures, SBOMs, and desktop zips (Linux/Windows/macOS) |

### Required GitHub Secrets

| Secret | Required | Purpose |
|--------|----------|---------|
| `RELEASE_KEYSTORE_BASE64` | Optional | `base64 -w0 release.keystore`. If absent, ephemeral keystore is generated. |
| `GITHUB_TOKEN` | Automatic | Provided by Actions for releases. |

---

## 6. GitLab CI Pipeline

**File**: `.gitlab-ci.yml`
**Triggers**: push to `main`, `develop`, tags `v*`
**Runner**: tagged with `spanish`

### Pipeline Stages

| Stage | Jobs | What It Does |
|-------|------|--------------|
| **validate** | `validate`, `hadolint` | Format, analyze, test, secrets, dependency audit, Dockerfile lint |
| **build** | `build` | APK + Docker image + security scans (Hadolint, Grype, Syft, Trivy, Dockle) |
| **package** | `package` | SBOM generation, Grype APK scan, Cosign signing, GitLab Release upload |
| **release** | `release` | GitLab Release creation with tag |

### Required GitLab CI/CD Variables

| Variable | Required | Purpose |
|----------|----------|---------|
| `RELEASE_KEYSTORE_BASE64` | Optional | Stable signing across builds |
| `MOBSF_API_KEY` | Optional | Enable MobSF dynamic analysis job |

---

## 7. Docker

### Dockerfile (9-Stage Build)

```dockerfile
# Stage 1: base          — Ubuntu 22.04 + JDK 17 + Python 3
# Stage 2: flutter-sdk   — Flutter 3.29.3 + Android SDK + NDK
# Stage 3: security-tools — Grype, Syft, Trivy, Cosign, gitleaks
# Stage 4: builder       — Flutter APK build (obfuscated, arm64)
# Stage 5: scanner       — SBOM generation + vulnerability scanning
# Stage 6: signer        — Cosign keyless signing
# Stage 7: artifacts     — Final artifact image (scratch)
# Stage 8: runtime       — Testing image with APK
# Stage 9: web           — Flutter web build + Python HTTP server
```

### docker-compose.yml (7 Services)

```yaml
services:
  builder:      # Compiles APK with Flutter + Android SDK
  scanner:      # Security scanning (Grype, Trivy, MobSF)
  scanner-ci:   # CI-mode scanner (--fail-on high)
  signer:       # Signs APKs and SBOMs with Cosign
  runtime:      # Testing on device/emulator (KVM passthrough)
  dev:          # Hot-reload development (web server on port 5000)
  web:          # Runs app in browser (port 8002)
```

### Usage

```bash
# Build APK via Docker
docker compose build builder
docker compose run --rm builder

# Security scan
docker compose build scanner-ci
docker compose run --rm scanner-ci

# Development (hot reload)
docker compose --profile dev up dev

# Run web version in Docker
docker compose --profile web up web
# Open http://localhost:8002

# Release signing
docker compose --profile release up signer
```

### Volumes

- `flutter-cache`: `/root/.pub-cache` (Dart packages)
- `gradle-cache`: `/root/.gradle` (Gradle build cache)
- `artifacts`: Build outputs
- `signatures`: Cosign signatures
- `sbom`: SBOM files
- `sarif`: SARIF scan reports

> `.dockerignore` deliberately KEEPS `app/assets/` (course content + audio compiled into APK)
> and `pubspec.lock` (reproducible `--enforce-lockfile` installs).

---

## 8. Every Folder Explained

### `app/` — Flutter Application

The main Flutter project containing all source code, assets, and Android configuration.

### `app/lib/` — Dart Source Code

37 Dart files organized into 4 directories:

| Directory | Files | Purpose |
|-----------|-------|---------|
| `lib/` | 1 | `main.dart` — entry point, theme, Provider setup |
| `lib/models/` | 2 | Data models: `course_models.dart` (TriText, Lesson, etc.), `verb_models.dart` (VerbInfo, VerbData) |
| `lib/services/` | 13 | Business logic: AppState, AudioService, ProgressService, FSRS, etc. |
| `lib/screens/` | 17 | UI screens: Home, Lesson, Flashcard, Quiz, Verb, Grammar, Search, Stats, etc. |
| `lib/widgets/` | 6 | Reusable widgets: AudioButton, WordTapText, TriBlock, TrText, etc. |

### `app/assets/course/` — Course Content

- `levels/index.json` — Level metadata (A1-C2 with lesson lists)
- `levels/A1-01.json` .. `C2-12.json` — 72 individual lesson files
- `index.json` — Search index (vocabulary, grammar, dialogue, reading)
- `verbs.json` — 1,816 verbs × 8 tenses

### `app/assets/audio/` — TTS Audio Files

~5,932 `.opus` files. Named by MD5 hash: `md5(lang:text)[:12].opus`.
Generated by `tools/gen_audio.py` using Microsoft Edge TTS (es-UY-ValentinaNeural).

### `app/android/` — Android Native Code

- `app/build.gradle.kts` — App config (minSdk 24, signing, NDK)
- `app/release.keystore` — LOCAL dev keystore (gitignored)
- `app/src/main/kotlin/` — 6 Kotlin files:
  - `MainActivity.kt` — MethodChannel for widget communication
  - `BootReceiver.kt` — Reschedules notifications on boot
  - `NotificationService.kt` — Daily reminder management
  - `NotificationReceiver.kt` — Shows study reminders
  - `EszeroWidgetProvider.kt` — Home screen widget
  - `WidgetConfigureActivity.kt` — Widget configuration

### `tools/` — Python Content Pipeline

19 Python scripts for building course content:

| Script | Purpose |
|--------|---------|
| `build_verbs.py` | Generate verbs.json from conjugation data |
| `build_index.py` | Generate index.json from lesson JSONs |
| `gen_audio.py` | Generate .opus audio via edge-tts |
| `build_content.py` | Build course content |
| `augment_content.py` | Augment existing content |
| `apply_es.py` | Spanish-specific content adjustments |
| `es_ipa.py` | Spanish IPA pronunciation data |
| `extract_es.py` | Spanish content extraction |
| `content_a1.py` .. `c2.py` | Level-specific content generators |
| `schema.py` | JSON schema definitions |
| `course_map.json` | Course structure mapping |
| `mobsf_scan.py` | MobSF security scanning |

### `.github/workflows/` — GitHub Actions

`build.yml` — 5-job DevSecOps pipeline (validate → build + desktop matrix → package → release).

### `.gitlab-ci.yml` — GitLab CI

5-job DevSecOps pipeline (validate → build + desktop-linux → package → release).

---

## 9. Every Config File Explained

| File | Lines | Purpose |
|------|-------|---------|
| `.gitignore` | 140 | Excludes security reports, SBOMs, signatures, keystores, Docker artifacts, IDE files, Flutter build artifacts, Python tooling, secrets |
| `.dockerignore` | 147 | Excludes everything except `app/assets/` (must ship in image) and `pubspec.lock` |
| `.gitleaks.toml` | 296 | Secret scanning rules: allowlists for config files, false positive patterns, rules for API keys, JWT tokens, SSH keys, etc. |
| `.pre-commit-config.yaml` | 206 | Pre-commit hooks: dart-format, flutter-analyze, gitleaks, trufflehog, license-check, pub-outdated, dart-linter, trailing-whitespace, check-yaml/json |
| `docker-compose.yml` | 161 | 7 services: builder, scanner, scanner-ci, signer, runtime, dev, web. Named volumes for caching. |
| `Dockerfile` | 210 | 9-stage multi-stage build: base → flutter-sdk → security-tools → builder → scanner → signer → artifacts → runtime → web |
| `app/pubspec.yaml` | 34 | Flutter dependencies: just_audio, shared_preferences, provider, crypto, pdf, fl_chart, share_plus |
| `app/analysis_options.yaml` | 28 | Dart linter config (flutter_lints) |
| `app/lic_ck.yaml` | 14 | License checker: MIT, BSD, Apache-2.0, ISC, MPL-2.0 permitted |
| `app/android/app/build.gradle.kts` | 54 | App config: minSdk 24, NDK 27, signing from env vars, minification enabled |
| `.github/dependabot.yml` | 80 | Auto-dependency updates: pub (weekly), github-actions (weekly), docker (weekly) |
| `.github/workflows/build.yml` | ~468 | GitHub Actions: validate → build + desktop (matrix) → package → release. ubuntu/windows/macos. |
| `.gitlab-ci.yml` | ~215 | GitLab CI: validate → build + desktop-linux → package → release. Tagged runners. |
| `SECURITY.md` | 186 | Security policy: vulnerability reporting, architecture, build security, compliance |
| `CONTRIBUTING.md` | 318 | Contribution guidelines: setup, coding standards, PR process, testing |

---

## 10. Configuration Reference

| Setting | Where | Default |
|---------|-------|---------|
| Flutter version | workflow env / GitLab variables / Dockerfile ARG | 3.29.3 |
| Java version | workflows / Dockerfile | 17 |
| App ID | `app/android/app/build.gradle.kts` | `com.rafaabou.eszero_hero` |
| Version | `app/pubspec.yaml` (`version:`) | 1.10.0+14 |
| Min SDK | `app/android/app/build.gradle.kts` | 24 |
| NDK | `app/android/app/build.gradle.kts` | 27.0.12077973 |
| UI languages | In-app switcher | en / es / ar (RTL) |
| Audio voice | `tools/gen_audio.py` | es-UY-ValentinaNeural |
| Runner labels (GH) | `.github/workflows/build.yml` | ubuntu-latest + windows-2022 + macos-latest (desktop matrix) |
| Runner labels (GitLab) | `.gitlab-ci.yml` | spanish |
| Export file | In-app export | `espanol_progress.json` |

---

## 11. Security Notes

- **Offline-first**: No network calls from the app. No `INTERNET` permission. No analytics. No tracking.
- **Microphone**: `RECORD_AUDIO` is declared solely for conversation practice (on-device scoring); recordings stay in the app temp dir and are cleaned up.
- **Speech recognition**: runs in the system Speech Services process (Google); with the offline pack installed, recognition stays on-device — see *Speak offline — one-time setup*.
- **Secret scanning**: Gitleaks + TruffleHog run on every push. Enable locally with `pre-commit install`.
- **Keystore**: `*.keystore` / `*.jks` / `keystore.properties` are never committed (gitignored).
- **Dev fallback**: `build.gradle.kts` falls back to password `release123` when env vars are unset.
- **Supply chain**: Every release gets Syft SBOM, Grype scan, Cosign keyless signature.
- **Docker**: 8-stage build with security scanning at each stage.
- **Compliance**: OWASP MASVS Level 1, GDPR compliant (no personal data).

See `SECURITY.md` for the full security policy and vulnerability reporting process.

---

## 12. Verify Before Push

```bash
cd app
flutter analyze              # Must be 0 issues
flutter test                 # Must pass 79 tests
git status                   # Nothing unintended staged
dart format --set-exit-if-changed --output=none .  # Format check
gitleaks detect --no-git -c .gitleaks.toml         # Optional local secret scan
```

---

## License

Apache-2.0 — see `LICENSE` and `NOTICE`.

---

## Changelog

### v1.10.0 (2026-09-22)
- **Voice conversation mode**: turn-based roleplay (partner auto-plays, you answer) + free spoken Q&A scored against accepted answers
- Mic rationale dialog, Retry-microphone, Open Settings on permission failure
- Offline-first STT (`onDevice` try + automatic fallback); offline-pack error copy with Settings path
- Score card: expected vs heard + accepted alternatives; haptics on result
- STT init no longer permanently fails after one error; model audio stops before listening
- Temp voice-recording cleanup; macOS mic/speech usage strings; `app_settings` dep
- README: offline STT pack setup, conversation docs, security note for RECORD_AUDIO

### v1.8.0 (2026-09-12)
- Unique example phrases for all 1,190 vocab words (ES/EN/AR) with per-word audio buttons
- +8 exercises per lesson (576 new): 4 multiple choice + 4 translation each
- Fixed Portuguese leftovers in ES exercise en/ar fields; Spanish alphabet answer 27 letters
- Render-level duplicate exercise removal (saved progress keys preserved)
- Reorder exercises: stable drag keys + Check button (parity with PT)
- Quiz seen-set dedup; full TTS audio fill — 7,857 clips, lint 0 missing
- TTS audio voice: es-ES-AlvaroNeural for new clips

### v1.7.0 (2026-09-10)

### v1.6.0 (2026-09-09)
- Desktop apps for Linux, Windows, and macOS (Flutter desktop runners + CI matrix builds)
- Web audio fix — .opus playback via HTML5 AudioElement with blob URLs
- serve_web.py ships correct MIME types for .opus audio and fonts
- Dockerfile web stage, build-all.sh, and start-server.sh use serve_web.py
- Version display fixed (app About screen + web landing page)

### v1.5.0 (2026-09-08)
- Bottom navigation bar (Inicio / Cartas / Verbos / Estadisticas / Cuenta)
- 17 achievement badges with unlock tracking
- Common Verbs filter with color-coded type badges
- Enhanced verb detail screen with summary header
- Speaking exercises with progress bar and redo option
- Account screen with export/import/share/clear data
- Flashcard and quiz review counters
- Better empty states across all screens

### v1.4.3 (2026-09-07)
- Web support — run directly in your browser
- CI/CD now builds on GitHub-hosted runners (ubuntu-latest)

### v1.4.2 (2026-09-01)
- Audio filter toggle (All / With Audio) on verb screen
- 1,816 verbs with 8 tenses (present, preterite, imperfect, future, conditional, subjunctive, subjunctive past, imperative)
- Verb conjugation grouping by type (-AR/-ER/-IR/-OR/irregular)
- Audio icon badges for verbs with full audio
- Fixed unnecessary non-null assertion in verb_screen.dart

### v1.4.1 (2026-08-31)
- hasFullAudio flag: 59 verbs with full audio
- Verb audio filter support

### v1.4.0 (2026-08-31)
- 8 tenses (added subjunctive_past + imperative)
- EN/AR translations for all verbs
- Verb grouping by conjType
- Trilingual tense names

### v1.3.0 (2026-08-31)
- Flashcard review with FSRS spaced repetition
- Quiz mode with best score tracking
- Verb conjugation browser
- Pinch-to-zoom everywhere
- Dark/Light/System theme

### v1.2.0 (2026-08-31)
- Reset progress with confirmation dialog
- Localized UI strings for pt/es/ar
- Match-pair quiz UI
- Exercise deduplication (2944 -> 1231)
- Dynamic lesson count

---

**Maintainer**: Mohamed Rafaa Tounekti
**Repository**: https://github.com/rafaabou/espanol-zero-to-hero
**Architecture**: See [ARCHITECTURE.md](ARCHITECTURE.md) for complete technical reference.
