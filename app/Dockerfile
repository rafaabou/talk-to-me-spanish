# syntax=docker/dockerfile:1
# =============================================================================
# Scan-only artifact image - Talk To Me Spanish
#
# The production APK is compiled ON THE HOST by CI ("Build Spanish Release
# APK" step) and staged into this build context as app-release.apk. This image
# exists purely so trivy/grype/dockle can inspect the shipped artifact in a
# hardened, minimal container. It is never published.
#
# Passes: hadolint (no warnings) and dockle CIS checks:
#         CIS-DI-0001 non-root user, CIS-DI-0005 content trust,
#         CIS-DI-0006 healthcheck.
#
# NOTE: app/.dockerignore excludes *.apk except the staged app-release.apk,
#       plus keystores/host state.
# =============================================================================

FROM alpine:3.20

LABEL org.opencontainers.image.title="talk-to-me-spanish" \
      org.opencontainers.image.description="Release APK artifact container (scan-only, never published)" \
      org.opencontainers.image.source="https://github.com/rafaabou/talk-to-me-spanish" \
      org.opencontainers.image.licenses="MIT"

RUN addgroup -S appgroup && adduser -S -G appgroup appuser

ENV DOCKER_CONTENT_TRUST=1

HEALTHCHECK --interval=30s --timeout=5s --retries=3 CMD [ -f /app-release.apk ] || exit 1

COPY app-release.apk /app-release.apk

USER appuser

CMD ["true"]
