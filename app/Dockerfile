# =============================================================================
# Multi-stage Dockerfile - Talk To Me Spanish
#
# Stage 1 (build):   compile the release APK inside the pinned Flutter image
# Stage 2 (runtime): minimal artifact holder used ONLY for local security
#                    scans (trivy image / dockle). Never pushed to a registry.
#
# Passes: hadolint (no warnings) and dockle CIS checks:
#         CIS-DI-0001 non-root user, CIS-DI-0005 content trust,
#         CIS-DI-0006 healthcheck.
#
# NOTE: app/.dockerignore (context root) keeps host .dart_tool/, build/ and
#       keystores out of the image. pubspec.lock stays in for --enforce-lockfile.
# =============================================================================

# ---- Stage 1: build ----------------------------------------------------------
FROM ghcr.io/cirruslabs/flutter:3.29.3 AS build

SHELL ["/bin/bash", "-o", "pipefail", "-c"]

WORKDIR /app

# Pre-install Android components Gradle needs (cached until base image changes):
# NDK 26.3.11579264 = flutter.ndkVersion on Flutter 3.29.3
# (license prompt isolated so sdkmanager's exit doesn't SIGPIPE 'yes' into 141)
RUN ( yes | sdkmanager --licenses > /dev/null ) || true ; \
    sdkmanager "platform-tools" "platforms;android-34" "platforms;android-35" \
      "build-tools;34.0.0" "ndk;26.3.11579264" "cmake;3.22.1" > /dev/null

COPY pubspec.yaml pubspec.lock ./

RUN flutter pub get --enforce-lockfile

COPY . .

# app/.dockerignore excludes host keystores (never bake real keys into images).
# Generate an ephemeral one for this throwaway scan-only build instead; the
# random password lives only in this layer's process memory, never in history.
RUN KS_PASS="$(od -An -N16 -tx1 /dev/urandom | tr -d ' \n')" && \
    if [ ! -f android/app/release.keystore ]; then \
      keytool -genkeypair \
        -keystore android/app/release.keystore \
        -alias release -keyalg RSA -keysize 2048 -validity 10000 \
        -storepass "$KS_PASS" -keypass "$KS_PASS" \
        -dname "CN=Docker Scan Build, OU=CI, O=Local"; \
    fi && \
    flutter build apk \
      --release \
      --obfuscate \
      --split-debug-info=build/debug-info \
      --target-platform android-arm64

# ---- Stage 2: runtime (artifact holder for scanners) --------------------------
FROM alpine:3.20 AS runtime

LABEL org.opencontainers.image.title="talk-to-me-spanish" \
      org.opencontainers.image.description="Release APK artifact container (scan-only, never published)" \
      org.opencontainers.image.source="https://github.com/rafaabou/talk-to-me-spanish" \
      org.opencontainers.image.licenses="MIT"

RUN addgroup -S appgroup && adduser -S -G appgroup appuser

ENV DOCKER_CONTENT_TRUST=1

HEALTHCHECK --interval=30s --timeout=5s --retries=3 CMD [ -f /app-release.apk ] || exit 1

COPY --from=build --chown=appuser:appgroup \
     /app/build/app/outputs/flutter-apk/app-release.apk /app-release.apk

USER appuser

CMD ["true"]
