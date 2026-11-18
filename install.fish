#!/usr/bin/env fish
set -l SCRIPT_DIR (realpath (dirname (status --current-filename)))
source "$SCRIPT_DIR/scripts/token-vault.fish"
source "$SCRIPT_DIR/scripts/github-auth.fish"
source "$SCRIPT_DIR/scripts/install-base.fish"
source "$SCRIPT_DIR/scripts/install-bridge.fish"
source "$SCRIPT_DIR/scripts/install-native-host.fish"
source "$SCRIPT_DIR/scripts/install-audit.fish"
set -l INSTALL_DIR "$HOME/.easy-vibe"
set -l BRIDGE_DIR "$INSTALL_DIR/web-mcp-bridge"
set -l VENV_DIR "$INSTALL_DIR/venv"
set -l MANIFEST "$INSTALL_DIR/manifest.txt"
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
# Mode interaktif: tawarkan tempel token baru (input tersembunyi), tanpa token di argumen perintah.
if test -z "$CLI_TOKEN"; and isatty stdin
  if test -n "$GH_TOKEN"
    printf '\n  Token GitHub sudah ada (sumber: %s).\n' $GH_TOKEN_SOURCE
    read -l -s -P '  Tempel token baru untuk mengganti, atau Enter untuk memakai yang ada: ' new_token
    printf '\n'
    if test -n "$new_token"
      if not gh_token_validate $new_token; printf '[GAGAL] Format token tidak valid\n' >&2; exit 1; end
      set -g GH_TOKEN $new_token
      set -g GH_TOKEN_SOURCE "input"
      printf '[OK] Token baru diterima\n'
    end
  end
end
if test -n "$GH_TOKEN"
  if not gh_token_validate $GH_TOKEN; printf '[GAGAL] Format token tidak valid\n' >&2; exit 1; end
  # token disimpan ke keyring pada langkah di bawah (bukan ke berkas)
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
    printf '[OK] Token diterima (disimpan ke keyring pada langkah berikutnya)\n'
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
set -l ALLOWED_CMDS "cargo,rustc,git,pgrep,node,npm,pacman,busctl,fish,diff,python3,llvm,llvm-mc,sed,grep,clang,clang++,gcc,g++"
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
set -g TOKEN_IN_VAULT 0
if test -n "$GH_TOKEN"
  if gh_token_save $GH_TOKEN
    set -g TOKEN_IN_VAULT 1
    printf '[OK] Token disimpan di keyring (bukan berkas)\n'
    # git push non-interaktif (coding_mcp) lewat helper libsecret, tanpa ~/.git-credentials
    if gh_setup_git_credential $GH_TOKEN
      printf '[OK] git credential.helper=libsecret (keyring) disiapkan\n'
    else
      printf '[PERINGATAN] Gagal menyiapkan credential.helper libsecret\n'
    end
  else
    printf '[PERINGATAN] Keyring tidak siap: token tidak disimpan, server github dan git push non-interaktif tidak aktif\n'
  end
end
set -g manifest_lines "installed_at "(date -Iseconds)
set -g manifest_lines $manifest_lines "bridge_source $BRIDGE_REPO"
set -g manifest_lines $manifest_lines "extension-id $EXT_ID"
set -g manifest_lines $manifest_lines "coding-mcp-allowlist $ALLOWED_CMDS"
if test "$TOKEN_IN_VAULT" = 1
  set -g manifest_lines $manifest_lines "keyring-item easy-vibe/github"
  set -g manifest_lines $manifest_lines "git-credentials-file $HOME/.git-credentials"
end
install_prasyarat; or exit 1
# Pada mesin baru libsecret baru terpasang di sini: ulangi penyimpanan token ke keyring.
if test -n "$GH_TOKEN"; and test "$TOKEN_IN_VAULT" != 1
  set -g TV_OK ""
  if gh_token_save $GH_TOKEN
    set -g TOKEN_IN_VAULT 1
    printf '[OK] Token disimpan di keyring (bukan berkas)\n'
    if gh_setup_git_credential $GH_TOKEN
      printf '[OK] git credential.helper=libsecret (keyring) disiapkan\n'
    end
    set -g manifest_lines $manifest_lines "keyring-item easy-vibe/github"
    set -g manifest_lines $manifest_lines "git-credentials-file $HOME/.git-credentials"
  end
