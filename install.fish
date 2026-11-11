#!/usr/bin/env fish
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

if not test -d "$REPO_PATH/.git"
    printf '[GAGAL] Bukan repositori Git\n' >&2
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
install_filesystem

printf '\n== Memasang GitDesktop ==\n'
install_gitdesktop "$HOME/Applications/GitDesktop.AppImage" "$HOME/.local/bin/gitdesktop-mcp"

printf '\n== Web MCP Bridge ==\n'
install_bridge $BRIDGE_REPO $BRIDGE_DIR $VENV_DIR $GH_TOKEN; or exit 1

printf '\n== Memasang library mcp untuk multi-git ==\n'
"$VENV_DIR/bin/pip" install mcp >/dev/null 2>&1
or begin
    printf '[GAGAL] Gagal menginstal library mcp\n' >&2
    exit 1
end

printf '\n== Menulis servers.json ==\n'
printf '{\n  "control_port": %d,\n  "launcher_port": %d,\n  "servers": [\n    {\n      "name": "gitdesktop",\n      "port": %d,\n      "command": ["gitdesktop-mcp", "mcp"]\n    }\n  ]\n}\n' $CONTROL_PORT $LAUNCHER_PORT $HUB_PORT > "$BRIDGE_DIR/server/servers.json"

# Path untuk skrip multi-git-mcp
set -l multi_git_script "$SCRIPT_DIR/scripts/multi-git-mcp.py"
set -l venv_python "$VENV_DIR/bin/python"

set -l snippet_path "$INSTALL_DIR/gitdesktop-mcp-servers.json"
printf '{\n  "mcpServers": {\n    "git": {\n      "command": "%s",\n      "args": ["%s"]\n    },\n    "filesystem": {\n      "command": "mcp-filesystem-server",\n      "args": ["%s"]\n    }\n  }\n}\n' "$venv_python" "$multi_git_script" "$HOME" > $snippet_path

set -l repo_mcp "$REPO_PATH/.mcp.json"
printf '{\n  "mcpServers": {\n    "git": {\n      "command": "%s",\n      "args": ["%s"]\n    },\n    "filesystem": {\n      "command": "mcp-filesystem-server",\n      "args": ["%s"]\n    }\n  }\n}\n' "$venv_python" "$multi_git_script" "$HOME" > $repo_mcp

printf '\n== Menyuntikkan MCP otomatis ==\n'
if command -v python >/dev/null 2>&1
    python "$SCRIPT_DIR/scripts/inject_gitdesktop_mcp.py" "$HOME" "$venv_python" "$multi_git_script"
end

set -l launcher "$INSTALL_DIR/start-easy-vibe.fish"
printf '#!/usr/bin/env fish\ncd "%s"\nexec "%s/bin/python" server/mcp_ws_bridge.py --config server/servers.json\n' "$BRIDGE_DIR" "$VENV_DIR" > $launcher
chmod +x $launcher

printf '%s\n' $manifest_lines > "$MANIFEST"
printf '\n== Selesai ==\n'
printf 'Siklus hidup otomatis telah diaktifkan.\n'
printf 'Bridge akan menyala saat Anda membuka GitDesktop, dan mati saat Anda menutupnya.\n'
printf 'Launcher manual (jika diperlukan): %s\n' $launcher
