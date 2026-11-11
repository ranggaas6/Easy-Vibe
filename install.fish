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
        printf '[GAGAL] Format token tidak valid (ghp_ atau github_pat_)\n' >&2
        exit 1
    end
    if test -n "$CLI_TOKEN"; or not test -f "$TOKEN_FILE"
        gh_token_save $GH_TOKEN
        printf '[OK] Token GitHub disimpan di %s (chmod 600)\n' $TOKEN_FILE
    end
else
    printf '[PERINGATAN] Token GitHub tidak diberikan. Clone repo private akan gagal.\n'
end

# 1. Sumber bridge
# PENTING: set -l di dalam blok if pada fish bersifat lokal ke blok itu saja.
# Deklarasikan di level skrip, isi ulang dengan `set` (tanpa -l) di dalam blok.
set -l BRIDGE_REPO "https://github.com/ranggaas6/web-mcp-bridge"
set -l CONTROL_PORT 8199
set -l LAUNCHER_PORT 8198
set -l HUB_PORT 8190
set -l BRIDGE_LABEL "fork"
if test $USE_UPSTREAM -eq 1
    set BRIDGE_REPO "https://github.com/AstraxOf/web-mcp-bridge"
    set CONTROL_PORT 8099
    set LAUNCHER_PORT 8098
    set HUB_PORT 8090
    set BRIDGE_LABEL "upstream"
end

if test -z "$BRIDGE_REPO"
    printf '[GAGAL] BRIDGE_REPO kosong — bug scoping.\n' >&2
    exit 1
end

if not test -d "$REPO_PATH/.git"
    printf '[GAGAL] Bukan repositori Git: %s\n' $REPO_PATH >&2
    exit 1
end
if not command -v pacman >/dev/null 2>&1
    printf '[GAGAL] pacman tidak ditemukan\n' >&2
    exit 1
end

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

install_prasyarat; or exit 1
install_gitrs
install_filesystem

printf '\n== Memasang GitDesktop ==\n'
install_gitdesktop "$HOME/Applications/GitDesktop.AppImage" "$HOME/.local/bin/gitdesktop-mcp"

printf '\n== Web MCP Bridge ==\n'
printf 'Sumber: %s\n' $BRIDGE_REPO
install_bridge $BRIDGE_REPO $BRIDGE_DIR $VENV_DIR $GH_TOKEN; or exit 1

printf '\n== Menulis servers.json ==\n'
printf '{\n  "control_port": %d,\n  "launcher_port": %d,\n  "servers": [\n    {\n      "name": "gitdesktop",\n      "port": %d,\n      "command": ["gitdesktop-mcp"]\n    }\n  ]\n}\n' $CONTROL_PORT $LAUNCHER_PORT $HUB_PORT > "$BRIDGE_DIR/server/servers.json"

set -l snippet_path "$INSTALL_DIR/gitdesktop-mcp-servers.json"
printf '{\n  "mcpServers": {\n    "gitrs": {\n      "command": "gitrs-mcp",\n      "args": ["--repo", "%s"]\n    },\n    "filesystem": {\n      "command": "mcp-filesystem-server",\n      "args": ["%s"]\n    }\n  }\n}\n' "$REPO_PATH" "$REPO_PATH" > $snippet_path

set -l repo_mcp "$REPO_PATH/.mcp.json"
printf '{\n  "mcpServers": {\n    "gitrs": {\n      "command": "gitrs-mcp",\n      "args": ["--repo", "%s"]\n    },\n    "filesystem": {\n      "command": "mcp-filesystem-server",\n      "args": ["%s"]\n    }\n  }\n}\n' "$REPO_PATH" "$REPO_PATH" > $repo_mcp
printf '[OK] .mcp.json ditulis di root repo (GitDesktop akan mendeteksinya otomatis)\n'

set -l launcher "$INSTALL_DIR/start-easy-vibe.fish"
printf '#!/usr/bin/env fish\ncd "%s"\nexec "%s/bin/python" server/mcp_ws_bridge.py --config server/servers.json\n' "$BRIDGE_DIR" "$VENV_DIR" > $launcher
chmod +x $launcher

if test "$EASY_VIBE_INSTALL_SERVICE" = "1"
    pushd $BRIDGE_DIR
    "$VENV_DIR/bin/python" server/install_service.py
    popd
    set -a manifest_lines "systemd-user easy-vibe"
end

printf '%s\n' $manifest_lines > "$MANIFEST"

printf '\n== Selesai ==\n'
printf 'Bridge: %s | kontrol %d, launcher %d, hub %d\n' $BRIDGE_LABEL $CONTROL_PORT $LAUNCHER_PORT $HUB_PORT
if test -n "$GH_TOKEN"
    printf 'Token GitHub: %s\n' $TOKEN_FILE
end
if not command -v gitdesktop-mcp >/dev/null 2>&1
    printf 'Manual: buka GitDesktop -> Settings -> Use GitDesktop as an MCP server -> Add to PATH\n'
end
printf '\nLangkah manual yang tersisa:\n'
printf '1. Buka repo ini di GitDesktop, lalu Settings -> MCP -> klik Import (.mcp.json sudah terdeteksi)\n'
printf '2. chrome://extensions -> Load unpacked -> %s\n' "$BRIDGE_DIR"
printf '3. https://chat.deepseek.com -> panel bridge -> Inject instructions\n\n'
printf 'Launcher: %s\n' $launcher
