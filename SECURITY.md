# Security Policy

## Supported Versions

| Version | Supported          |
| ------- | ------------------ |
| 1.0.x   | ✅ Yes             |
| < 1.0   | ❌ No              |

## Reporting a Vulnerability

We take security vulnerabilities seriously. If you discover a security vulnerability, please report it responsibly.

### Reporting Channels

1. **Preferred**: Email security@rafaabou.com with details
2. **GitHub Security Advisory**: Use the "Security" tab in this repository
3. **GitLab Security Issue**: Create a confidential issue on GitLab

### What to Include

Please include the following information:
- Description of the vulnerability
- Steps to reproduce
- Potential impact
- Affected versions
- Any proof-of-concept code (if applicable)
- Suggested fix (if known)

### Response Timeline

| Severity | Initial Response | Fix Target |
|----------|------------------|------------|
| Critical | 24 hours         | 72 hours   |
| High     | 48 hours         | 1 week     |
| Medium   | 1 week           | 2 weeks    |
| Low      | 2 weeks          | Next release |

## Security Architecture

### Application Security

- **Offline-first design**: No network calls required for core functionality
- **No user data collection**: No PII, no analytics, no tracking
- **Local-only storage**: All data stored locally via SharedPreferences
- **No backend APIs**: No attack surface from server-side vulnerabilities

### Build Security

| Control | Implementation |
|---------|----------------|
| Code Signing | Release APKs signed with dedicated release keystore |
| Minification | R8 obfuscation enabled for release builds |
| Debug Info | Split debug info separated from APK |
| Obfuscation | Dart code obfuscation enabled |
| Debuggable | `android:debuggable="false"` in release |
| Backup | `android:allowBackup="false"` |

### Dependency Security

| Control | Tool | Frequency |
|---------|------|-----------|
| SAST | CodeQL (Dart) | Every PR/Push |
| SCA | Grype + Syft | Every build |
| Container Scan | Trivy | Every build |
| Mobile Scan | MobSF | Every build |
| Secret Scan | Gitleaks + TruffleHog | Every commit |
| License Check | license_checker | Every build |

### Runtime Security

- **No network permissions**: `INTERNET` permission not declared
- **No cleartext traffic**: `android:usesCleartextTraffic="false"` (default)
- **No exported components**: Only necessary components exported with intent filters
- **Certificate pinning**: Not applicable (no network calls)
- **Certificate transparency**: Not applicable (no network calls)

### Data Protection

| Data Type | Storage | Encryption |
|-----------|---------|------------|
| User Progress | SharedPreferences | Platform default |
| Favorites | SharedPreferences | Platform default |
| Settings | SharedPreferences | Platform default |
| Audio Files | Assets (read-only) | N/A |
| Course Content | Assets (read-only) | N/A |

## Secure Development Practices

### Code Review Requirements

- All changes require PR review
- Security-focused review for:
  - New dependencies
  - Permission changes
  - Storage modifications
  - Native code (if any)

### Testing Requirements

- Unit tests for business logic
- Integration tests for critical flows
- Security tests for:
  - Input validation
  - Storage encryption
  - Permission handling

### Release Process

1. All security scans must pass
2. Version bump with semantic versioning
3. Signed with release keystore
4. SBOM generated (CycloneDX)
5. Cosign signatures generated
6. Published to GitHub/GitLab releases

## Vulnerability Disclosure

We follow coordinated vulnerability disclosure:

1. **Private disclosure** → We acknowledge within 24h
2. **Assessment** → We validate and assess impact within 72h
3. **Fix development** → We develop and test fix
7. **Coordinated release** → We release fix and publish advisory
30. **Public disclosure** → After fix is available to users

## Security Contacts

- **Primary**: Mohamed Rafaa TOUNEKTI (rafaabou@gmail.com)
- **PGP Key**: Available on request
- **Response Time**: 24h for critical, 48h for high

## Compliance

| Standard | Status |
|----------|--------|
| OWASP MASVS | Level 1 target |
| OWASP ASVS | Level 1 target |
| GDPR | Compliant (no personal data) |
| ePrivacy | Compliant (no tracking) |

## Security Tooling

| Tool | Purpose | Integration |
|------|---------|-------------|
| CodeQL | SAST | GitHub/GitLab CI |
| Grype | Vulnerability scanning | CI/CD |
| Syft | SBOM generation | CI/CD |
| Trivy | FS/Container scan | CI/CD |
| MobSF | Mobile app scanning | CI/CD |
| Gitleaks | Secret detection | Pre-commit + CI |
| TruffleHog | Secret detection | Pre-commit + CI |
| Cosign | Artifact signing | Release |

## Incident Response

In case of a security incident:

1. **Contain** → Revoke compromised keys, rotate secrets
2. **Assess** → Determine scope and impact
3. **Remediate** → Deploy fix, rotate keys
4. **Communicate** → Notify affected users if needed
5. **Review** → Post-incident review within 1 week

## Security Updates

Security updates are released as patch versions (e.g., 1.0.1, 1.0.2) and announced via:
- GitHub/GitLab releases
- Security advisories (GitHub/GitLab)
- Email to security mailing list (if subscribed)

---

**Last Updated**: 2026
**Version**: 1.0
**Maintainer**: Mohamed Rafaa TOUNEKTI
## Signing key handling (important)

- `*.keystore` / `*.jks` / `keystore.properties` are **never committed** (gitignored + dockerignored).
- CI signs releases from the `RELEASE_KEYSTORE_BASE64` secret; without it an **ephemeral
  development keystore** (password `release123`) is generated per build. APKs built this way
  are fine for personal testing but must not be published to a store.
- Before any public/store release: generate a strong private keystore, store it in the CI
  secret, and treat `release123` strictly as a local-development fallback.
- If a real secret ever lands in history: rotate it immediately, then purge history
  (e.g. `git filter-repo`) — rotation alone is not sufficient.
