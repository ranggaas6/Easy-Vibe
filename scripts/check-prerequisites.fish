#!/usr/bin/env fish
# Memeriksa prasyarat Easy-Vibe di CachyOS + fish.
# Topologi: DeepSeek -> Bridge -> GitDesktop MCP (hub) -> gitrs-mcp + mcp-filesystem-server
# Pemakaian: fish scripts/check-prerequisites.fish

set -g exit_code 0

function check_command -a name
    if command -v $name >/dev/null 2>&1
        printf '[OK]   %s ditemukan: %s\n' $name (command -v $name)
    else
        printf '[GAGAL] %s tidak ditemukan\n' $name
        set -g exit_code 1
    end
end

function check_pacman_pkg -a pkg
    if pacman -Qi $pkg >/dev/null 2>&1
        printf '[OK]   paket pacman %s terpasang\n' $pkg
    else
        printf '[PERINGATAN] paket pacman %s belum terpasang\n' $pkg
    end
end

function check_version -a name min_major
    set -l raw ($name --version 2>&1 | head -n 1)
    set -l version (string match -r -- '[0-9]+\.[0-9]+(\.[0-9]+)?' $raw | head -n 1)
    if test -z "$version"
        printf '[PERINGATAN] Tidak dapat membaca versi %s dari: %s\n' $name $raw
        return
    end
    set -l major (string split -m 1 '.' $version)[1]
    if test $major -lt $min_major
        printf '[PERINGATAN] %s versi %s, disarankan minimal %s.x\n' $name $version $min_major
    else
        printf '[OK]   %s versi %s\n' $name $version
    end
end

echo '== Memeriksa lingkungan CachyOS + fish =='
if command -v pacman >/dev/null 2>&1
    printf '[OK]   pacman ditemukan\n'
else
    printf '[GAGAL] pacman tidak ditemukan. Skrip ini untuk CachyOS/Arch.\n'
    set -g exit_code 1
end

if test "$SHELL" = "/usr/bin/fish" -o "$SHELL" = "/bin/fish"
    printf '[OK]   shell saat ini: %s\n' $SHELL
else
    printf '[PERINGATAN] Shell bukan fish: %s. Installer dirancang untuk fish.\n' $SHELL
end

echo
echo '== Memeriksa paket dasar (pacman) =='
for p in git python python-pip go curl base-devel
    check_pacman_pkg $p
end

echo
echo '== Memeriksa perangkat dasar =='
check_command git
check_command python
check_command go

echo
echo '== Memeriksa versi =='
if command -v python >/dev/null 2>&1
    check_version python 3
end
if command -v go >/dev/null 2>&1
    check_version go 1
end

echo
echo '== Memeriksa GitDesktop MCP (hub) =='
if command -v gitdesktop-mcp >/dev/null 2>&1
    printf '[OK]   gitdesktop-mcp ditemukan: %s\n' (command -v gitdesktop-mcp)
else
    printf '[GAGAL] gitdesktop-mcp tidak ditemukan. GitDesktop adalah hub MCP; tanpa binary ini seluruh rantai tool gagal.\n'
    set -g exit_code 1
end

if command -v gitdesktop >/dev/null 2>&1
    printf '[OK]   aplikasi gitdesktop ditemukan\n'
else
    printf '[PERINGATAN] aplikasi gitdesktop tidak ditemukan di PATH. Mungkin terpasang via Flatpak; pastikan Settings -> MCP bisa dibuka.\n'
end

echo
echo '== Memeriksa server anak =='
check_command gitrs-mcp
check_command mcp-filesystem-server

if command -v gitrs-mcp >/dev/null 2>&1
    set -l p (command -v gitrs-mcp)
    if string match -q -- "$HOME/.local/bin/*" $p
        printf '[OK]   gitrs-mcp di ~/.local/bin (ada di PATH CachyOS fish)\n'
    end
end

if command -v mcp-filesystem-server >/dev/null 2>&1
    set -l p (command -v mcp-filesystem-server)
    set -l gopath_bin (go env GOPATH)/bin
    if string match -q -- "$gopath_bin/*" $p
        printf '[OK]   mcp-filesystem-server di %s\n' $gopath_bin
    end
end

echo
echo '== Memeriksa instalasi Easy-Vibe =='
set -l install_dir "$HOME/.easy-vibe"
set -l bridge_dir "$install_dir/web-mcp-bridge"
set -l venv_dir "$install_dir/venv"
set -l launcher "$install_dir/start-easy-vibe.fish"
set -l snippet "$install_dir/gitdesktop-mcp-servers.json"

for d in $install_dir $bridge_dir $venv_dir
    if test -d $d
        printf '[OK]   direktori ada: %s\n' $d
    else
        printf '[PERINGATAN] direktori tidak ditemukan: %s\n' $d
    end
end

if test -f "$bridge_dir/server/servers.json"
    printf '[OK]   servers.json ada\n'
    set -l isi (cat "$bridge_dir/server/servers.json")
    if string match -q -- '*"gitdesktop"*' $isi
        printf '[OK]   servers.json memakai gitdesktop sebagai hub\n'
    else
        printf '[PERINGATAN] servers.json tidak memuat entry gitdesktop. Topologi hub belum diterapkan.\n'
    end
else
    printf '[PERINGATAN] servers.json belum dibuat. Jalankan install.fish dulu.\n'
end

if test -f $snippet
    printf '[OK]   snippet server anak ada: %s\n' $snippet
    printf '       Pastikan isinya sudah ditempel ke Settings -> MCP di GitDesktop.\n'
else
    printf '[PERINGATAN] snippet server anak tidak ada: %s\n' $snippet
end

if test -x $launcher
    printf '[OK]   launcher siap: %s\n' $launcher
else
    printf '[PERINGATAN] launcher tidak ditemukan: %s\n' $launcher
end

echo
echo '== Memeriksa berkas konfigurasi repo =='
for f in config/bridge-servers.example.json config/mcp.json prompts/system-prompt-id.md
    if test -f $f
        printf '[OK]   %s ada\n' $f
    else
        printf '[GAGAL] %s tidak ditemukan\n' $f
        set -g exit_code 1
    end
end

echo
if test $exit_code -eq 0
    echo 'Semua prasyarat wajib terpenuhi.'
else
    echo 'Ada prasyarat yang belum terpenuhi. Perbaiki lalu jalankan ulang.'
end

exit $exit_code
