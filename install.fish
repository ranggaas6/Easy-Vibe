#!/usr/bin/env fish
# Easy-Vibe Installer untuk CachyOS + fish
# Pemakaian: fish install.fish [--clean] [--force] [--upstream] [--skip-gitdesktop] [--github-token TOKEN]

set -l SCRIPT_DIR (dirname (status --current-filename))
source "$SCRIPT_DIR/scripts/github-auth.fish"
source "$SCRIPT_DIR/scripts/install-base.fish"
source "$SCRIPT_DIR/scripts/install-bridge.fish"
source "$SCRIPT_DIR/scripts/install-gitdesktop.fish"

set -l REPO_PATH (pwd)
set -l INSTALL_DIR "$HOME/.easy-vibe"
set -l BRIDGE_DIR "$INSTALL_DIR/web-mcp-bridge"
set -l VENV_DIR "$INSTALL_DIR/venv"
set -l MANIFEST "$INSTALL_DIR/manifest.txt"
set -l TOKEN_FILE "$INSTALL_DIR/github-token"
set -l CLEAN 0
set -l FORCE 0
set -l USE_UPSTREAM 0
set -l CLI_TOKEN ""
set -g EASY_VIBE_SKIP_GITDESKTOP 0

set -l i 1
while test $i -le (count $argv)
    set -l a $argv[$i]
    switch $a
        case --clean
            set CLEAN 1
        case --force
            set FORCE 1
        case --upstream
            set USE_UPSTREAM 1
        case --skip-gitdesktop
            set -g EASY_VIBE_SKIP_GITDESKTOP 1
        case --github-token
            set i (math $i + 1)
            if test $i -gt (count $argv)
                echo "--github-token butuh nilai" >&2
                exit 1
            end
            set CLI_TOKEN $argv[$i]
        case -h --help
            echo "Pemakaian: fish install.fish [--clean] [--force] [--upstream] [--skip-gitdesktop] [--github-token TOKEN]"
            exit 0
        case '*'
            echo "Opsi tidak dikenal: $a" >&2
            exit 1
    end
    set i (math $i + 1)
end

# 0. Token
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
        printf '[GAGAL] Format token tidak valid (harus ghp_ atau github_pat_)\n' >&2
        exit 1
    end
    if test -n "$CLI_TOKEN"; or not test -f "$TOKEN_FILE"
        gh_token_save $GH_TOKEN
        printf '[OK] Token GitHub disimpan di %s (chmod 600)\n' $TOKEN_FILE
    end
else
    printf '[PERINGATAN] Token GitHub tidak diberikan. Clone repo private akan gagal.\n'
    printf 'Gunakan: fish install.fish --github-token ghp_xxx\n'
end

# 1. Sumber bridge
if test $USE_UPSTREAM -eq 1
    set -l BRIDGE_REPO "https://github.com/AstraxOf/web-mcp-bridge"
    set -l CONTROL_PORT 8099
    set -l LAUNCHER_PORT 8098
    set -l HUB_PORT 8090
    set -l BRIDGE_LABEL "upstream"
else
    set -l BRIDGE_REPO "https://github.com/ranggaas6/web-mcp-bridge"
    set -l CONTROL_PORT 8199
    set -l LAUNCHER_PORT 8198
    set -l HUB_PORT 8190
    set -l BRIDGE_LABEL "fork"
end

# 1a. Validasi
if not test -d "$REPO_PATH/.git"
    printf '[GAGAL] Bukan repositori Git: %s\n' $REPO_PATH >&2
    exit 1
end
if not command -v pacman >/dev/null 2>&1
    printf '[GAGAL] pacman tidak ditemukan\n' >&2
    exit 1
end

# 1b. Bersihkan
if test $CLEAN -eq 1
    if test -f "$SCRIPT_DIR/uninstall.fish"
        fish "$SCRIPT_DIR/uninstall.fish" --yes
    else if test -f uninstall.fish
        fish uninstall.fish --yes
    else
        rm -rf "$INSTALL_DIR"
    end
