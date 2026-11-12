#!/usr/bin/env fish
set -l SCRIPT_DIR (realpath (dirname (status --current-filename)))
source "$SCRIPT_DIR/scripts/github-auth.fish"
source "$SCRIPT_DIR/scripts/install-base.fish"
source "$SCRIPT_DIR/scripts/install-bridge.fish"
source "$SCRIPT_DIR/scripts/install-native-host.fish"
set -l INSTALL_DIR "$HOME/.easy-vibe"
set -l BRIDGE_DIR "$INSTALL_DIR/web-mcp-bridge"
set -l VENV_DIR "$INSTALL_DIR/venv"
set -l MANIFEST "$INSTALL_DIR/manifest.txt"
set -l TOKEN_FILE "$INSTALL_DIR/github-token"
set -l CLEAN 0
set -l FORCE 0
set -l CLI_TOKEN ""
set -l EXT_ID ""
set -l i 1
while test $i -le (count $argv)
  set -l a $argv[$i]
  switch $a
    case --clean
      set CLEAN 1
    case --force
      set FORCE 1
    case --skip-gitdesktop
    case --upstream
      printf '[GAGAL] --upstream tidak didukung: native messaging hanya ada di fork.\n' >&2
      exit 1
    case --github-token
      set i (math $i + 1)
      if test $i -gt (count $argv); echo "--github-token butuh nilai" >&2; exit 1; end
      set CLI_TOKEN $argv[$i]
    case --extension-id
      set i (math $i + 1)
      if test $i -gt (count $argv); echo "--extension-id butuh nilai" >&2; exit 1; end
      set EXT_ID $argv[$i]
    case -h --help
      echo "Pemakaian: fish install.fish [--clean] [--force] [--github-token TOKEN] --extension-id ID"
      exit 0
    case '*'
      echo "Opsi tidak dikenal: $a" >&2; exit 1
  end
  set i (math $i + 1)
end
set -g GH_TOKEN ""
set -l tok_args
if test -n "$CLI_TOKEN"; set tok_args --github-token $CLI_TOKEN; end
if gh_token_resolve $tok_args; set -g GH_TOKEN $GH_TOKEN_RESOLVED; end
if test -n "$GH_TOKEN"
  if not gh_token_validate $GH_TOKEN; printf '[GAGAL] Format token tidak valid\n' >&2; exit 1; end
  if test -n "$CLI_TOKEN"; or not test -f "$TOKEN_FILE"
    gh_token_save $GH_TOKEN
  end
else
  printf '\n'
  printf '  Token GitHub tidak ditemukan.\n'
  printf '  Server github memerlukan PAT dengan scope \'repo\'.\n'
  printf '  Tekan Enter untuk melewati (server github tidak akan aktif).\n'
  read -l -s -P '  GitHub token: ' input_token
  printf '\n'
  if test -n "$input_token"
    if not gh_token_validate $input_token
      printf '[GAGAL] Format token tidak valid\n' >&2
      exit 1
    end
    set -g GH_TOKEN $input_token
    gh_token_save $GH_TOKEN
    printf '[OK] Token disimpan\n'
  else
    printf '[PERINGATAN] Tanpa token, server github tidak akan aktif.\n'
  end
end
if test -z "$EXT_ID"; printf '[GAGAL] --extension-id wajib diisi\n' >&2; exit 1; end
set -l BRIDGE_REPO "https://github.com/ranggaas6/web-mcp-bridge"
set -l CONTROL_PORT 8199
set -l LAUNCHER_PORT 8198
set -l CODING_PORT 8190
set -l GITHUB_PORT 8191
set -l FS_PORT 8192
if not command -v pacman >/dev/null 2>&1; printf '[GAGAL] pacman tidak ditemukan\n' >&2; exit 1; end
if test $CLEAN -eq 1
  if test -f "$SCRIPT_DIR/uninstall.fish"
    fish "$SCRIPT_DIR/uninstall.fish" --yes
  else
    rm -rf "$INSTALL_DIR"
  end
else if test -f "$MANIFEST" -a $FORCE -eq 0
  printf '[GAGAL] Instalasi lama terdeteksi. Pakai --clean atau --force.\n' >&2
  exit 1
end
mkdir -p "$INSTALL_DIR"
if test -n "$GH_TOKEN"
  gh_token_save $GH_TOKEN
end
set -g manifest_lines "installed_at "(date -Iseconds)
set -g manifest_lines $manifest_lines "bridge_source $BRIDGE_REPO"
set -g manifest_lines $manifest_lines "extension-id $EXT_ID"
if test -n "$GH_TOKEN"
  set -g manifest_lines $manifest_lines "github-token-file $TOKEN_FILE"
end
install_prasyarat; or exit 1
install_filesystem; or exit 1
install_coding_mcp; or exit 1
install_github_mcp; or exit 1
if test -z "$CODING_BIN"; or test -z "$FS_BIN"; or test -z "$GITHUB_BIN"
  printf '[GAGAL] Path server tidak lengkap\n' >&2
  exit 1
end
printf '\n== Web MCP Bridge ==\n'
install_bridge $BRIDGE_REPO $BRIDGE_DIR $VENV_DIR $GH_TOKEN; or exit 1
printf '\n== Native host ==\n'
install_native_host "$SCRIPT_DIR/scripts/native-host/easy-vibe-host" $EXT_ID "$SCRIPT_DIR/scripts/native-host/easy-vibe-watcher"; or exit 1
printf '\n== Menulis servers.json ==\n'
set -l gh_env ""
if test -n "$GH_TOKEN"
  set gh_env "\"env\": { \"GITHUB_TOKEN\": \"$GH_TOKEN\" }, "
end
printf '{\n  "control_port": %d,\n  "launcher_port": %d,\n  "servers": [\n    { "name": "coding-mcp", "port": %d, "command": ["%s", "serve", "--transport", "stdio"] },\n    { %s"name": "github", "port": %d, "command": ["%s"] },\n    { "name": "filesystem", "port": %d, "command": ["%s", "%s"] }\n  ]\n}\n' $CONTROL_PORT $LAUNCHER_PORT $CODING_PORT $CODING_BIN "$gh_env" $GITHUB_PORT $GITHUB_BIN $FS_PORT $FS_BIN $HOME > "$BRIDGE_DIR/server/servers.json"
chmod 600 "$BRIDGE_DIR/server/servers.json"
set -l launcher "$INSTALL_DIR/start-easy-vibe.fish"
printf '#!/usr/bin/env fish\ncd "%s"\nexec "%s/bin/python" server/mcp_ws_bridge.py --config server/servers.json\n' "$BRIDGE_DIR" "$VENV_DIR" > $launcher
chmod +x $launcher
pkill -f mcp_ws_bridge.py 2>/dev/null
sleep 1
printf '%s\n' $manifest_lines > "$MANIFEST"
printf '\n== Selesai ==\n'
printf 'coding-mcp: %s\n' $CODING_BIN
printf 'github:     %s\n' $GITHUB_BIN
printf 'filesystem: %s\n' $FS_BIN
printf 'Pemicu: buka tab DeepSeek di Brave.\n'