end
install_filesystem; or exit 1
install_coding_mcp; or exit 1
install_github_mcp; or exit 1
if test -z "$CODING_BIN"; or test -z "$FS_BIN"; or test -z "$GITHUB_BIN"
  printf '[GAGAL] Path server tidak lengkap\n' >&2
  exit 1
end
printf '\n== Web MCP Bridge ==\n'
install_bridge $BRIDGE_REPO $BRIDGE_DIR $VENV_DIR $GH_TOKEN; or exit 1
if test -d "$BRIDGE_DIR"
    coding-mcp init "$BRIDGE_DIR"
    and set -a manifest_lines "coding-mcp-root $BRIDGE_DIR"
    and printf '[OK]   coding-mcp root tambahan: %s\n' "$BRIDGE_DIR"
    or printf '[PERINGATAN] coding-mcp init %s gagal (dilanjutkan)\n' "$BRIDGE_DIR"
end
printf '\n== Native host ==\n'
install_native_host "$SCRIPT_DIR/scripts/native-host/easy-vibe-host" $EXT_ID "$SCRIPT_DIR/scripts/native-host/easy-vibe-watcher"; or exit 1
install_audit "$INSTALL_DIR" "$SCRIPT_DIR"
printf '\n== Menulis servers.json ==\n'
set -l gh_env ""
set -l GITHUB_CMD $GITHUB_BIN
if test "$TOKEN_IN_VAULT" = 1
  tv_write_github_wrapper $GITHUB_BIN "$INSTALL_DIR/bin/github-mcp-wrapper"
  set GITHUB_CMD "$INSTALL_DIR/bin/github-mcp-wrapper"
  printf '[OK]   Server github memakai token dari keyring (servers.json tanpa token)\n'
else
  printf '[PERINGATAN] Token tidak ada di keyring: server github berjalan tanpa token\n'
end
printf '{\n  "control_port": %d,\n  "launcher_port": %d,\n  "servers": [\n    { "name": "coding-mcp", "port": %d, "command": ["%s", "serve", "--transport", "stdio"], "env": { "ALLOWED_COMMANDS": "%s" } },\n    { %s"name": "github", "port": %d, "command": ["%s"] },\n    { "name": "filesystem", "port": %d, "command": ["%s", "%s"] }\n  ]\n}\n' $CONTROL_PORT $LAUNCHER_PORT $CODING_PORT (audit_wrap coding-mcp $CODING_BIN) "$ALLOWED_CMDS" "$gh_env" $GITHUB_PORT (audit_wrap github $GITHUB_CMD) $FS_PORT $FS_BIN $HOME > "$BRIDGE_DIR/server/servers.json"
chmod 600 "$BRIDGE_DIR/server/servers.json"
if test "$TOKEN_IN_VAULT" = 1
  tv_migrate_git_credentials
  tv_scrub_legacy
  printf '[OK]   Sisa token plaintext (github-token, ~/.git-credentials, cadangan servers.json, log) dibersihkan\n'
end
set -l launcher "$INSTALL_DIR/start-easy-vibe.fish"
printf '#!/usr/bin/env fish\npkill -f audit-brief.py 2>/dev/null\nif test -f "%s/audit-brief.py"\n  setsid python3 "%s/audit-brief.py" >/dev/null 2>&1 &\nend\ncd "%s"\nexec "%s/bin/python" server/mcp_ws_bridge.py --config server/servers.json\n' "$INSTALL_DIR" "$INSTALL_DIR" "$BRIDGE_DIR" "$VENV_DIR" > $launcher
chmod +x $launcher
pkill -f mcp_ws_bridge.py 2>/dev/null
pkill -f audit-brief.py 2>/dev/null
sleep 1
printf '%s\n' $manifest_lines > "$MANIFEST"
printf '\n== Selesai ==\n'
printf 'coding-mcp: %s\n' $CODING_BIN
printf 'github:     %s\n' $GITHUB_BIN
printf 'filesystem: %s\n' $FS_BIN
printf 'Pemicu: buka tab DeepSeek di Brave.\n'
