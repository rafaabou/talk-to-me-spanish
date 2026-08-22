# Talk To Me Spanish

Offline-first **Spanish** learning app (Flutter, Android). 72 CEFR lessons (A1–C2), FSRS flashcards,
quizzes, audio with speed/repeat controls, verb conjugator, stats + streaks — 100% offline.

- Package: `com.rafaabou.eszero_hero` · Min SDK 24 · Target: arm64 release APK (~30–40 MB)
- Course content: `app/assets/course/` (72 lessons + index.json + verbs.json)
- Audio: `app/assets/audio/` (offline .opus clips, MD5-keyed)

---

## 1. Repository layout

```
.
├── app/                        # Flutter project
│   ├── lib/                    # Dart code (screens / services / models / widgets)
│   ├── assets/course/          # Lesson JSONs (generated) + index.json + verbs.json
│   ├── assets/audio/           # Offline audio clips
│   ├── android/                # Android host (Kotlin 2.2, AGP 8.7, minSdk 24)
│   └── test/                   # Unit + widget tests (55 tests)
├── tools/                      # Python content pipeline (build_index.py, ...)
├── .github/workflows/build.yml # GitHub Actions DevSecOps pipeline
├── .gitlab-ci.yml              # GitLab CI DevSecOps pipeline
├── Dockerfile                  # Multi-stage builder/scanner images
├── docker-compose.yml          # Local builder + scanner services
└── SECURITY.md                 # Security policy & reporting
```

## 2. Local development

Requirements: **Flutter 3.29.3** and **JDK 17**.

> ⚠️ JDK 25 breaks the Kotlin Gradle plugin (`JavaVersion.parse` crash).
> Always build with JDK 17: `export JAVA_HOME=<path-to-jdk17>` if your system Java is newer.

```bash
cd app
flutter pub get
flutter analyze            # must be clean
flutter test               # 55 tests must pass
flutter run                # run on device/emulator

# Release APK (arm64-only, ~30-40 MB)
flutter build apk --release --target-platform android-arm64
# output: build/app/outputs/flutter-apk/app-release.apk
```

