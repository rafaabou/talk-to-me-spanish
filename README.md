# Talk To Me Spanish By Mohamed Rafaa Tounekti

![Flutter](https://img.shields.io/badge/Flutter-3.29.3-blue?logo=flutter)
![Dart](https://img.shields.io/badge/Dart-3.7.2-blue?logo=dart)
![License](https://img.shields.io/badge/License-Apache_2.0-green)
![Android](https://img.shields.io/badge/Android-21%2B-green?logo=android)
![Security](https://img.shields.io/badge/Security-DevSecOps-brightgreen)
![Offline](https://img.shields.io/badge/Offline-First-orange)

**Talk To Me Spanish** is a complete offline Spanish language learning app for Portuguese speakers. Learn Spanish from A1 (beginner) to C2 (mastery) with interactive lessons, vocabulary, grammar, dialogues, and exercises — all 100% offline.

---

## 📱 Screenshots

| Home | Lessons | Vocabulary | Exercises |
|------|---------|------------|-----------|
| ![Home](screenshots/home.png) | ![Lessons](screenshots/lessons.png) | ![Vocab](screenshots/vocab.png) | ![Exercises](screenshots/exercises.png) |

---

## ✨ Features

### 🎓 **Complete Curriculum (A1–C2)**
- **72 lessons** across 6 CEFR levels (A1, A2, B1, B2, C1, C2)
- Progressive difficulty from basics to mastery
- Each lesson: Objectives → Vocabulary → Grammar → Dialogue → Reading → Exercises

### 🧠 **Smart Learning**
- **Spaced Repetition (FSRS)** — Intelligent flashcard algorithm adapts to your progress
- **Configurable repetition** — 1×, 3×, 7×, 10× review cycles
- **Streak tracking** — Daily study streaks with calendar heatmap
- **Progress analytics** — Lesson completion, exercise accuracy, streak stats

### 📚 **Rich Content**
- **Vocabulary** — 1000+ words with IPA pronunciation, examples, audio
- **Grammar** — Interactive explanations with expandable sections, audio examples
- **Dialogues** — Real conversations with speaker labels, audio playback
- **Reading** — Comprehension texts with translations (ES/EN/AR)
- **Exercises** — Multiple choice, fill-in-blank, listening, reordering, matching
- **Speaking** — Repeat-after-me with audio recording

### 🌍 **Multilingual Support**
| Language | Code | Status |
|----------|------|--------|
| Spanish | `es` | ✅ Primary |
| English | `en` | ✅ Full |
| Arabic | `ar` | ✅ RTL support |
| Portuguese | `pt` | ✅ Source language |

### 🔒 **Privacy & Security**
- **100% Offline** — No internet required, no data leaves your device
- **No tracking** — No analytics, no ads, no user accounts
- **Local storage only** — SharedPreferences for progress
- **Signed releases** — Cosign signatures, SLSA provenance
- **Obfuscated builds** — R8 minification + Dart obfuscation

---

## 🚀 Quick Start

You can build the app in **three ways**:
- **Option A** — Build locally on your machine
- **Option B** — Build via GitHub Actions (CI/CD)
- **Option C** — Build via GitLab CI/CD

### Prerequisites
- Android 5.0+ (API 21+)
- 100MB free storage (includes audio assets)

### Option A: Build Locally

```bash
# 1) Prerequisites
flutter --version  # 3.29.3+
java --version     # 17+

# 2) Install dependencies
cd app
flutter pub get

# 3) Run static analysis + tests (same checks CI runs)
flutter analyze --fatal-infos
flutter test
dart format --set-exit-if-changed --output=none .

# 4) Build the release APK
flutter build apk --release --obfuscate --split-debug-info=build/debug-info

# 5) Install on a connected device/emulator
flutter install
# or manually:
# adb install -r build/app/outputs/flutter-apk/app-release.apk
```

> **Note:** The release build is signed automatically using `android/app/release.keystore`
> (already present locally, never committed). If you don't have it, the build falls back to
> reading the environment variables `RELEASE_KEYSTORE_PATH`, `RELEASE_KEYSTORE_PASSWORD`,
> `RELEASE_KEY_ALIAS`, `RELEASE_KEY_PASSWORD`.

### Option B: Build via GitHub Actions (CI/CD)

The repository includes a full DevSecOps pipeline in `.github/workflows/build.yml`.
It runs automatically on every `push`/`pull_request` to `main` or `develop`.

**Pipeline stages:**
```
Validate → Build → Scan → Package → Release
   │         │       │        │        │
   ▼         ▼       ▼        ▼        ▼
Format    Build    Grype    Sign      GitHub
Analyze   APKs     Trivy    Cosign    Release
Tests     Obfusc.  SBOM     SLSA      Assets
License   Minify            Proven.
Gitleaks
TruffleHog
```

**What you need to do:**
1. **Enable GitHub Actions** — already on by default for GitHub repos.
2. **Add the signing secret** so releases are signed with your real keystore:
   ```bash
   gh secret set RELEASE_KEYSTORE_BASE64 \
     --repo rafaabou/talk-to-me-spanish \
     --body "$(base64 -w0 app/android/app/release.keystore)"
   ```
   > If the secret is not set, CI generates an *ephemeral* keystore and the build still
   > completes (APK will be debug-signed — fine for testing, not for production releases).
3. **Watch the run:**
   ```bash
   gh run list --repo rafaabou/talk-to-me-spanish
   gh run watch --repo rafaabou/talk-to-me-spanish
   ```
4. **Create a release** by tagging a version:
   ```bash
   git tag v1.0.0
   git push origin v1.0.0
   ```
   This triggers the `release` job, which attaches the signed APK, SBOMs and signatures
   to a GitHub Release page.

**Required GitHub Secrets:**
| Secret | Purpose | Required |
|--------|---------|----------|
| `RELEASE_KEYSTORE_BASE64` | Base64 of `release.keystore` | Yes (production signing) |

### Option C: Build via GitLab CI/CD

The repository also includes a full DevSecOps pipeline in `.gitlab-ci.yml`.
It runs automatically on every `push`/`merge_request` to `main` or `develop`.

**Pipeline stages (`.gitlab-ci.yml`):**
```
validate → build → scan → package → release
   │         │       │        │        │
   ▼         ▼       ▼        ▼        ▼
Format    Build    Grype    Sign      GitLab
Analyze   APKs     Trivy    Cosign    Release
Tests     Obfusc.  SBOM     SLSA      Assets
License   Minify   MobSF    Proven.
Gitleaks
TruffleHog
```

**What you need to do:**
1. **Push the repository to GitLab** (create a new project, then):
   ```bash
   git remote add gitlab git@gitlab.com:YOUR_USERNAME/talk-to-me-spanish.git
   git push -u gitlab main
   ```
2. **Add the signing variable** so releases are signed with your real keystore:
   ```bash
   # In GitLab → Settings → CI/CD → Variables, add:
   RELEASE_KEYSTORE_BASE64 = "$(base64 -w0 app/android/app/release.keystore)"
   ```
   > Optional: `MOBSF_API_KEY` and `MOBSF_URL` enable the (manual) MobSF job.
   > If the keystore variable is not set, CI generates an *ephemeral* keystore and the
   > build still completes (APK will be debug-signed).
3. **Watch the pipeline:**
   ```bash
   # In GitLab → CI/CD → Pipelines, or via the GitLab CLI
   glab ci list
   glab ci status
   ```
4. **Create a release** by tagging a version:
   ```bash
   git tag v1.0.0
   git push gitlab v1.0.0
   ```
   This triggers the `release` job, which creates a GitLab Release with the signed APK,
   SBOMs and signatures.

**Required GitLab CI/CD Variables:**
| Variable | Purpose | Required |
|----------|---------|----------|
| `RELEASE_KEYSTORE_BASE64` | Base64 of `release.keystore` | Yes (production signing) |
| `MOBSF_API_KEY` | MobSF API key | No (optional manual scan) |
| `MOBSF_URL` | MobSF instance URL | No (optional manual scan) |

### Updating Both Language Apps (Spanish + Portuguese)

The Spanish and Portuguese apps are **separate repositories** with identical structure:
- `talk-to-me-spanish` → `app/` (Spanish, `com.rafaabou.eszero_hero`)
- `talk-to-me-portugues` → `app/` (Portuguese, `com.rafaabou.ptbr_zero_to_hero`)

When you make a change, apply it **in both repos**:

```bash
# 1) Edit the source file in the Spanish repo, e.g.
cd "/path/to/espanol-zero-to-hero/app"
# ...make your changes...

# 2) Apply the SAME change to the Portuguese repo
cd "/path/to/ptbr-zero-to-hero/app"
# ...make the identical change...

# 3) Verify BOTH apps (analyze + tests + format)
cd "/path/to/espanol-zero-to-hero/app" && flutter analyze && flutter test
cd "/path/to/ptbr-zero-to-hero/app"   && flutter analyze && flutter test

# 4) Commit & push each repo separately
cd "/path/to/espanol-zero-to-hero"
git add -A && git commit -m "feat: ..." && git push origin main

cd "/path/to/ptbr-zero-to-hero"
git add -A && git commit -m "feat: ..." && git push origin main

# 5) Confirm both CI pipelines pass
gh run list --repo rafaabou/talk-to-me-spanish
gh run list --repo rafaabou/talk-to-me-portugues
```

> **Important:** Changes to the app name, description, or labels are in:
> `app/pubspec.yaml`, `app/lib/main.dart`, `app/android/app/src/main/AndroidManifest.xml`.
> Keep the two apps' texts in their own language (Spanish app → Spanish content,
> Portuguese app → Portuguese content).

---

## 🏗️ Architecture

```
lib/
├── main.dart                    # App entry point
├── models/                      # Data models (Lesson, VocabWord, etc.)
├── screens/                     # UI screens
│   ├── home_screen.dart
│   ├── lesson_list_screen.dart
│   ├── lesson_screen.dart
│   ├── flashcard_screen.dart
│   ├── quiz_screen.dart
│   ├── search_screen.dart
│   ├── favorites_screen.dart
│   ├── grammar_screen.dart
│   ├── verb_screen.dart
│   ├── stats_screen.dart
│   └── onboarding_screen.dart
├── widgets/                     # Reusable UI components
├── services/                    # Business logic
│   ├── app_state.dart           # Global state (theme, lang, speed)
│   ├── audio_service.dart       # Audio playback
│   ├── course_repository.dart   # Lesson content loading
│   ├── progress_service.dart    # Progress persistence
│   ├── notification_service.dart # Local notifications
│   └── pdf_export_service.dart  # Lesson PDF export
└── utils/                       # Helpers
```

### Key Technologies
| Layer | Technology |
|-------|------------|
| UI | Flutter 3.29, Material 3 |
| State | Provider + ChangeNotifier |
| Audio | just_audio |
| Persistence | SharedPreferences |
| PDF | pdf package |
| Charts | fl_chart |
| Security | crypto, crypto-js |

---

## 🔧 Configuration

### App Settings (In-App)
| Setting | Options | Default |
|---------|---------|---------|
| Language | ES / EN / AR | ES |
| Theme | Light / Dark / System | System |
| Audio Speed | 0.5× / 0.75× / 1.0× | 1.0× |
| Repeat Count | 1× / 3× / 7× / 10× | 1× |
| Text Size | 80% – 200% | 100% |
| Notifications | Daily review / Streak reminders | Enabled |

### Audio Settings
- **Speed control** — 0.5× to 2.0×
- **Repeat** — 1 to 10 times
- **Offline playback** — All audio bundled

---

## 🔐 Security & DevSecOps

### Build Pipeline (GitHub Actions + GitLab CI)
```
Validate → Build → Scan → Package → Release
   │         │       │        │        │
   ▼         ▼       ▼        ▼        ▼
Format    Build    CodeQL   Sign      Release
Analyze   APKs    Grype    Cosign    Assets
License   Obfusc. Trivy    SLSA      GitHub/
Gitleaks  Minify  MobSF    Proven.   GitLab
TruffleHog Minify  SBOM    Cosign
```

### Security Features
| Feature | Implementation |
|---------|----------------|
| **Code Signing** | Release keystore (RSA-2048) |
| **Obfuscation** | `--obfuscate` + `--split-debug-info` |
| **Minification** | R8 `isMinifyEnabled = true` |
| **Backup** | `android:allowBackup="false"` |
| **Debug** | `android:debuggable="false"` |
| **Signatures** | Cosign keyless + SLSA provenance |
| **SBOM** | CycloneDX (Syft) |
| **Vuln Scan** | Grype, Trivy, MobSF |
| **Secrets** | Gitleaks + TruffleHog |
| **Deps** | Grype, license_checker |

### Verified Build
```bash
# Verify signature
apksigner verify --print-certs app-release.apk

# Verify minification
apkanalyzer manifest print app-release.apk | grep isMinifyEnabled
```

---

## 🐳 Docker

```bash
# Build
docker compose -f docker-compose.yml build builder

# Run security scan
docker compose run --rm scanner-ci

# Development (hot reload)
docker compose --profile dev up dev
```

---

## 📦 Release Artifacts

| Artifact | Description |
|----------|-------------|
| `talk-to-me-spanish-v1.0.0.apk` | Signed release APK |
| `español-zero-a-heroe-v1.0.0.apk.sig` | Cosign signature |
| `sbom-project.cdx.json` | Project SBOM (CycloneDX) |
| `sbom-apk.cdx.json` | APK SBOM |
| `provenance.intoto.jsonl` | SLSA provenance |
| `sbom-project.cdx.json.sig` | SBOM signature |

---

## 📄 License

**Apache License 2.0** — See [LICENSE](LICENSE) and [NOTICE](NOTICE)

```
Copyright 2026 Mohamed Rafaa TOUNEKTI

Licensed under the Apache License, Version 2.0
```

---

## 🤝 Contributing

See [CONTRIBUTING.md](CONTRIBUTING.md) for:
- Development setup
- Coding standards
- PR process
- Testing guidelines
- Translation workflow

---

## 🛡️ Security

See [SECURITY.md](SECURITY.md) for:
- Vulnerability reporting
- Security architecture
- Compliance status
- Incident response

---

## 👤 Author

**Mohamed Rafaa TOUNEKTI**  
DevOps & DevSecOps Engineer  
🔗 [LinkedIn](https://linkedin.com/in/mohamed-rafaa-tounekti)  
✉️ rafaabou@gmail.com  
🐙 [GitHub](https://github.com/rafaabou)

---

## 🙏 Acknowledgments

- Flutter team for the amazing framework
- Flutter community packages (just_audio, provider, etc.)
- Open source security tools (Grype, Trivy, Syft, Cosign, Gitleaks, TruffleHog)
- MobSF for mobile security scanning

---

**Made with ❤️ for language learners worldwide**

*Learn Spanish offline, anywhere, anytime — no ads, no tracking, just learning.*