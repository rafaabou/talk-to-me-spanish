# Multi-stage Dockerfile for Español Zero a Héroe
# Builds Spanish app with full DevSecOps pipeline

# =============================================================================
# STAGE 1: Base - Common dependencies
# =============================================================================
FROM ubuntu:22.04 AS base

ENV DEBIAN_FRONTEND=noninteractive
ENV TZ=UTC

RUN apt-get update && apt-get install -y --no-install-recommends \
    ca-certificates \
    curl \
    git \
    unzip \
    xz-utils \
    zip \
    openjdk-17-jdk-headless \
    python3 \
    python3-pip \
    && rm -rf /var/lib/apt/lists/*

ENV JAVA_HOME=/usr/lib/jvm/java-17-openjdk-amd64
ENV PATH="${JAVA_HOME}/bin:${PATH}"

# =============================================================================
# STAGE 2: Flutter SDK + Android SDK + NDK
# =============================================================================
FROM base AS flutter-sdk

ARG FLUTTER_VERSION=3.29.3
ARG ANDROID_SDK_VERSION=11076708
ARG ANDROID_NDK_VERSION=27.0.12077973

ENV FLUTTER_VERSION=${FLUTTER_VERSION}
ENV ANDROID_SDK_ROOT=/opt/android-sdk
ENV ANDROID_NDK_HOME=${ANDROID_SDK_ROOT}/ndk/${ANDROID_NDK_VERSION}
ENV PATH="${ANDROID_SDK_ROOT}/cmdline-tools/latest/bin:${ANDROID_SDK_ROOT}/platform-tools:${ANDROID_SDK_ROOT}/emulator:${PATH}"

# Install Flutter
RUN curl -sL "https://storage.googleapis.com/flutter_infra_release/releases/stable/linux/flutter_linux_${FLUTTER_VERSION}-stable.tar.xz" \
    | tar xJ -C /opt \
    && /opt/flutter/bin/flutter config --no-analytics \
    && /opt/flutter/bin/flutter doctor -v

ENV PATH="/opt/flutter/bin:${PATH}"

# Install Android SDK
RUN mkdir -p ${ANDROID_SDK_ROOT}/cmdline-tools \
    && curl -sL "https://dl.google.com/android/repository/commandlinetools-linux-${ANDROID_SDK_VERSION}_latest.zip" -o /tmp/cmdline-tools.zip \
    && unzip -q /tmp/cmdline-tools.zip -d ${ANDROID_SDK_ROOT}/cmdline-tools \
    && mv ${ANDROID_SDK_ROOT}/cmdline-tools/cmdline-tools ${ANDROID_SDK_ROOT}/cmdline-tools/latest \
    && rm /tmp/cmdline-tools.zip

# Accept licenses and install components
RUN yes | ${ANDROID_SDK_ROOT}/cmdline-tools/latest/bin/sdkmanager --licenses \
    && ${ANDROID_SDK_ROOT}/cmdline-tools/latest/bin/sdkmanager \
        "platforms;android-35" \
        "build-tools;35.0.0" \
        "ndk;${ANDROID_NDK_VERSION}" \
        "cmake;3.22.1"

ENV ANDROID_NDK_HOME=${ANDROID_SDK_ROOT}/ndk/${ANDROID_NDK_VERSION}

# =============================================================================
# STAGE 3: Security Tools
# =============================================================================
FROM flutter-sdk AS security-tools

# Install security scanning tools
RUN pip3 install --no-cache-dir --break-system-packages \
    syft \
    grype \
    cyclonedx-bom \
    licensechecker \
    gitleaks

# Install Trivy
RUN curl -sL https://github.com/aquasecurity/trivy/releases/latest/download/trivy_Linux-64bit.deb -o /tmp/trivy.deb \
    && dpkg -i /tmp/trivy.deb \
    && rm /tmp/trivy.deb

# Install Cosign
RUN curl -sL "https://github.com/sigstore/cosign/releases/latest/download/cosign-linux-amd64" -o /usr/local/bin/cosign \
    && chmod +x /usr/local/bin/cosign

# Install Syft
RUN curl -sSfL https://raw.githubusercontent.com/anchore/syft/main/install.sh | sh -s -- -b /usr/local/bin

# Install Grype
RUN curl -sSfL https://raw.githubusercontent.com/anchore/grype/main/install.sh | sh -s -- -b /usr/local/bin

# =============================================================================
# STAGE 4: Builder - Compile Spanish App
# =============================================================================
FROM security-tools AS builder

WORKDIR /workspace

# Copy only necessary files for dependency resolution first (cache layer)
COPY app/pubspec.yaml ./app/
COPY app/pubspec.lock ./app/

# Pre-fetch dependencies (cacheable layer)
RUN cd app && flutter pub get --enforce-lockfile

# Copy source code
COPY app/lib ./app/lib
COPY app/assets ./app/assets
COPY app/android ./app/android

# Generate code and build
RUN cd app \
    && flutter pub run build_runner build --delete-conflicting-outputs \
    && flutter build apk --release \
        --obfuscate \
        --split-debug-info=build/debug-info \
        --target-platform android-arm64

# =============================================================================
# STAGE 5: Security Scanning
# =============================================================================
FROM security-tools AS scanner

WORKDIR /workspace

COPY --from=builder /workspace/app/build/app/outputs/flutter-apk/app-release.apk ./espanol-release.apk
COPY --from=builder /workspace/app/pubspec.lock ./espanol-pubspec.lock

# Generate SBOMs
RUN syft espanol-release.apk -o cyclonedx-json=espanol-apk-sbom.cdx.json \
    && syft . -o cyclonedx-json=project-sbom.cdx.json

# Vulnerability scanning with fail-on-high
RUN grype sbom:espanol-apk-sbom.cdx.json --fail-on high --output json > espanol-grype-report.json || true \
    && grype sbom:project-sbom.cdx.json --fail-on high --output json > project-grype-report.json || true

# Trivy filesystem scan
RUN trivy fs --severity HIGH,CRITICAL --format sarif -o trivy-results.sarif . || true

# =============================================================================
# STAGE 6: Signing & Attestation
# =============================================================================
FROM security-tools AS signer

WORKDIR /workspace

COPY --from=builder /workspace/app/build/app/outputs/flutter-apk/app-release.apk ./espanol-release.apk
COPY --from=scanner /workspace/*.json ./sbom/
COPY --from=scanner /workspace/*.sarif ./sarif/

# Verify APK signatures
RUN apksigner verify --print-certs /workspace/espanol-release.apk

# Sign with Cosign (keyless)
RUN cosign sign-blob --yes \
    --output-signature espanol-release.apk.sig \
    /workspace/espanol-release.apk \
    && cosign sign-blob --yes \
    --output-signature sbom.cdx.json.sig \
    /workspace/sbom/project-sbom.cdx.json

# =============================================================================
# STAGE 7: Final Artifact Image
# =============================================================================
FROM scratch AS artifacts

COPY --from=builder /workspace/app/build/app/outputs/flutter-apk/app-release.apk /espanol-release.apk
COPY --from=signer /workspace/*.sig /signatures/
COPY --from=scanner /workspace/sbom/*.json /sbom/
COPY --from=scanner /workspace/sarif/*.sarif /sarif/
COPY --from=builder /workspace/app/build/debug-info /debug-info

# =============================================================================
# STAGE 8: Minimal Runtime (for testing)
# =============================================================================
FROM base AS runtime

WORKDIR /app

COPY --from=builder /workspace/app/build/app/outputs/flutter-apk/app-release.apk ./espanol-release.apk

# Install Android emulator for testing (optional)
RUN apt-get update && apt-get install -y --no-install-recommends \
    android-sdk-platform-tools-common \
    && rm -rf /var/lib/apt/lists/*

ENTRYPOINT ["bash"]

# =============================================================================
# STAGE 9: Web Build & Serve
# =============================================================================
FROM flutter-sdk AS web-builder

WORKDIR /workspace

COPY app/pubspec.yaml ./app/
COPY app/pubspec.lock ./app/
RUN cd app && flutter pub get --enforce-lockfile

COPY app/lib ./app/lib
COPY app/assets ./app/assets
COPY app/web ./app/web

RUN cd app && flutter build web --release

FROM python:3.12-slim AS web

WORKDIR /app

COPY --from=web-builder /workspace/app/build/web/ ./web/

EXPOSE 8080

CMD ["python3", "-m", "http.server", "8080", "--directory", "/app/web"]