else if test -f "$MANIFEST" -a $FORCE -eq 0
    printf '[GAGAL] Instalasi lama terdeteksi. Pakai --clean atau --force.\n' >&2
    exit 1
end

mkdir -p "$INSTALL_DIR"
set -g manifest_lines "installed_at "(date -Iseconds)
set -a manifest_lines "bridge_source $BRIDGE_REPO"
if test -n "$GH_TOKEN"
    set -a manifest_lines "github-token-file $TOKEN_FILE"
end

# 2. Prasyarat
install_prasyarat
or begin
    printf '[GAGAL] Prasyarat dasar gagal\n' >&2
    exit 1
end

# 3. Tool MCP
install_gitrs
install_filesystem

# 4. GitDesktop
printf '\n== Memasang GitDesktop (hub MCP) ==\n'
install_gitdesktop "$HOME/Applications/GitDesktop.AppImage" "$HOME/.local/bin/gitdesktop-mcp"

# 5. Bridge
install_bridge $BRIDGE_REPO $BRIDGE_DIR $VENV_DIR $GH_TOKEN
or begin
    printf '[GAGAL] Bridge gagal disiapkan\n' >&2
    exit 1
end

# 6. servers.json
printf '\n== Menulis servers.json ==\n'
printf '{\n  "control_port": %d,\n  "launcher_port": %d,\n  "servers": [\n    {\n      "name": "gitdesktop",\n      "port": %d,\n      "command": ["gitdesktop-mcp"]\n    }\n  ]\n}\n' $CONTROL_PORT $LAUNCHER_PORT $HUB_PORT > "$BRIDGE_DIR/server/servers.json"
printf '[OK] servers.json ditulis\n'

# 7. Snippet server anak
set -l snippet_path "$INSTALL_DIR/gitdesktop-mcp-servers.json"
printf '{\n  "mcpServers": {\n    "gitrs": {\n      "command": "gitrs-mcp",\n      "args": ["--repo", "%s"]\n    },\n    "filesystem": {\n      "command": "mcp-filesystem-server",\n      "args": ["%s"]\n    }\n  }\n}\n' "$REPO_PATH" "$REPO_PATH" > $snippet_path
printf '[OK] Snippet: %s\n' $snippet_path

# 8. Launcher
set -l launcher "$INSTALL_DIR/start-easy-vibe.fish"
printf '#!/usr/bin/env fish\ncd "%s"\nexec "%s/bin/python" server/mcp_ws_bridge.py --config server/servers.json\n' "$BRIDGE_DIR" "$VENV_DIR" > $launcher
chmod +x $launcher
printf '[OK] Launcher: %s\n' $launcher

# 9. Layanan
if test "$EASY_VIBE_INSTALL_SERVICE" = "1"
    pushd $BRIDGE_DIR
    "$VENV_DIR/bin/python" server/install_service.py
    popd
    set -a manifest_lines "systemd-user easy-vibe"
    printf '[OK] Layanan dipasang\n'
else
    printf '[PERINGATAN] Layanan tidak dipasang (set EASY_VIBE_INSTALL_SERVICE=1)\n'
end

# 10. Manifest
printf '%s\n' $manifest_lines > "$MANIFEST"
printf '[OK] Manifest: %s\n' $MANIFEST

# 11. Ringkasan
printf '\n== Selesai ==\n'
printf 'Bridge: %s | port kontrol %d, launcher %d, hub %d\n' $BRIDGE_LABEL $CONTROL_PORT $LAUNCHER_PORT $HUB_PORT
if test -n "$GH_TOKEN"
    printf 'Token GitHub: %s\n' $TOKEN_FILE
end
if not command -v gitdesktop-mcp >/dev/null 2>&1
    printf 'Langkah manual: buka GitDesktop -> Settings -> Use GitDesktop as an MCP server -> Add to PATH\n'
end
printf 'Snippet server anak: %s\n' $snippet_path
printf 'Ekstensi browser: %s\n' "$BRIDGE_DIR"
printf 'Launcher: %s\n\n' $launcher
