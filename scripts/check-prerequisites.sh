#!/usr/bin/env bash
# Memeriksa prasyarat Easy-Vibe.
# Pemakaian: bash scripts/check-prerequisites.sh

set -u

exit_code=0

check_command() {
  local name="$1"
  if command -v "$name" >/dev/null 2>&1; then
    printf '[OK]   %s ditemukan: %s\n' "$name" "$(command -v "$name")"
  else
    printf '[GAGAL] %s tidak ditemukan\n' "$name"
    exit_code=1
  fi
}

check_version() {
  local name="$1"
  local min_major="$2"
  local raw version major
  raw=$("$name" --version 2>&1 | head -n 1)
  version=$(printf '%s' "$raw" | grep -Eo '[0-9]+\.[0-9]+(\.[0-9]+)?' | head -n 1)
  if [ -z "$version" ]; then
    printf '[PERINGATAN] Tidak dapat membaca versi %s dari: %s\n' "$name" "$raw"
    return
  fi
  major=${version%%.*}
  if [ "$major" -lt "$min_major" ]; then
    printf '[PERINGATAN] %s versi %s, disarankan minimal %s.x\n' "$name" "$version" "$min_major"
  else
    printf '[OK]   %s versi %s\n' "$name" "$version"
  fi
}

echo '== Memeriksa perangkat dasar =='
check_command git
check_command python3
check_command go

echo
echo '== Memeriksa versi =='
if command -v python3 >/dev/null 2>&1; then
  check_version python3 3
fi
if command -v go >/dev/null 2>&1; then
  check_version go 1
fi

echo
echo '== Memeriksa server MCP =='
check_command gitrs-mcp
check_command mcp-filesystem-server

echo
echo '== Memeriksa berkas konfigurasi =='
for f in config/bridge-servers.example.json config/mcp.json prompts/system-prompt-id.md; do
  if [ -f "$f" ]; then
    printf '[OK]   %s ada\n' "$f"
  else
    printf '[GAGAL] %s tidak ditemukan\n' "$f"
    exit_code=1
  fi
done

echo
if [ "$exit_code" -eq 0 ]; then
  echo 'Semua prasyarat wajib terpenuhi.'
else
  echo 'Ada prasyarat yang belum terpenuhi. Perbaiki lalu jalankan ulang.'
fi

exit "$exit_code"
