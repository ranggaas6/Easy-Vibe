#!/usr/bin/env fish
# Easy-Vibe Installer untuk CachyOS + fish
#
# Topologi: DeepSeek -> Web MCP Bridge (fork ranggaas6) -> GitDesktop MCP (hub) -> gitrs-mcp + mcp-filesystem-server
#
# Pemakaian:
#   fish install.fish              # pasang
#   fish install.fish --clean      # bersihkan dulu via uninstall.fish, lalu pasang
#   fish install.fish --force      # timpa instalasi lama tanpa bertanya
#   fish install.fish --upstream   # pakai upstream AstraxOf/web-mcp-bridge (port 8099/8098/8090)
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

for a in $argv
    switch $a
        case --clean
            set CLEAN 1
        case --force
            set FORCE 1
        case --upstream
            set USE_UPSTREAM 1
        case -h --help
            echo "Pemakaian: fish install.fish [--clean] [--force] [--upstream]"
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
# 5. GitDesktop (hub MCP, wajib) — hanya lewat rilis resmi
# ------------------------------------------------------------
# Paket AUR `gitdesktop-bin` sudah usang (terakhir sinkron sekitar awal 2025)
# dan Flatpak `io.github.thebguy.GitDesktop` tidak tersedia di Flathub.
# Satu-satunya sumber yang andal adalah halaman rilis resmi di GitHub.
langkah "Memeriksa GitDesktop (hub MCP, wajib)"
if ada gitdesktop-mcp
    ok "gitdesktop-mcp tersedia di "(command -v gitdesktop-mcp)
else if ada gitdesktop
    warn "GitDesktop GUI ada di "(command -v gitdesktop)", tetapi `gitdesktop-mcp` tidak ditemukan di PATH."
    warn "Buka GitDesktop -> Settings -> Use GitDesktop as an MCP server -> Add to PATH, lalu buka terminal baru."
else
    warn "GitDesktop belum terpasang. Installer ini TIDAK mencoba memasangnya otomatis."
    warn "Alasannya: paket AUR gitdesktop-bin sudah usang, dan Flatpak io.github.thebguy.GitDesktop tidak tersedia di Flathub."
    warn "Unduh AppImage dari halaman rilis resmi:"
    warn "  https://github.com/theBGuy/GitDesktop/releases/latest"
    warn "Contoh di CachyOS/Arch (x86_64):"
    warn "  mkdir -p ~/Applications"
    warn "  mv ~/Downloads/GitDesktop_<versi>_amd64.AppImage ~/Applications/GitDesktop.AppImage"
    warn "  chmod +x ~/Applications/GitDesktop.AppImage"
    warn "  ~/Applications/GitDesktop.AppImage"
    warn "Setelah GUI terbuka: Settings -> Use GitDesktop as an MCP server -> Add to PATH."
    warn "Pastikan ~/.local/bin ada di PATH (fish_add_path ~/.local/bin), lalu buka terminal baru."
    warn "Verifikasi dengan: gitdesktop-mcp --version"
    warn ""
    warn "Instalasi bridge akan tetap dilanjutkan, tetapi bridge tidak bisa start sampai gitdesktop-mcp tersedia."
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
    printf '0. Pasang GitDesktop dari rilis resmi (lihat peringatan di atas), jalankan Settings -> Use GitDesktop as an MCP server -> Add to PATH, lalu buka terminal baru.\n\n'
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