Release signing reads env vars (`RELEASE_KEYSTORE_PATH`, `RELEASE_KEYSTORE_PASSWORD`,
`RELEASE_KEY_ALIAS`, `RELEASE_KEY_PASSWORD`). If unset it falls back to
`android/app/release.keystore` with the development password `release123`
(see [Security notes](#8-security-notes)).

### Content regeneration (optional)

```bash
python3 tools/build_index.py   # rebuild assets/course/index.json from the 72 lessons
```

## 3. Gitflow

| Branch | Purpose | CI behaviour |
|---|---|---|
| `main` | Production code. Protected. | Full pipeline incl. scans |
| `develop` | Integration branch | Full pipeline |
| `feature/*` | Work branches, PR/MR → `develop` | Validation on MR |
| `hotfix/*` | Urgent fixes → `main` (+ backport to develop) | Full pipeline |
| `v*` tags | Releases (`v1.1.0`) | Build + GitHub/GitLab Release |

Flow: `feature/x → develop → main`. Cut a tag on `main` to publish a release.

## 4. How it works — GitHub Actions (`.github/workflows/build.yml`)

Triggers: push/PR to `develop`, `test`; tag `v*`; manual dispatch.

| Stage | Job | What it does |
|---|---|---|
| 1 validate | `validate` | format check → `flutter analyze --fatal-infos` → `flutter test` → gitleaks + TruffleHog secret scans → dependency audit |
| 2 build | `build` | restore keystore from secret (or ephemeral) → obfuscated arm64 APK → size check |
| 3 security-scan | `security-scan` (matrix: grype, trivy) | SBOM (Syft) + vulnerability scans, SARIF upload, fails on HIGH+ |
| 4 package | `package` | apksigner verify → Syft/Grype on the APK → Cosign keyless signature → SLSA provenance attestation |
| 5 release | `release` | On `v*` tags: creates the GitHub Release with APK + signatures + SBOM |

### Required GitHub secrets

| Secret | Required? | Purpose |
|---|---|---|
| `RELEASE_KEYSTORE_BASE64` | optional | `base64 -d` of your real `release.keystore`. If absent, an ephemeral keystore is generated per build (installs work, but signature changes between builds). |
| `GITHUB_TOKEN` | automatic | Provided by Actions for releases/attestations. |

## 5. How it works — GitLab CI (`.gitlab-ci.yml`)

Same five stages, self-contained runner image (Flutter + Android SDK installed in-pipeline):

| Stage | Jobs | Notes |
|---|---|---|
| validate | `validate`, `dependency-update` | analyze + tests; scheduled dep bumps |
| build | `build` | keystore via `RELEASE_KEYSTORE_BASE64` variable or ephemeral; arm64 APK artifact (1 week) |
| scan | `grype-scan`, `trivy-scan`, `mobsf-scan` | Syft SBOM + Grype (fails on HIGH+), Trivy SARIF (SAST report), MobSF dynamic static analysis (**manual**, skipped without API key) |
| package | `package` | cosign-signed artifacts |
| release | `release` | on `v*` tags → GitLab Release |

Cache: pub/gradle/flutter keyed per project+branch. Artifacts expire 1–90 days by stage.

### Required GitLab CI/CD variables

| Variable | Required? | Purpose |
|---|---|---|
| `RELEASE_KEYSTORE_BASE64` | optional | stable signing across builds |
| `MOBSF_API_KEY`, `MOBSF_URL` | optional | enable the manual MobSF job |

Everything else needs no configuration — pipelines run out-of-the-box.

## 6. Docker

Multi-stage `Dockerfile`: `base` → `flutter-sdk` (Flutter + Android SDK + NDK) → `builder` / `scanner` targets.

```bash
docker compose build builder          # build toolchain image
docker compose run --rm builder       # shell with Flutter+Android SDK mounted on ./app
docker compose build scanner          # scanner image (syft/grype/trivy available)
docker compose run --rm scanner-ci    # one-shot scan into ./artifacts ./sbom ./sarif
```

Volumes cache `/root/.pub-cache`, `/root/.gradle` so repeat builds are fast.

> `.dockerignore` deliberately KEEPS `app/assets/` (course content + audio are compiled into
> the APK) and `pubspec.lock` (reproducible `--enforce-lockfile` installs).

## 7. Configuration reference

| Setting | Where | Default |
|---|---|---|
| Flutter version | workflow env / GitLab variables / Dockerfile ARG | 3.29.3 |
| Java version | workflows / Dockerfile | 17 |
| App id | `app/android/app/build.gradle.kts` | `com.rafaabou.eszero_hero` |
| Version name/code | `app/pubspec.yaml` (`version:`) | 1.1.0+2 |
| Progress export file | documents dir | `eszero_progress.json` |
| UI languages | in-app switcher | en / es / ar (RTL) |

## 8. Security notes

- **Secret scanning**: gitleaks (config: `.gitleaks.toml`) + TruffleHog run on every push;
  local devs can enable `.pre-commit-config.yaml` (`pre-commit install`).
- **Keystore**: never commit `*.keystore` / `*.jks` / `keystore.properties` (gitignored).
  The repo-local `android/app/release.keystore` is a LOCAL development keystore and is not tracked.
- **Known dev fallback**: `build.gradle.kts` falls back to password `release123` when env vars
  are unset (matches the local dev keystore). For production distribution set the
  `RELEASE_KEY*` env vars or the `RELEASE_KEYSTORE_BASE64` CI secret and generate a strong
  private keystore: rotate before any public release.
- **Supply chain**: every release artifact gets a Syft SBOM, Grype scan, Cosign signature
  and SLSA provenance attestation.
- Vulnerabilities: see `SECURITY.md` for the reporting policy.

## 9. Verify before push

```bash
cd app && flutter analyze && flutter test   # both must pass
git status                                  # nothing unintended staged
gitleaks detect --no-git -c .gitleaks.toml  # optional local secret scan
```

## License

Apache-2.0 — see `LICENSE` and `NOTICE`.
