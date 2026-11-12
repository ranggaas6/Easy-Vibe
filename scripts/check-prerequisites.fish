#!/usr/bin/env fish
# Memeriksa prasyarat Easy-Vibe di CachyOS + fish.
# Topologi: DeepSeek -> Bridge (fork) -> native host -> coding-mcp + filesystem
set -g exit_code 0
function ck -a n
    if command -v $n >/dev/null 2>&1
        printf '[OK]   %s: %s\n' $n (command -v $n)
    else
        printf '[GAGAL] %s tidak ditemukan\n' $n
        set -g exit_code 1
    end
end
function ckp -a p
    if pacman -Qi $p >/dev/null 2>&1
        printf '[OK]   paket %s\n' $p
    else
        printf '[PERINGATAN] paket %s belum terpasang\n' $p
    end
end
echo '== Lingkungan =='
if command -v pacman >/dev/null 2>&1
    printf '[OK]   pacman\n'
else
    printf '[GAGAL] pacman tidak ada; skrip ini untuk Arch/CachyOS\n'
    set -g exit_code 1
end
echo '== Paket dasar =='
for p in git python python-pip go curl base-devel nodejs npm
    ckp $p
end
echo '== Perangkat =='
for c in git python go node npm coding-mcp mcp-filesystem-server
    ck $c
end
echo '== Instalasi Easy-Vibe =='
set -l D "$HOME/.easy-vibe"
for d in $D "$D/web-mcp-bridge" "$D/venv" "$D/native-host"
    if test -d $d
        printf '[OK]   %s\n' $d
    else
        printf '[PERINGATAN] tidak ada: %s\n' $d
    end
end
set -l M "$D/manifest.txt"
if test -f $M
    printf '[OK]   manifest ada\n'
    for key in native-host-script native-host-manifest npm-global
        if string match -q -- "$key *" (cat $M)
            printf '[OK]   manifest memuat %s\n' $key
        else
            printf '[PERINGATAN] manifest tidak memuat %s\n' $key
        end
    end
end
set -l S "$D/web-mcp-bridge/server/servers.json"
if test -f $S
    printf '[OK]   servers.json ada\n'
    set -l isi (cat $S)
    if string match -q -- '*coding-mcp*' $isi
        printf '[OK]   servers.json memuat coding-mcp\n'
    else
        printf '[GAGAL] servers.json tidak memuat coding-mcp\n'
        set -g exit_code 1
    end
    if string match -q -- '*filesystem*' $isi
        printf '[OK]   servers.json memuat filesystem\n'
    else
        printf '[GAGAL] servers.json tidak memuat filesystem\n'
        set -g exit_code 1
    end
    if string match -q -- '*mcp-filesystem-server*' $isi
        printf '[OK]   filesystem memakai binary\n'
    end
end
echo '== Native host manifest Brave =='
set -l found 0
for d in "$HOME/.config/BraveSoftware/Brave-Browser/NativeMessagingHosts" "$HOME/.var/app/com.brave.Browser/config/BraveSoftware/Brave-Browser/NativeMessagingHosts" "$HOME/.config/BraveSoftware/Brave-Browser-Beta/NativeMessagingHosts"
    set -l mf "$d/com.ranggaas6.easy_vibe.json"
    if test -e $mf
        set found 1
        printf '[OK]   %s\n' $mf
        if string match -q -- '*chrome-extension://*/*' (cat $mf)
            printf '[OK]   allowed_origins terisi\n'
        else
            printf '[GAGAL] allowed_origins masih wildcard\n'
            set -g exit_code 1
        end
    end
end
if test $found -eq 0
    printf '[PERINGATAN] manifest native host belum terpasang\n'
end
echo '== Berkas konfigurasi repo =='
for f in config/bridge-servers.example.json config/mcp.json prompts/system-prompt-id.md
    if test -f $f
        printf '[OK]   %s\n' $f
    else
        printf '[GAGAL] %s tidak ditemukan\n' $f
        set -g exit_code 1
    end
end
echo
if test $exit_code -eq 0
    echo 'Semua prasyarat wajib terpenuhi.'
else
    echo 'Ada prasyarat yang belum terpenuhi.'
end
exit $exit_code
