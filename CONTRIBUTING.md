# Contributing to Talk To Me Spanish

Thank you for your interest in contributing to Talk To Me Spanish!
By Mohamed Rafaa Tounekti.

## Code of Conduct

This project adheres to a Code of Conduct. By participating, you are expected to uphold this code. Please report unacceptable behavior to rafaabou@gmail.com.

## How to Contribute

### Types of Contributions

1. **Bug Reports** — Found a bug? Let us know!
2. **Feature Requests** — Have an idea? We'd love to hear it!
3. **Code Contributions** — Fix bugs, add features, improve performance
4. **Documentation** — Improve docs, fix typos, add examples
5. **Translations** — Add or improve language support
6. **Security** — Report vulnerabilities (see SECURITY.md)
7. **Testing** — Write tests, report bugs, test releases

### Before You Start

1. Check existing issues and PRs
2. For significant changes, open an issue first to discuss
3. Fork the repository and create a feature branch
4. Follow the coding standards below

## Development Setup

### Prerequisites

- Flutter SDK 3.29.3+
- Dart SDK 3.7.2+
- Android SDK 35 + NDK 27
- Java 17
- Git

> **IMPORTANT**: JDK 25 breaks the Kotlin Gradle plugin. Always use JDK 17.

### Setup

```bash
# Clone the repository
git clone https://github.com/rafaabou/espanol-zero-to-hero.git
cd espanol-zero-to-hero/app

# Install dependencies
flutter pub get

# Run the app
flutter run
```

### Development Commands

```bash
# Format code
dart format --set-exit-if-changed --output=none .

# Static analysis
flutter analyze --fatal-infos

# Run tests (79 tests)
flutter test

# Build release APK
JAVA_HOME=/path/to/jdk17 flutter build apk --release --obfuscate --split-debug-info=build/debug-info --target-platform android-arm64

# Check dependencies
flutter pub outdated
flutter pub deps
```

## Coding Standards

### Dart/Flutter Style

