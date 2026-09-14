#!/bin/bash
# Portable launcher: copy this whole folder to any PC and run with:
#   bash RUN.sh
# Needs only Python 3 (no Flutter, no dependencies). Works offline.
set -u
cd "$(dirname "$0")"

APP_NAME="Talk To Me Spanish"
DEFAULT_PORT=8002
WEB_DIR="app/build/web"

if ! command -v python3 >/dev/null 2>&1; then
  echo "ERROR: Python 3 is required but was not found."
  echo "Install it from https://www.python.org/downloads/ then run again."
  exit 1
fi

if [ ! -f "$WEB_DIR/index.html" ]; then
  echo "ERROR: prebuilt web app not found in $WEB_DIR"
  echo "On a machine with Flutter, run:  cd app && flutter build web --release"
  exit 1
fi

# Recreate Flutter double-nesting symlinks if the copy lost them (e.g. USB/FAT32)
for dir in audio course; do
  if [ -d "$WEB_DIR/assets/assets/$dir" ] && [ ! -e "$WEB_DIR/assets/$dir" ]; then
    (cd "$WEB_DIR/assets" && ln -s "assets/$dir" "$dir" 2>/dev/null) || \
      { echo "WARNING: cannot create symlink for $dir - audio may 404"; }
  fi
done

# Pick first free port starting at DEFAULT_PORT
PORT=$DEFAULT_PORT
while python3 -c "import socket; s=socket.socket(); s.bind(('', $PORT))" 2>/dev/null; [ $? -ne 0 ]; do
  PORT=$((PORT + 1))
  if [ "$PORT" -gt "$((DEFAULT_PORT + 20))" ]; then
    echo "ERROR: no free port near $DEFAULT_PORT"
    exit 1
  fi
done

URL="http://localhost:$PORT"
echo "Starting $APP_NAME on $URL ..."
if command -v xdg-open >/dev/null 2>&1; then
  (sleep 1 && xdg-open "$URL" >/dev/null 2>&1 &) || true
fi
python3 serve_web.py "$PORT" "$WEB_DIR"
