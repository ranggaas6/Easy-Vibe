#!/usr/bin/env fish
# Easy-Vibe Installer untuk CachyOS + fish
#
# Topologi: DeepSeek -> Web MCP Bridge (fork ranggaas6) -> GitDesktop MCP (hub) -> gitrs-mcp + mcp-filesystem-server
#
# Pemakaian:
#   fish install.fish                   # pasang (GitDesktop ikut terpasang otomatis)
#   fish install.fish --clean           # bersihkan dulu via uninstall.fish, lalu pasang
#   fish install.fish --force           # timpa instalasi lama tanpa bertanya
#   fish install.fish --upstream        # pakai upstream AstraxOf/web-mcp-bridge (port 8099/8098/8090)
#   fish install.fish --skip-gitdesktop # lewati pemasangan otomatis GitDesktop
#
# Layanan systemd pengguna:
#   set -Ux EASY_VIBE_INSTALL_SERVICE 1
#   fish install.fish

set -l REPO_PATH (pwd)
set -l INSTALL_DIR "$HOME/.easy-vibe"
set -l BRIDGE_DIR "$INSTALL_DIR/web-mcp-bridge"
set -l VENV_DIR "$INSTALL_DIR/venv"
set -l MANIFEST "$INSTALL_DIR/manifest.txt"
set -l CLEAN 0
set -l FORCE 0
set -l USE_UPSTREAM 0
set -l SKIP_GD 0

for a in $argv
    switch $a
        case --clean
            set CLEAN 1
        case --force
            set FORCE 1
        case --upstream
            set USE_UPSTREAM 1
        case --skip-gitdesktop
            set SKIP_GD 1
        case -h --help
            echo "Pemakaian: fish install.fish [--clean] [--force] [--upstream] [--skip-gitdesktop]"
            exit 0
        case '*'
            echo "Opsi tidak dikenal: $a" >&2
            exit 1
    end
end

function langkah -a msg
    printf '\n== %s ==\n' $msg
end

function ok -a msg
    printf '[OK]   %s\n' $msg
end

function warn -a msg
    printf '[PERINGATAN] %s\n' $msg
end

function gagal -a msg
    printf '[GAGAL] %s\n' $msg >&2
    exit 1
end

function ada -a cmd
    command -v $cmd >/dev/null 2>&1
end

# ------------------------------------------------------------
# 0. Pilih sumber bridge
# ------------------------------------------------------------
if test $USE_UPSTREAM -eq 1
    set -l BRIDGE_REPO "https://github.com/AstraxOf/web-mcp-bridge"
    set -l CONTROL_PORT 8099
    set -l LAUNCHER_PORT 8098
    set -l HUB_PORT 8090
    set -l BRIDGE_LABEL "upstream (AstraxOf)"
else
    set -l BRIDGE_REPO "https://github.com/ranggaas6/web-mcp-bridge"
    set -l CONTROL_PORT 8199
    set -l LAUNCHER_PORT 8198
    set -l HUB_PORT 8190
    set -l BRIDGE_LABEL "fork (ranggaas6)"
end

# ------------------------------------------------------------
# 1. Validasi
# ------------------------------------------------------------
if not test -d "$REPO_PATH/.git"
    gagal "Bukan repositori Git: $REPO_PATH"
end

if not command -v pacman >/dev/null 2>&1
    gagal "pacman tidak ditemukan. Installer ini untuk CachyOS/Arch."
end

# ------------------------------------------------------------
# 1a. Bersihkan instalasi lama bila diminta atau terdeteksi
# ------------------------------------------------------------
if test $CLEAN -eq 1
    langkah "Membersihkan instalasi lama"
    if test -f (dirname (status --current-filename))/uninstall.fish
        fish (dirname (status --current-filename))/uninstall.fish --yes
    else if test -f uninstall.fish
        fish uninstall.fish --yes
    else
        warn "uninstall.fish tidak ditemukan. Menghapus direktori instalasi saja."
        rm -rf "$INSTALL_DIR"
    end
    ok "Pembersihan selesai"
