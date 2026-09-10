#!/usr/bin/env bash
set -e

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
APP_DIR="$SCRIPT_DIR/app"
WEB_PORT=8002

export JAVA_HOME="${JAVA_HOME:-/home/antix/.local/jdk17}"
export ANDROID_HOME="${ANDROID_HOME:-/home/antix/.local/android-sdk}"

echo "=== Building Talk To Me Spanish ==="
echo ""

cd "$APP_DIR"

echo "[1/4] Building APK..."
flutter build apk --release --target-platform android-arm64
cp build/app/outputs/flutter-apk/app-release.apk "$SCRIPT_DIR/TalkToMeES.apk"
echo "APK saved to: $SCRIPT_DIR/TalkToMeES.apk"

echo ""
echo "[2/4] Building Linux Desktop..."
if flutter build linux --release; then
  rm -rf "$SCRIPT_DIR/TalkToMeES-linux"
  cp -r build/linux/x64/release/bundle "$SCRIPT_DIR/TalkToMeES-linux"
  echo "Linux desktop saved to: $SCRIPT_DIR/TalkToMeES-linux"
else
  echo "WARNING: Linux desktop build failed (needs libgtk-3-dev, cmake, ninja-build, clang). Skipping."
fi

echo ""
echo "[3/4] Building Web..."
flutter build web --release

WEB_DIR="$APP_DIR/build/web"
for dir in audio course; do
  if [ -d "$WEB_DIR/assets/assets/$dir" ] && [ ! -e "$WEB_DIR/assets/$dir" ]; then
    (cd "$WEB_DIR/assets" && ln -s "assets/$dir" "$dir")
    echo "Symlinked $dir"
  fi
done

echo ""
echo "[4/4] Starting web server on port $WEB_PORT..."
echo "Open http://localhost:$WEB_PORT in your browser"
python3 "$SCRIPT_DIR/serve_web.py" "$WEB_PORT" build/web
