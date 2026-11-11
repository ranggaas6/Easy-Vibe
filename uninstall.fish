#!/usr/bin/env fish
# Easy-Vibe Uninstaller untuk CachyOS + fish

set -g DRY 0
set -g TOOLS 0
set -g GD 0
set -g FULL 0
set -g YES 0
set -g PKGS_TO_REMOVE

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
            case pacman-pkg
                set -a PKGS_TO_REMOVE $parts[2]
        end
    end
else
    say "== Manifest tidak ditemukan =="
    say "(instalasi lama; akan menggunakan fallback)"
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
end

if test $FULL -eq 1
    say "== Paket pacman dasar =="
    
    # Fallback: jika manifest tidak mencatat paket (instalasi lama),
    # cek daftar paket bawaan yang mungkin terpasang oleh Easy-Vibe.
    if test (count $PKGS_TO_REMOVE) -eq 0
        say "[INFO] Manifest tidak mencatat paket pacman baru."
        say "[INFO] Memeriksa paket bawaan Easy-Vibe yang sedang terpasang..."
        set -l default_pkgs git python python-pip go curl base-devel
        for p in $default_pkgs
            if pacman -Qi $p >/dev/null 2>&1
                set -a PKGS_TO_REMOVE $p
            end
        end
    end

    if test (count $PKGS_TO_REMOVE) -eq 0
        say "Tidak ada paket pacman yang perlu dihapus."
    else
        say "Paket pacman berikut terdeteksi dan akan dihapus:"
        for p in $PKGS_TO_REMOVE
            say "  - $p"
        end
        
        if test $YES -eq 1
            set -l jawab y
        else
            read -l -P "Hapus paket pacman di atas? [y/N] " jawab
        end
        
        if test "$jawab" = "y"; or test "$jawab" = "Y"
            if test $DRY -eq 0
                sudo pacman -Rns --noconfirm $PKGS_TO_REMOVE
                say "paket pacman dihapus"
            else
                say "akan dihapus via pacman: $PKGS_TO_REMOVE"
            end
        else
            say "Penghapusan paket pacman dibatalkan."
        end
    end
end

say "== Selesai =="
if test $DRY -eq 1
    say "Jalankan tanpa --dry-run untuk benar-benar menghapus."
else
    say "Buka terminal baru agar PATH aktif."
end