else if test -f "$MANIFEST" -a $FORCE -eq 0
    warn "Instalasi lama terdeteksi di $INSTALL_DIR."
    warn "Jalankan dengan --clean untuk membersihkan dulu, atau --force untuk menimpa."
    gagal "Dibatalkan agar tidak menumpuk di atas instalasi lama."
end

mkdir -p "$INSTALL_DIR"
set -l manifest_lines "installed_at "(date -Iseconds)
set -a manifest_lines "bridge_source "$BRIDGE_REPO

# ------------------------------------------------------------
# 2. Prasyarat dasar
# ------------------------------------------------------------
langkah "Memasang prasyarat dasar"
set -l paket git python python-pip go curl base-devel
sudo pacman -S --needed --noconfirm $paket
or gagal "Gagal memasang paket dasar"
ok "Paket dasar terpasang"

# ------------------------------------------------------------
# 3. gitrs-mcp
# ------------------------------------------------------------
langkah "Memasang gitrs-mcp"
if ada gitrs-mcp
    ok "gitrs-mcp sudah terpasang: "(command -v gitrs-mcp)
else
    curl -fsSL https://raw.githubusercontent.com/prasenjit-net/gitrs-mcp/master/install.sh | sh
    if ada gitrs-mcp
        ok "gitrs-mcp terpasang di "(command -v gitrs-mcp)
        set -a manifest_lines "gitrs-mcp "(command -v gitrs-mcp)
    else
        warn "gitrs-mcp belum ada di PATH. Buka terminal baru atau jalankan: fish_add_path ~/.local/bin"
    end
end

# ------------------------------------------------------------
# 4. mcp-filesystem-server
# ------------------------------------------------------------
langkah "Memasang mcp-filesystem-server"
if ada mcp-filesystem-server
    ok "mcp-filesystem-server sudah terpasang"
else
    go install github.com/mark3labs/mcp-filesystem-server@latest
    or gagal "go install gagal"
    set -l gopath_bin (go env GOPATH)/bin
    fish_add_path $gopath_bin
    set -a manifest_lines "fish_user_paths "$gopath_bin
    set -a manifest_lines "mcp-filesystem-server "$gopath_bin/mcp-filesystem-server
    if ada mcp-filesystem-server
        ok "mcp-filesystem-server terpasang di $gopath_bin"
    else
        warn "Binary ada di $gopath_bin. Jalankan: fish_add_path $gopath_bin"
    end
end

# ------------------------------------------------------------
# 5. GitDesktop (hub MCP, wajib) — otomatis dari rilis resmi
# ------------------------------------------------------------
# Paket AUR `gitdesktop-bin` sudah usang (terakhir sinkron sekitar awal 2025)
# dan Flatpak `io.github.thebguy.GitDesktop` tidak tersedia di Flathub.
# Satu-satunya sumber yang andal adalah halaman rilis resmi di GitHub.
# Installer mengunduh AppImage x86_64 terbaru, memasangnya di ~/Applications,
# lalu membuat symlink gitdesktop-mcp sendiri sebagai pengganti langkah GUI
# "Settings -> Use GitDesktop as an MCP server -> Add to PATH".
langkah "Memasang GitDesktop (hub MCP)"

set -l GD_APPIMAGE "$HOME/Applications/GitDesktop.AppImage"
set -l GD_LINK "$HOME/.local/bin/gitdesktop-mcp"

if test $SKIP_GD -eq 1
    warn "Pemasangan GitDesktop dilewati karena --skip-gitdesktop."
    warn "Pastikan gitdesktop-mcp tersedia di PATH sebelum menjalankan bridge."
else if ada gitdesktop-mcp
    ok "gitdesktop-mcp sudah tersedia di "(command -v gitdesktop-mcp)
    set -a manifest_lines "gitdesktop-mcp-link "(command -v gitdesktop-mcp)
