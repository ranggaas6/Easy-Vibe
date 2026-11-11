# Helper pemasangan GitDesktop untuk Easy-Vibe
# Dipanggil dari install.fish; mengharapkan variabel global:
#   GH_TOKEN, INSTALL_DIR, manifest_lines (di-set oleh caller)

function ada_gd -a cmd
    command -v $cmd >/dev/null 2>&1
end

function install_gitdesktop -a appimage_path link_path
    if test -n "$EASY_VIBE_SKIP_GITDESKTOP"; and test "$EASY_VIBE_SKIP_GITDESKTOP" = "1"
        printf '[PERINGATAN] Pemasangan GitDesktop dilewati karena --skip-gitdesktop.\n'
        return 0
    end

    # Jika GitDesktop sudah ada, pastikan wrapper dibuat ulang
    if ada_gd gitdesktop-mcp
        set -l real_appimage (readlink -f (command -v gitdesktop-mcp))
        if test -z "$real_appimage"
            set real_appimage "$HOME/Applications/GitDesktop.AppImage"
        end
        
        mkdir -p (dirname $link_path)
        # Skrip wrapper yang aman: jalankan GUI dulu, tunggu port, baru jalankan bridge
        printf '#!/usr/bin/env fish\n# Wrapper otomatis Easy-Vibe\nif test (count $argv) -gt 0; and test "$argv[1]" = "mcp"\n    exec "%s" $argv\nend\n\n"%s" $argv &>/dev/null &\nset -l gd_pid $last_pid\n\nfor i in (seq 1 20)\n    if ss -tln | grep -q ":8190 "\n        break\n    end\n    sleep 0.5\nend\n\nif kill -0 $gd_pid 2>/dev/null\n    fish "%s/start-easy-vibe.fish" &>/dev/null &\n    set -l bridge_pid $last_pid\n    wait $gd_pid\n    kill $bridge_pid 2>/dev/null\nend\n' "$real_appimage" "$real_appimage" "$HOME/.easy-vibe" > "$link_path"
        chmod +x "$link_path"
        printf '[OK]   Wrapper gitdesktop-mcp diperbarui di %s\n' $link_path
        set -a manifest_lines "gitdesktop-mcp-link $link_path"
        
        set -l desktop_dir "$HOME/.local/share/applications"
        set -l desktop_file "$desktop_dir/gitdesktop.desktop"
        mkdir -p $desktop_dir
        printf '[Desktop Entry]\nType=Application\nName=GitDesktop\nComment=AI-native Git desktop client\nExec="%s"\nIcon=git\nTerminal=false\nCategories=Development;VersionControl;\nStartupWMClass=GitDesktop\n' "$link_path" > "$desktop_file"
        chmod +x "$desktop_file"
        set -a manifest_lines "gitdesktop-desktop-file $desktop_file"
        if command -v update-desktop-database >/dev/null 2>&1
            update-desktop-database $desktop_dir >/dev/null 2>&1
        end
        printf '[OK]   Ikon menu aplikasi dibuat di %s\n' $desktop_file
        return 0
    end

    set -l api "https://api.github.com/repos/theBGuy/GitDesktop/releases/latest"
    set -l curl_opts -fsSL
    if test -n "$GH_TOKEN"
        set -a curl_opts -H "Authorization: Bearer $GH_TOKEN"
    end
    set -l release (curl $curl_opts "$api" 2>/dev/null)
    set -l asset (printf '%s' "$release" | string match -r '"browser_download_url"\s*:\s*"[^"]*_amd64\.AppImage"' | string replace -r '.*"(https[^"]+)".*' '$1' | head -n1)

    if test -z "$asset"
        printf '[PERINGATAN] Aset AppImage x86_64 tidak ditemukan di rilis GitDesktop terbaru.\n'
        printf '[PERINGATAN] Unduh manual: https://github.com/theBGuy/GitDesktop/releases/latest\n'
        return 1
    end

    mkdir -p (dirname $appimage_path)
    printf '\n== Mengunduh GitDesktop AppImage ==\n'
    printf '[PERINGATAN] Sumber: %s\n' $asset
    set -l dl_opts -fL --progress-bar
    if test -n "$GH_TOKEN"
        set -a dl_opts -H "Authorization: Bearer $GH_TOKEN"
    end

    if not curl $dl_opts -o "$appimage_path" "$asset"
        printf '[PERINGATAN] Unduhan AppImage gagal.\n'
        return 1
    end

    chmod +x "$appimage_path"
    set -a manifest_lines "gitdesktop-appimage $appimage_path"
    set -l sha (sha256sum "$appimage_path" | string split ' ')[1]
    set -a manifest_lines "gitdesktop-sha256 $sha"
    printf '[OK]   AppImage terpasang di %s\n' $appimage_path
    printf '[OK]   SHA-256: %s\n' $sha

    mkdir -p (dirname $link_path)
    # Buat skrip wrapper yang aman
    printf '#!/usr/bin/env fish\n# Wrapper otomatis Easy-Vibe\nif test (count $argv) -gt 0; and test "$argv[1]" = "mcp"\n    exec "%s" $argv\nend\n\n"%s" $argv &>/dev/null &\nset -l gd_pid $last_pid\n\nfor i in (seq 1 20)\n    if ss -tln | grep -q ":8190 "\n        break\n    end\n    sleep 0.5\nend\n\nif kill -0 $gd_pid 2>/dev/null\n    fish "%s/start-easy-vibe.fish" &>/dev/null &\n    set -l bridge_pid $last_pid\n    wait $gd_pid\n    kill $bridge_pid 2>/dev/null\nend\n' "$appimage_path" "$appimage_path" "$HOME/.easy-vibe" > "$link_path"
    chmod +x "$link_path"
    fish_add_path (dirname $link_path)
    printf '[OK]   Wrapper gitdesktop-mcp dibuat di %s\n' $link_path
    set -a manifest_lines "gitdesktop-mcp-link $link_path"

    # Verifikasi mode MCP
    set -l gd_rc 124
    if test -x "$link_path"
        timeout 5 "$link_path" mcp </dev/null >/dev/null 2>&1
        set gd_rc $status
    end
    if test $gd_rc -ne 124; and test $gd_rc -ne 127
        printf '[OK]   gitdesktop-mcp merespons mode MCP (exit %d)\n' $gd_rc
    else if test $gd_rc -eq 124
        printf '[PERINGATAN] gitdesktop-mcp menggantung saat dipanggil mode MCP.\n'
        printf '[PERINGATAN] Buka GitDesktop sekali, lalu Settings -> Use GitDesktop as an MCP server -> Add to PATH.\n'
    else
        printf '[PERINGATAN] gitdesktop-mcp tidak dapat dieksekusi di %s\n' $link_path
    end

    set -l desktop_dir "$HOME/.local/share/applications"
    set -l desktop_file "$desktop_dir/gitdesktop.desktop"
    mkdir -p $desktop_dir
    printf '[Desktop Entry]\nType=Application\nName=GitDesktop\nComment=AI-native Git desktop client\nExec="%s"\nIcon=git\nTerminal=false\nCategories=Development;VersionControl;\nStartupWMClass=GitDesktop\n' "$link_path" > "$desktop_file"
    chmod +x "$desktop_file"
    set -a manifest_lines "gitdesktop-desktop-file $desktop_file"
    if command -v update-desktop-database >/dev/null 2>&1
        update-desktop-database $desktop_dir >/dev/null 2>&1
    end
    printf '[OK]   Ikon menu aplikasi dibuat di %s\n' $desktop_file

    return 0
end
