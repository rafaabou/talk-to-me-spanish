# Contributing to Talk To Me

Thank you for your interest in contributing to Talk To Me! This document provides guidelines for contributing to the Talk To Me Spanish and Talk To Me Português Brasileiro apps.

## Code of Conduct

This project adheres to a Code of Conduct. By participating, you are expected to uphold this code. Please report unacceptable behavior to conduct@rafaabou.com.

## How to Contribute

### Types of Contributions

1. **Bug Reports** - Found a bug? Let us know!
2. **Feature Requests** - Have an idea? We'd love to hear it!
3. **Code Contributions** - Fix bugs, add features, improve performance
4. **Documentation** - Improve docs, fix typos, add examples
4. **Translations** - Add or improve language support
5. **Security** - Report vulnerabilities (see SECURITY.md)
6. **Testing** - Write tests, report bugs, test releases

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

### Setup

```bash
# Clone the repository
git clone https://github.com/rafaabou/talk-to-me-spanish.git
cd talk-to-me-spanish/app

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

# Run tests
flutter test

# Build release APK
flutter build apk --release --obfuscate --split-debug-info=build/debug-info

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

- **Clean Architecture**: Separate UI, business logic, data layers
- **State Management**: Provider pattern (already established)
- **Dependency Injection**: Constructor injection preferred
- **Error Handling**: Use Result/Either pattern, avoid exceptions for control flow
- **Async**: Use `Future`/`Stream`, avoid blocking calls

### File Organization

```
lib/
├── main.dart                 # App entry point
├── models/                   # Data models
├── screens/                  # UI screens
├── widgets/                  # Reusable widgets
├── services/                 # Business logic/services
└── utils/                    # Utilities/helpers
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
7. **Address** review feedback
8. **Merge** after approval

### PR Requirements

- [ ] All CI checks pass
- [ ] Code formatted (`dart format`)
- [ ] Static analysis passes (`flutter analyze`)
- [ ] Tests pass (`flutter test`)
- [ ] No new warnings from `flutter analyze`
- [ ] Updated documentation if needed
- [ ] CHANGELOG.md updated (for significant changes)
- [ ] Security scan passes (no new vulnerabilities)

## Testing

### Test Types

| Type | Location | Command |
|------|----------|---------|
| Unit | `test/` | `flutter test` |
| Widget | `test/` | `flutter test` |
| Integration | `integration_test/` | `flutter test integration_test` |

### Test Guidelines

- Test business logic, not UI implementation
- Mock external dependencies
- Test edge cases and error paths
- Aim for >80% coverage on business logic
- Name tests clearly: `should_<expected>_when_<condition>`

## Adding Translations

### Supported Languages

- English (en) - Base
- Spanish (es) - Primary for Español app
- Portuguese (pt) - Primary for Português app
- Arabic (ar) - RTL support

### Adding New Language

1. Add locale to `AppState` supported languages
2. Create translation files in `lib/l10n/` (if using gen_l10n)
3. Or add translations to `TriText` model objects
4. Test RTL layout for Arabic
5. Update `pubspec.yaml` with new locale

### Translation Format

```dart
TriText(
  es: 'Hola mundo',
  en: 'Hello world',
  ar: 'مرحبا بالعالم',
  pt: 'Olá mundo',
)
```

## Adding Content

### Course Structure

```
assets/course/
├── levels/
│   ├── A1.json
│   ├── A2.json
│   └── ...
├── index.json
└── verbs.json
```

### Adding a Lesson

1. Add lesson to appropriate level JSON
2. Include all required fields:
   - `id`, `level`, `title` (TriText)
   - `objectives` (List<TriText>)
   - `vocabulary` (List<VocabWord>)
   - `grammar` (List<GrammarSection>)
   - `dialogueLines` (List<DialogueLine>)
   - `readingText` (TriText, optional)
   - `culturalTips` (TriText, optional)
   - `speaking` (List<SpeakingItem>)
   - `exercises` (List<Exercise>)
3. Add audio files to `assets/audio/`
5. Regenerate index: `dart run tools/generate_index.dart`
6. Run tests

### Audio Files

- Format: OPUS (preferred) or MP3
- Naming: `{lang}_{hash}.opus` (auto-generated)
- Location: `assets/audio/`
- Generate with TTS or record native speakers
- Optimize for size (target <50KB per clip)

## Code Review Checklist

### For Authors

- [ ] Self-reviewed code
- [ ] Tests pass locally
- [ ] Format applied
- [ ] Analysis passes
- [ ] No debug prints (`print()`, `debugPrint()`)
- [ ] No hardcoded strings (use TriText)
- [ ] No TODO/FIXME without issue reference
- [ ] CHANGELOG updated for significant changes

### For Reviewers

- [ ] Code follows style guide
- [ ] Logic is correct and tested
- [ ] No security issues
- [ ] Performance considered
- [ ] Documentation updated
- [ ] Breaking changes documented
- [ ] Dependencies justified

## Release Process

### Versioning

We follow [Semantic Versioning](https://semver.org/):
- MAJOR: Breaking changes
- MINOR: New features (backward compatible)
- PATCH: Bug fixes (backward compatible)

### Release Checklist

- [ ] All CI checks pass on `main`
- [ ] Version bumped in `pubspec.yaml`
- [ ] CHANGELOG.md updated
- [ ] Release notes drafted
- [ ] Release keystore available
- [ ] Build release APKs
- [ ] Sign with release keystore
- [ ] Generate SBOMs
- [ ] Sign artifacts with Cosign
- [ ] Generate SLSA provenance
- [ ] Create GitHub/GitLab release
- [ ] Upload artifacts
- [ ] Announce release

## Getting Help

- **Documentation**: Check README.md and code comments
- **Issues**: Search existing issues first
- **Discussions**: Use GitHub/GitLab Discussions
- **Security**: See SECURITY.md for vulnerability reporting

## Recognition

Contributors are recognized in:
- CHANGELOG.md
- Release notes
- Contributors section in README
- GitHub/GitLab contributor graphs

Thank you for contributing to Talk To Me! 🎉