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
            # dipertahankan untuk kompatibilitas
        case --upstream
            printf '[GAGAL] --upstream tidak lagi didukung: native messaging hanya ada di fork ranggaas6/web-mcp-bridge.\n' >&2
            exit 1
        case --github-token
            set i (math $i + 1)
            if test $i -gt (count $argv)
                echo "--github-token butuh nilai" >&2
                exit 1
            end
            set CLI_TOKEN $argv[$i]
        case --extension-id
            set i (math $i + 1)
            if test $i -gt (count $argv)
                echo "--extension-id butuh nilai" >&2
                exit 1
            end
            set EXT_ID $argv[$i]
        case -h --help
            echo "Pemakaian: fish install.fish [--clean] [--force] [--github-token TOKEN] --extension-id ID"
            exit 0
        case '*'
            echo "Opsi tidak dikenal: $a" >&2
            exit 1
    end
    set i (math $i + 1)
end
set -g GH_TOKEN ""
set -l tok_args
if test -n "$CLI_TOKEN"
    set tok_args --github-token $CLI_TOKEN
end
if gh_token_resolve $tok_args
    set -g GH_TOKEN $GH_TOKEN_RESOLVED
end
if test -n "$GH_TOKEN"
    if not gh_token_validate $GH_TOKEN
        printf '[GAGAL] Format token tidak valid\n' >&2
        exit 1
    end
    if test -n "$CLI_TOKEN"; or not test -f "$TOKEN_FILE"
        gh_token_save $GH_TOKEN
        printf '[OK] Token GitHub disimpan\n'
    end
else
    printf '[PERINGATAN] Token GitHub tidak diberikan.\n'
end
if test -z "$EXT_ID"
    printf '[GAGAL] --extension-id wajib diisi (ID extension Web MCP Bridge di brave://extensions)\n' >&2
    exit 1
end
set -l BRIDGE_REPO "https://github.com/ranggaas6/web-mcp-bridge"
set -l CONTROL_PORT 8199
set -l LAUNCHER_PORT 8198
set -l CODING_PORT 8190
set -l FS_PORT 8192
if not command -v pacman >/dev/null 2>&1
    printf '[GAGAL] pacman tidak ditemukan\n' >&2
    exit 1
end
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
set -g manifest_lines "installed_at "(date -Iseconds)
set -g manifest_lines $manifest_lines "bridge_source $BRIDGE_REPO"
set -g manifest_lines $manifest_lines "extension-id $EXT_ID"
if test -n "$GH_TOKEN"
    set -g manifest_lines $manifest_lines "github-token-file $TOKEN_FILE"
end
install_prasyarat; or exit 1
install_filesystem; or exit 1
install_coding_mcp; or exit 1
if test -z "$CODING_BIN"; or test -z "$FS_BIN"
    printf '[GAGAL] Path coding-mcp atau filesystem tidak terdeteksi\n' >&2
    exit 1
end
printf '\n== Web MCP Bridge ==\n'
install_bridge $BRIDGE_REPO $BRIDGE_DIR $VENV_DIR $GH_TOKEN; or exit 1
printf '\n== Native host ==\n'
install_native_host "$SCRIPT_DIR/scripts/native-host/easy-vibe-host" $EXT_ID; or exit 1
printf '\n== Menulis servers.json ==\n'
printf '{\n  "control_port": %d,\n  "launcher_port": %d,\n  "servers": [\n    {\n      "name": "coding-mcp",\n      "port": %d,\n      "command": ["%s", "serve", "--transport", "stdio"]\n    },\n    {\n      "name": "filesystem",\n      "port": %d,\n      "command": ["%s", "%s"]\n    }\n  ]\n}\n' $CONTROL_PORT $LAUNCHER_PORT $CODING_PORT $CODING_BIN $FS_PORT $FS_BIN $HOME > "$BRIDGE_DIR/server/servers.json"
set -l launcher "$INSTALL_DIR/start-easy-vibe.fish"
printf '#!/usr/bin/env fish\ncd "%s"\nexec "%s/bin/python" server/mcp_ws_bridge.py --config server/servers.json\n' "$BRIDGE_DIR" "$VENV_DIR" > $launcher
chmod +x $launcher
pkill -f mcp_ws_bridge.py 2>/dev/null
sleep 1
printf '%s\n' $manifest_lines > "$MANIFEST"
printf '\n== Selesai ==\n'
printf 'coding-mcp: %s\n' $CODING_BIN
printf 'filesystem: %s\n' $FS_BIN
printf 'Pemicu: buka tab DeepSeek di Brave (bridge hidup), tutup tab (bridge mati).\n'
