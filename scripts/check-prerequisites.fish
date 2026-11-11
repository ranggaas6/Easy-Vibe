#!/usr/bin/env fish
# Memeriksa prasyarat Easy-Vibe di CachyOS + fish.
# Topologi: DeepSeek -> Bridge (fork ranggaas6) -> GitDesktop MCP (hub) -> gitrs-mcp + mcp-filesystem-server
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
    printf '       Pasang GitDesktop dari rilis resmi:\n'
    printf '         https://github.com/theBGuy/GitDesktop/releases/latest\n'
    printf '       Lalu buka GitDesktop -> Settings -> Use GitDesktop as an MCP server -> Add to PATH.\n'
    printf '       Jangan memakai AUR gitdesktop-bin (usang) atau Flatpak io.github.thebguy.GitDesktop (tidak tersedia).\n'
    set -g exit_code 1
end

if command -v gitdesktop >/dev/null 2>&1
    printf '[OK]   aplikasi gitdesktop ditemukan: %s\n' (command -v gitdesktop)
else
    set -l appimage_candidates "$HOME/Applications/GitDesktop.AppImage" "$HOME/Applications/GitDesktop_"*"_amd64.AppImage"
    set -l found_appimage 0
    for cand in $appimage_candidates
        if test -e "$cand"
            set found_appimage 1
            printf '[OK]   AppImage GitDesktop ditemukan: %s\n' $cand
            break
        end
    end
    if test $found_appimage -eq 0
        printf '[PERINGATAN] aplikasi GitDesktop tidak ditemukan di PATH maupun sebagai AppImage di ~/Applications.\n'
        printf '       Pasang dari rilis resmi: https://github.com/theBGuy/GitDesktop/releases/latest\n'
        printf '       Jangan memakai AUR gitdesktop-bin (usang) atau Flatpak io.github.thebguy.GitDesktop (tidak tersedia).\n'
    end
end

if test -L "$HOME/.local/bin/gitdesktop-mcp" -o -f "$HOME/.local/bin/gitdesktop-mcp"
    printf '[OK]   launcher gitdesktop-mcp ada di ~/.local/bin\n'
else
    printf '[PERINGATAN] launcher gitdesktop-mcp tidak ada di ~/.local/bin. Buka GitDesktop -> Settings -> Use GitDesktop as an MCP server -> Add to PATH.\n'
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
set -l manifest "$install_dir/manifest.txt"

for d in $install_dir $bridge_dir $venv_dir
    if test -d $d
        printf '[OK]   direktori ada: %s\n' $d
    else
        printf '[PERINGATAN] direktori tidak ditemukan: %s\n' $d
    end
end

if test -d "$bridge_dir/.git"
    set -l origin (git -C "$bridge_dir" remote get-url origin 2>/dev/null)
    printf '[INFO] sumber bridge: %s\n' $origin
    if string match -q -- '*ranggaas6/web-mcp-bridge*' $origin
        printf '[OK]   bridge memakai fork ranggaas6 (sumber utama Easy-Vibe)\n'
    else if string match -q -- '*AstraxOf/web-mcp-bridge*' $origin
        printf '[PERINGATAN] bridge memakai upstream AstraxOf. Jalankan installer tanpa --upstream untuk beralih ke fork.\n'
    else
        printf '[PERINGATAN] origin bridge tidak dikenali: %s\n' $origin
    end
end

if test -f $manifest
    printf '[OK]   manifest ada: %s\n' $manifest
    set -l sumber (string match -r 'bridge_source .*' (cat $manifest) | head -n 1)
    if test -n "$sumber"
        printf '       %s\n' $sumber
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
    if string match -q -- '*"control_port"\s*:\s*8199*' $isi; or string match -q -- '*8199*' $isi
        printf '[OK]   servers.json memakai port kontrol fork 8199\n'
    else if string match -q -- '*8099*' $isi
        printf '[INFO] servers.json memakai port kontrol upstream 8099\n'
    end
    if string match -q -- '*8198*' $isi
        printf '[OK]   servers.json memakai port launcher fork 8198\n'
    else if string match -q -- '*8098*' $isi
        printf '[INFO] servers.json memakai port launcher upstream 8098\n'
    end
    if string match -q -- '*8190*' $isi
        printf '[OK]   servers.json memakai port hub fork 8190\n'
    else if string match -q -- '*8090*' $isi
        printf '[INFO] servers.json memakai port hub upstream 8090\n'
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
