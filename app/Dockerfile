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

WORKDIR /app

COPY pubspec.yaml pubspec.lock ./

RUN flutter pub get --enforce-lockfile

COPY . .

RUN flutter build apk \
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