else
    set -l GD_API "https://api.github.com/repos/theBGuy/GitDesktop/releases/latest"
    set -l GD_RELEASE (curl -fsSL "$GD_API" 2>/dev/null)
    set -l GD_ASSET (printf '%s' "$GD_RELEASE" | string match -r '"browser_download_url"\s*:\s*"[^"]*_amd64\.AppImage"' | string replace -r '.*"(https[^"]+)".*' '$1' | head -n1)

    if test -z "$GD_ASSET"
        warn "Tidak menemukan aset AppImage x86_64 di rilis terbaru GitDesktop."
        warn "Unduh manual dari: https://github.com/theBGuy/GitDesktop/releases/latest"
        warn "Instalasi bridge akan tetap dilanjutkan, tetapi bridge tidak bisa start"
        warn "sampai gitdesktop-mcp tersedia di PATH."
    else
        mkdir -p "$HOME/Applications"
        langkah "Mengunduh GitDesktop AppImage"
        warn "Sumber: $GD_ASSET"
        if curl -fL --progress-bar -o "$GD_APPIMAGE" "$GD_ASSET"
            chmod +x "$GD_APPIMAGE"
            set -a manifest_lines "gitdesktop-appimage $GD_APPIMAGE"
            set -l GD_SHA (sha256sum "$GD_APPIMAGE" | string split ' ')[1]
            set -a manifest_lines "gitdesktop-sha256 $GD_SHA"
            ok "AppImage terpasang di $GD_APPIMAGE"
            ok "SHA-256: $GD_SHA"
        else
            warn "Unduhan AppImage gagal. Pasang manual dari halaman rilis resmi."
        end

        if test -x "$GD_APPIMAGE"
            mkdir -p "$HOME/.local/bin"
            ln -sf "$GD_APPIMAGE" "$GD_LINK"
            fish_add_path "$HOME/.local/bin"
            ok "Symlink gitdesktop-mcp dibuat di $GD_LINK"
            set -a manifest_lines "gitdesktop-mcp-link $GD_LINK"
        end

        if test -x "$GD_LINK"; and fish -c "'$GD_LINK' --version >/dev/null 2>&1"
            ok "GitDesktop terpasang dan gitdesktop-mcp terverifikasi"
        else
            warn "AppImage terpasang, tetapi gitdesktop-mcp belum terverifikasi."
            warn "Buka GitDesktop sekali, lalu jalankan:"
            warn "  Settings -> Use GitDesktop as an MCP server -> Add to PATH"
            warn "Setelah itu buka terminal baru dan cek: gitdesktop-mcp --version"
        end
    end
end

# ------------------------------------------------------------
# 6. Web MCP Bridge (fork default) dan venv
# ------------------------------------------------------------
langkah "Menyiapkan Web MCP Bridge: $BRIDGE_LABEL"
if test -d "$BRIDGE_DIR/.git"
    set -l current_origin (git -C "$BRIDGE_DIR" remote get-url origin 2>/dev/null)
    if test "$current_origin" != "$BRIDGE_REPO"
        warn "Sumber lama: $current_origin"
        warn "Mengganti origin ke $BRIDGE_REPO"
        git -C "$BRIDGE_DIR" remote set-url origin "$BRIDGE_REPO"
    end
    git -C "$BRIDGE_DIR" pull --ff-only
else
    git clone "$BRIDGE_REPO" "$BRIDGE_DIR"
end

if not test -f "$BRIDGE_DIR/server/requirements.txt"
    gagal "Struktur bridge tidak dikenali: $BRIDGE_DIR"
end

if not test -d "$VENV_DIR"
    python -m venv "$VENV_DIR"
    or gagal "Gagal membuat virtual environment di $VENV_DIR"
end

"$VENV_DIR/bin/pip" install --upgrade pip
"$VENV_DIR/bin/pip" install -r "$BRIDGE_DIR/server/requirements.txt"
or gagal "Gagal memasang dependensi Python di venv"
ok "Dependensi bridge terpasang di venv"

# ------------------------------------------------------------
# 7. servers.json: satu entry gitdesktop, port sesuai sumber
# ------------------------------------------------------------
langkah "Menulis servers.json (port kontrol $CONTROL_PORT, launcher $LAUNCHER_PORT)"
printf '{\n  "control_port": %d,\n  "launcher_port": %d,\n  "servers": [\n    {\n      "name": "gitdesktop",\n      "port": %d,\n      "command": ["gitdesktop-mcp"]\n    }\n  ]\n}\n' $CONTROL_PORT $LAUNCHER_PORT $HUB_PORT > "$BRIDGE_DIR/server/servers.json"
ok "servers.json ditulis dengan gitdesktop sebagai hub"

