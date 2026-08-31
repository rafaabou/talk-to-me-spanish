# Talk To Me Spanish

**Latest release: v1.2.0**

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
├── Dockerfile                  # Scan-only image (Alpine + COPY app-release.apk)
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
| `main` | Production code. Protected. | Full pipeline incl. scans; creates GitHub Release on every push |
| `develop` | Integration branch | Full pipeline |
| `feature/*` | Work branches, PR/MR → `develop` | Validation on MR |
| `hotfix/*` | Urgent fixes → `main` (+ backport to develop) | Full pipeline |
| `v*` tags | Explicit versioned releases | Full pipeline; creates GitHub Release |

Flow: `feature/x → develop → main`. Every push to `main` produces a release artifact.

## 4. How it works — GitHub Actions (`.github/workflows/build.yml`)

Triggers: push/PR to `main`, `develop`; tag `v*`; manual dispatch.
Runs on the dedicated **self-hosted** runner labelled `spanish` (all 4 jobs).

| Stage | Job | What it does |
|---|---|---|
| 1 validate | `validate` (30m) | format check → `flutter analyze --fatal-infos` → `flutter test` → gitleaks + TruffleHog secret scans → dependency audit |
| 2 build | `build` (90m) | restore keystore (or ephemeral) → obfuscated arm64 APK → size check → **inline security scans** (Hadolint, Grype, Syft, Trivy, Dockle all `if: always()`) |
| 3 package | `package` (45m) | apksigner verify → Syft `dir:.` (project SBOM) + Grype `--fail-on high` (APK SBOM) → Cosign keyless signature → `gh release create` |
| 4 release | `release` (20m) | **runs on every push to `main`** → GitHub Release via `softprops/action-gh-release@v2` with APK, signatures, SBOMs |

### Required GitHub secrets

| Secret | Required? | Purpose |
|---|---|---|
| `RELEASE_KEYSTORE_BASE64` | optional | `base64 -d` of your real `release.keystore`. If absent, an ephemeral keystore is generated per build (installs work, but signature changes between builds). |
| `GITHUB_TOKEN` | automatic | Provided by Actions for releases. |

## 5. How it works — GitLab CI (`.gitlab-ci.yml`)

Same four stages, self-contained runner image (Flutter + Android SDK installed in-pipeline):

| Stage | Jobs | Notes |
|---|---|---|
| validate | `validate`, `dependency-update` | analyze + tests; scheduled dep bumps |
| build | `build` | keystore via `RELEASE_KEYSTORE_BASE64` variable or ephemeral; arm64 APK artifact (1 week) |
| scan | `grype-scan`, `trivy-scan`, `mobsf-scan` | Syft SBOM + Grype (fails on HIGH+), Trivy SARIF (SAST report), MobSF dynamic static analysis (**manual**, skipped without API key) |
| package | `package` | cosign-signed artifacts |
| release | `release` | **runs on every push to `main`** → GitLab Release |

Cache: pub/gradle/flutter keyed per project+branch. Artifacts expire 1–90 days by stage.

### Required GitLab CI/CD variables

| Variable | Required? | Purpose |
|---|---|---|
| `RELEASE_KEYSTORE_BASE64` | optional | stable signing across builds |
| `MOBSF_API_KEY`, `MOBSF_URL` | optional | enable the manual MobSF job |

Everything else needs no configuration — pipelines run out-of-the-box.

## 6. Docker

**Scan-only `Dockerfile`** (no in-container compilation — eliminates OOM on small runners):

```dockerfile
FROM alpine:3.22
COPY app-release.apk /app-release.apk
# ... scanners (hadolint, dockle, trivy, grype, syft) installed at runtime
```

```bash
# Build APK on host, then scan via docker-compose
docker compose build scanner
docker compose run --rm scanner-ci    # one-shot scan into ./artifacts ./sbom ./sarif

# Local development shell with Flutter + Android SDK (builder service)
docker compose build builder
docker compose run --rm builder       # shell with Flutter+Android SDK mounted on ./app
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
| Version name/code | `app/pubspec.yaml` (`version:`) | 1.2.0+4 |
| Progress export file | documents dir | `eszero_progress.json` |
| UI languages | in-app switcher | en / es / ar (RTL) |
| Runner labels (GH Actions) | `.github/workflows/build.yml` | `self-hosted, linux, X64, spanish` |
| Runner labels (GitLab) | `.gitlab-ci.yml` | `spanish` |
| CI Java setup | `actions/setup-java@v5` (no `cache: gradle`) | Temurin 17 |
| CI Flutter setup | `subosito/flutter-action@v2` (`cache: false`) | 3.29.3 stable |

## 8. Security notes

- **Secret scanning**: gitleaks (config: `.gitleaks.toml`) + TruffleHog run on every push;
  local devs can enable `.pre-commit-config.yaml` (`pre-commit install`).
- **Keystore**: never commit `*.keystore` / `*.jks` / `keystore.properties` (gitignored).
  The repo-local `android/app/release.keystore` is a LOCAL development keystore and is not tracked.
- **Known dev fallback**: `build.gradle.kts` falls back to password `release123` when env vars
  are unset (matches the local dev keystore). For production distribution set the
  `RELEASE_KEY*` env vars or the `RELEASE_KEYSTORE_BASE64` CI secret and generate a strong
  private keystore: rotate before any public release.
- **Supply chain**: every release artifact gets a Syft SBOM (project + APK), Grype scan,
  Cosign keyless signature, and a GitHub Release with all artifacts attached.
- Vulnerabilities: see `SECURITY.md` for the reporting policy.

## 9. Verify before push

```bash
cd app && flutter analyze && flutter test   # both must pass
git status                                  # nothing unintended staged
gitleaks detect --no-git -c .gitleaks.toml  # optional local secret scan
```

## License

Apache-2.0 — see `LICENSE` and `NOTICE`.

## Changelog

### v1.2.0 (2026-08-31)
- Reset progress now shows confirmation dialog
- Silent `catch (_) {}` blocks replaced with `debugPrint` for debuggability
- Localized UI strings (match-pair headers, audio button, theme selector) for pt/es/ar
- Dead code cleanup (duplicate ternaries, unused imports, merged answer blocks)
- Dynamic lesson count (no more hardcoded 72 in stats/export)
- Match-pair quiz UI: two-column select-to-match (Portuguese left, English right)
- Deduplicated `.gitignore`, fixed duplicate `commit-message` in `dependabot.yml`
- Removed stale CI artifacts (`analysis-report.txt`, `deps-outdated.json`)
- Version bumped to 1.2.0+4