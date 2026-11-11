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

    if ada_gd gitdesktop-mcp
        printf '[OK]   gitdesktop-mcp sudah tersedia di %s\n' (command -v gitdesktop-mcp)
        set -a manifest_lines "gitdesktop-mcp-link "(command -v gitdesktop-mcp)
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
    ln -sf "$appimage_path" "$link_path"
    fish_add_path (dirname $link_path)
    printf '[OK]   Symlink gitdesktop-mcp dibuat di %s\n' $link_path
    set -a manifest_lines "gitdesktop-mcp-link $link_path"

    if test -x "$link_path"; and fish -c "'$link_path' --version >/dev/null 2>&1"
        printf '[OK]   GitDesktop terpasang dan gitdesktop-mcp terverifikasi\n'
    else
        printf '[PERINGATAN] AppImage terpasang, tetapi gitdesktop-mcp belum terverifikasi.\n'
        printf '[PERINGATAN] Buka GitDesktop sekali, lalu Settings -> Use GitDesktop as an MCP server -> Add to PATH.\n'
    end
    return 0
end