- Follow [Effective Dart](https://dart.dev/guides/language/effective-dart)
- Use `dart format` (enforced by CI)
- Follow `flutter analyze` rules (enforced by CI)
- Use meaningful variable/function names
- Prefer `const` constructors
- Use `final` over `var` when possible
- Document public APIs with `///` comments

### Architecture Guidelines

- **Provider + ChangeNotifier**: State management pattern (already established)
- **Singleton services**: Lazy-loading singletons for repositories
- **Trilingual**: Every UI string in ES/EN/AR via `TriText`
- **Offline-first**: No network calls required

### File Organization

```
lib/
├── main.dart                 # App entry point
├── models/                   # Data models (TriText, Lesson, VerbInfo)
├── screens/                  # UI screens (14 files)
├── widgets/                  # Reusable widgets (6 files)
├── services/                 # Business logic (11 files)
```

### Naming Conventions

| Type | Convention | Example |
|------|------------|---------|
| Files | snake_case | `lesson_screen.dart` |
| Classes | PascalCase | `LessonScreen` |
| Functions/Variables | camelCase | `loadLessons()` |
| Constants | SCREAMING_SNAKE_CASE | `MAX_RETRY_COUNT` |
| Private | _prefix | `_privateMethod()` |
| Enums | PascalCase | `LessonStatus` |

### Git Commit Messages

Follow [Conventional Commits](https://www.conventionalcommits.org/):

```
<type>(<scope>): <description>

[optional body]

[optional footer]
```

Types:
- `feat`: New feature
- `fix`: Bug fix
- `docs`: Documentation only
- `style`: Formatting, no code change
- `refactor`: Code restructuring
- `perf`: Performance improvement
- `test`: Adding tests
- `chore`: Maintenance, deps
- `ci`: CI/CD changes
- `security`: Security fixes
- `deps`: Dependency updates

Examples:
```
feat(lesson): add cultural tips section
fix(audio): fix playback speed reset on pause
docs(readme): update installation instructions
refactor(models): extract course models to separate file
```

### Pull Request Process

1. **Create** feature branch from `develop`
2. **Develop** with atomic commits
3. **Test** locally (format, analyze, test)
4. **Push** to your fork
5. **Open PR** against `develop` branch
6. **Describe** changes clearly in PR description
7. **Wait** for CI checks to pass
8. **Address** review feedback
9. **Merge** after approval

### PR Requirements

- [ ] All CI checks pass
- [ ] Code formatted (`dart format`)
- [ ] Static analysis passes (`flutter analyze`)
- [ ] Tests pass (`flutter test`)
- [ ] No new warnings from `flutter analyze`
- [ ] Updated documentation if needed
- [ ] Security scan passes (no new vulnerabilities)

## Testing

### Test Types

| Type | Location | Command |
|------|----------|---------|
| Unit | `test/` | `flutter test` |
| Widget | `test/` | `flutter test` |
| Integration | `integration_test/` | `flutter test integration_test` |

### Test Files (79 tests)

| File | Covers |
|------|--------|
| `course_repository_test.dart` | Level/lesson loading, caching |
| `fsrs_test.dart` | FSRS algorithm, card lifecycle |
| `pinch_test.dart` | Pinch-to-zoom gesture handling |
| `progress_service_test.dart` | Persistence, streaks, favorites, SRS |
| `quiz_screen_test.dart` | Quiz logic, scoring |
| `ui_text_test.dart` | Localization helper |
| `widget_test.dart` | Widget rendering |

### Test Guidelines

- Test business logic, not UI implementation
- Mock external dependencies
- Test edge cases and error paths
- Aim for >80% coverage on business logic
- Name tests clearly: `should_<expected>_when_<condition>`

## Adding Content

### Course Structure

```
assets/course/
├── levels/
│   ├── index.json          # Level metadata
│   ├── A1-01.json          # Individual lessons
│   └── ...
├── index.json              # Search index
└── verbs.json              # Verb conjugations
```

### Adding a Lesson

1. Add lesson JSON to appropriate level in `assets/course/levels/`
2. Include all required fields:
   - `id`, `level`, `title` (TriText)
   - `objectives` (List<TriText>)
   - `vocabulary` (List<VocabWord>)
   - `grammar` (List<GrammarSection>)
   - `dialogue` (title + lines)
   - `reading` (title + text)
   - `speaking` (List<SpeakingItem>)
   - `exercises` (List<Exercise>)
   - `culturalTips` (TriText, optional)
3. Add audio files to `assets/audio/`
4. Regenerate index: `python3 tools/build_index.py`
5. Run tests

### Audio Files

- Format: `.opus` (Ogg Opus)
- Naming: `md5(lang:text)[:12].opus` (auto-generated)
- Location: `assets/audio/`
- Generate with: `python3 tools/gen_audio.py`
- Voice: es-UY-ValentinaNeural (Microsoft Edge TTS)

## Code Review Checklist

### For Authors

- [ ] Self-reviewed code
- [ ] Tests pass locally
- [ ] Format applied
- [ ] Analysis passes
- [ ] No debug prints (`print()`, `debugPrint()`)
- [ ] No hardcoded strings (use TriText)
- [ ] No TODO/FIXME without issue reference

### For Reviewers

- [ ] Code follows style guide
- [ ] Logic is correct and tested
- [ ] No security issues
- [ ] Performance considered
- [ ] Documentation updated
- [ ] Breaking changes documented

## Release Process

### Versioning

We follow [Semantic Versioning](https://semver.org/):
- MAJOR: Breaking changes
- MINOR: New features (backward compatible)
- PATCH: Bug fixes (backward compatible)

### Release Checklist

- [ ] All CI checks pass on `main`
- [ ] Version bumped in `pubspec.yaml`
- [ ] README.md updated
- [ ] Release keystore available
- [ ] Build release APKs
- [ ] Sign with release keystore
- [ ] Generate SBOMs
- [ ] Sign artifacts with Cosign
- [ ] Create GitHub/GitLab release
- [ ] Upload artifacts

## Getting Help

- **Documentation**: Check README.md, ARCHITECTURE.md, and code comments
- **Issues**: Search existing issues first
- **Discussions**: Use GitHub/GitLab Discussions
- **Security**: See SECURITY.md for vulnerability reporting

## Recognition

Contributors are recognized in:
- Release notes
- GitHub/GitLab contributor graphs

Thank you for contributing to Talk To Me!
