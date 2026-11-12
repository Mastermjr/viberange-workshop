#!/usr/bin/env bash
set -euo pipefail

SERVICE="${SERVICE:-vector}"
CONFIG="${CONFIG:-/etc/vector/vector.toml}"

echo "== Vector config =="
if command -v vector >/dev/null 2>&1; then
  vector validate "$CONFIG"
else
  echo "vector binary not found; checking systemd only" >&2
fi

echo "== Vector service =="
if command -v systemctl >/dev/null 2>&1; then
  systemctl --no-pager --full status "$SERVICE" || true
  journalctl -u "$SERVICE" -n 50 --no-pager || true
else
  echo "systemctl unavailable"
fi
