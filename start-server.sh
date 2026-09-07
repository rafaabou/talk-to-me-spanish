#!/bin/bash
SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
WEB_DIR="$SCRIPT_DIR/app/build/web"
PORT=8002

if [ ! -d "$WEB_DIR" ]; then
  echo "ERROR: Web build not found at $WEB_DIR"
  echo "Run: cd app && flutter build web --release"
  exit 1
fi

fuser -k "$PORT/tcp" 2>/dev/null

nohup python3 -m http.server "$PORT" --directory "$WEB_DIR" --bind 0.0.0.0 > /dev/null 2>&1 &

sleep 1

if curl -s -o /dev/null http://localhost:$PORT; then
  echo "Server running on http://localhost:$PORT"
  xdg-open "http://localhost:$PORT" 2>/dev/null
else
  echo "Failed to start server"
fi
