# Build stage
FROM ghcr.io/cirruslabs/flutter:3.29.3 AS build
WORKDIR /app
COPY pubspec.yaml pubspec.lock ./
RUN flutter pub get --enforce-lockfile
COPY . .
RUN flutter build apk --release --obfuscate --split-debug-info=build/debug-info --target-platform android-arm64

# Runtime stage (minimal)
FROM alpine:3.20
COPY --from=build /app/build/app/outputs/flutter-apk/app-release.apk /app-release.apk
