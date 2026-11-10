#!/usr/bin/env bash
# Menjalankan Web MCP Bridge untuk Easy-Vibe.
# Pemakaian: bash scripts/start-bridge.sh [path-ke-web-mcp-bridge]

set -euo pipefail

BRIDGE_DIR="${1:-${WEB_MCP_BRIDGE_DIR:-../web-mcp-bridge}}"
CONFIG_DIR="$(cd "$(dirname "$0")/.." && pwd)/config"
TARGET_CONFIG="$BRIDGE_DIR/server/servers.json"

if [ ! -d "$BRIDGE_DIR" ]; then
  echo "Direktori Web MCP Bridge tidak ditemukan: $BRIDGE_DIR" >&2
  echo "Clone dulu: git clone https://github.com/AstraxOf/web-mcp-bridge" >&2
  exit 1
fi

if [ ! -f "$TARGET_CONFIG" ]; then
  if [ -f "$CONFIG_DIR/bridge-servers.example.json" ]; then
    echo "Menyalin contoh konfigurasi ke $TARGET_CONFIG"
    cp "$CONFIG_DIR/bridge-servers.example.json" "$TARGET_CONFIG"
    echo "EDIT dulu $TARGET_CONFIG dan ganti path CHANGE_ME dengan path repo Anda." >&2
    exit 1
  else
    echo "Konfigurasi tidak ditemukan: $TARGET_CONFIG" >&2
    exit 1
  fi
fi

if [ ! -f "$BRIDGE_DIR/server/mcp_ws_bridge.py" ]; then
  echo "Skrip bridge tidak ditemukan: $BRIDGE_DIR/server/mcp_ws_bridge.py" >&2
  exit 1
fi

echo "Menjalankan bridge dengan konfigurasi $TARGET_CONFIG"
echo "Bridge mendengarkan di 127.0.0.1. Jangan mengekspos ke jaringan publik."

exec python3 "$BRIDGE_DIR/server/mcp_ws_bridge.py" --config "$TARGET_CONFIG"
