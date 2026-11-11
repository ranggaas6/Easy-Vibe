#!/usr/bin/env fish
# Easy-Vibe Uninstaller untuk CachyOS + fish

set -l DRY 0
set -l TOOLS 0
set -l GD 0
set -l FULL 0
set -l YES 0

for a in $argv
    switch $a
        case --dry-run
            set DRY 1
        case --with-tools
            set TOOLS 1
        case --with-gitdesktop
            set GD 1
        case --full
            set FULL 1
            set TOOLS 1
            set GD 1
        case --yes -y
            set YES 1
        case -h --help
            echo "Pemakaian: fish uninstall.fish [--dry-run] [--with-tools] [--with-gitdesktop] [--full] [--yes]"
            exit 0
        case '*'
            echo "Opsi tidak dikenal: $a" >&2
            exit 1
    end
end

set -l DIR "$HOME/.easy-vibe"
set -l MANIFEST "$DIR/manifest.txt"
set -l GOBIN (go env GOPATH 2>/dev/null)/bin

function say -a m
    printf "%s\n" "$m"
end

function rm_path -a p
    if test -e "$p"
        if test $DRY -eq 1
            say "akan dihapus: $p"
        else
            rm -rf "$p"
            say "dihapus: $p"
        end
    end
end

say "== Uninstaller Easy-Vibe =="
if test $DRY -eq 1
    say "mode dry-run"
end

# ------------------------------------------------------------
# Manifest-driven removal (default)
# ------------------------------------------------------------
# install.fish mencatat setiap artefak yang ia buat ke manifest.
# Uninstaller default cukup menghapus persis apa yang tercatat,
# sehingga GitDesktop ikut terhapus otomatis bila installer
# yang memasangnya.
if test -f "$MANIFEST"
    say "== Artefak dari manifest =="
    for line in (cat "$MANIFEST")
        set -l parts (string split " " -- $line)
        if test (count $parts) -lt 2
            continue
        end
        switch $parts[1]
            case gitdesktop-appimage gitdesktop-mcp-link gitdesktop-desktop-file
                rm_path $parts[2]
            case mcp-filesystem-server gitrs-mcp
                if test $TOOLS -eq 1
                    rm_path $parts[2]
                end
        end
    end
else
    say "== Manifest tidak ditemukan =="
    say "(instalasi lama; gunakan flag eksplisit bila perlu)"
end

say "== Layanan systemd pengguna =="
for f in (ls "$HOME/.config/systemd/user" 2>/dev/null)
    if string match -q "*easy-vibe*" "$f"; or string match -q "*mcp-ws-bridge*" "$f"; or string match -q "*web-mcp-bridge*" "$f"
        if test $DRY -eq 0
            systemctl --user stop "$f" 2>/dev/null
            systemctl --user disable "$f" 2>/dev/null
        end
        rm_path "$HOME/.config/systemd/user/$f"
    end
end

say "== Proses berjalan =="
for n in mcp_ws_bridge.py gitdesktop-mcp gitrs-mcp mcp-filesystem-server
    if pgrep -f "$n" >/dev/null 2>&1
        if test $DRY -eq 0
            pkill -f "$n" 2>/dev/null
            say "dihentikan: $n"
        else
            say "akan dihentikan: $n"
        end
    end
end

say "== Direktori instalasi =="
rm_path "$DIR"

say "== fish PATH =="
if contains "$GOBIN" $fish_user_paths
    if test $DRY -eq 0
        set -U fish_user_paths (string match -v -- "$GOBIN" $fish_user_paths)
        say "dihapus dari fish_user_paths: $GOBIN"
    else
        say "akan dihapus dari fish_user_paths: $GOBIN"
    end
end

if test $TOOLS -eq 1
    say "== Tool MCP =="
    rm_path "$HOME/.local/bin/gitrs-mcp"
    rm_path "$GOBIN/mcp-filesystem-server"
end

if test $GD -eq 1
    say "== GitDesktop (flag eksplisit) =="
    # Flag ini dipertahankan sebagai jalur warisan untuk instalasi lama
    # yang manifest-nya belum mencatat GitDesktop. Pada instalasi baru,
    # pembersihan GitDesktop sudah dilakukan otomatis lewat manifest.

    set -l launcher "$HOME/.local/bin/gitdesktop-mcp"
    if test -L "$launcher" -o -f "$launcher"
        rm_path "$launcher"
    end

    for candidate in "$HOME/Applications/GitDesktop.AppImage" "$HOME/Applications/GitDesktop_"*"_amd64.AppImage"
        if test -e "$candidate"
            rm_path "$candidate"
        end
    end

    set -l desktop_file "$HOME/.local/share/applications/gitdesktop.desktop"
    if test -e "$desktop_file"
        rm_path "$desktop_file"
    end

    if pacman -Qi gitdesktop-bin >/dev/null 2>&1
        if test $DRY -eq 0
            if command -v paru >/dev/null 2>&1
                paru -Rns --noconfirm gitdesktop-bin
            else if command -v yay >/dev/null 2>&1
                yay -Rns --noconfirm gitdesktop-bin
            end
            say "gitdesktop-bin dihapus (paket warisan)"
        else
            say "akan dihapus: gitdesktop-bin (paket warisan)"
        end
    end
    if command -v flatpak >/dev/null 2>&1
        if flatpak list --app 2>/dev/null | string match -q "*GitDesktop*"
            if test $DRY -eq 0
                flatpak uninstall -y io.github.thebguy.GitDesktop
                say "flatpak GitDesktop dihapus (paket warisan)"
            else
                say "akan dihapus: io.github.thebguy.GitDesktop (paket warisan)"
            end
        end
    end
end

if test $FULL -eq 1
    say "== Paket pacman dasar =="
    say "git python python-pip go curl base-devel"
    if test $YES -eq 1
        set -l jawab y
    else
        read -l -P "Hapus paket pacman dasar? [y/N] " jawab
    end
    if test "$jawab" = "y"; or test "$jawab" = "Y"
        if test $DRY -eq 0
            sudo pacman -Rns --noconfirm git python python-pip go curl base-devel
            say "paket pacman dihapus"
        else
            say "akan dihapus via pacman"
        end
    end
end

say "== Selesai =="
if test $DRY -eq 1
    say "Jalankan tanpa --dry-run untuk benar-benar menghapus."
else
    say "Buka terminal baru agar PATH aktif."
end