# ------------------------------------------------------------
# 8. Snippet server anak
# ------------------------------------------------------------
langkah "Menyiapkan snippet server anak untuk GitDesktop"
set -l snippet_path "$INSTALL_DIR/gitdesktop-mcp-servers.json"
printf '{\n  "mcpServers": {\n    "gitrs": {\n      "command": "gitrs-mcp",\n      "args": ["--repo", "%s"]\n    },\n    "filesystem": {\n      "command": "mcp-filesystem-server",\n      "args": ["%s"]\n    }\n  }\n}\n' "$REPO_PATH" "$REPO_PATH" > $snippet_path
ok "Snippet ditulis ke $snippet_path"

# ------------------------------------------------------------
# 9. Launcher fish
# ------------------------------------------------------------
langkah "Membuat launcher"
set -l launcher "$INSTALL_DIR/start-easy-vibe.fish"
printf '#!/usr/bin/env fish\ncd "%s"\nexec "%s/bin/python" server/mcp_ws_bridge.py --config server/servers.json\n' "$BRIDGE_DIR" "$VENV_DIR" > $launcher
chmod +x $launcher
ok "Launcher: $launcher"

# ------------------------------------------------------------
# 10. Layanan (opsional)
# ------------------------------------------------------------
if test "$EASY_VIBE_INSTALL_SERVICE" = "1"
    langkah "Memasang bridge sebagai layanan systemd pengguna"
    pushd $BRIDGE_DIR
    "$VENV_DIR/bin/python" server/install_service.py
    popd
    set -a manifest_lines "systemd-user easy-vibe"
    ok "Layanan dipasang"
else
    warn "Layanan tidak dipasang. Jalankan launcher manual, atau ulangi dengan EASY_VIBE_INSTALL_SERVICE=1."
end

# ------------------------------------------------------------
# 11. Manifest untuk uninstaller
# ------------------------------------------------------------
langkah "Menulis manifest"
printf '%s\n' $manifest_lines > "$MANIFEST"
ok "Manifest: $MANIFEST"

# ------------------------------------------------------------
# 12. Ringkasan
# ------------------------------------------------------------
langkah "Selesai"
printf '\nSumber bridge: %s\n' $BRIDGE_LABEL
printf 'Port kontrol: %d · launcher: %d · hub: %d\n\n' $CONTROL_PORT $LAUNCHER_PORT $HUB_PORT
printf 'Langkah manual yang tersisa:\n\n'
if not ada gitdesktop-mcp
    printf '0. GitDesktop belum terverifikasi. Buka GitDesktop sekali dan jalankan:\n'
    printf '   Settings -> Use GitDesktop as an MCP server -> Add to PATH\n'
    printf '   Lalu buka terminal baru dan cek: gitdesktop-mcp --version\n\n'
end
printf '1. Daftarkan server anak di GitDesktop:\n'
printf '   - Buka GitDesktop -> Settings -> MCP\n'
printf '   - Tempel isi %s\n\n' $snippet_path
printf '2. Pasang ekstensi browser:\n'
printf '   - Buka chrome://extensions (atau edge://extensions / brave://extensions)\n'
printf '   - Aktifkan Developer mode\n'
printf '   - Klik Load unpacked\n'
printf '   - Pilih folder: %s\n\n' "$BRIDGE_DIR"
printf '3. Buka https://chat.deepseek.com\n'
printf '4. Buka panel Web MCP Bridge, klik Inject instructions\n'
printf '5. Biarkan izin pada Ask every time\n\n'
printf 'Mulai bridge:\n  %s\n\n' $launcher
printf 'Hapus instalasi:\n  fish uninstall.fish\n\n'
printf 'Periksa prasyarat:\n  fish scripts/check-prerequisites.fish\n\n'
