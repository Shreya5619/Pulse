#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
SERVER_DIR="$ROOT_DIR/server"
PORT="${PULSE_HTTP_PORT:-8080}"
HOST="${PULSE_HTTP_HOST:-127.0.0.1}"
BASE_URL="http://$HOST:$PORT"

echo "==> [Pulse] Seeding demo data..."
node "$ROOT_DIR/scripts/seed-demo-data.ts"

echo "==> [Pulse] Starting server on $BASE_URL ..."
cd "$SERVER_DIR"

if [ -f package.json ]; then
  if npm run | grep -q "dev"; then
    npm run dev &
  else
    echo "No dev script found in server/package.json"
    exit 1
  fi
else
  echo "server/package.json not found"
  exit 1
fi

SERVER_PID=$!
trap 'echo "==> [Pulse] Stopping server..."; kill $SERVER_PID >/dev/null 2>&1 || true' EXIT

echo "==> [Pulse] Waiting for health check..."
for i in {1..40}; do
  if curl -sf "$BASE_URL/health" >/dev/null; then
    echo "==> [Pulse] Server is healthy"
    break
  fi
  sleep 1
done

if ! curl -sf "$BASE_URL/health" >/dev/null; then
  echo "Health check failed for $BASE_URL/health"
  exit 1
fi

echo "==> [Pulse] Replaying demo scenario..."
node "$ROOT_DIR/scripts/replay-demo.ts"

echo "==> [Pulse] Demo replay sent successfully."
echo "==> [Pulse] Press Ctrl+C to stop."
wait $SERVER_PID