# Modul prasyarat dasar untuk install.fish
function ib_ada -a cmd
    command -v $cmd >/dev/null 2>&1
end
function ib_warn -a msg
    printf '[PERINGATAN] %s\n' $msg
end
function ib_ok -a msg
    printf '[OK]   %s\n' $msg
end
function ib_langkah -a msg
    printf '\n== %s ==\n' $msg
end
function install_prasyarat
    ib_langkah "Memasang prasyarat dasar"
    set -l paket git python python-pip go curl base-devel nodejs npm inotify-tools
    set -l newly_installed
    for p in $paket
        if not pacman -Qi $p >/dev/null 2>&1
            set -a newly_installed $p
        end
    end
    sudo pacman -S --needed --noconfirm $paket
    or begin
        printf '[GAGAL] Paket dasar gagal dipasang\n' >&2
        return 1
    end
    if test (count $newly_installed) -gt 0
        for p in $newly_installed
            set -a manifest_lines "pacman-pkg $p"
        end
    end
    if not ib_ada inotifywait
        printf '[GAGAL] inotifywait tidak ditemukan setelah instalasi\n' >&2
        return 1
    end
    ib_ok "Paket dasar terpasang (inotifywait: "(command -v inotifywait)")"
end
function install_filesystem
    ib_langkah "Memasang mcp-filesystem-server"
    set -l gopath_bin (go env GOPATH)/bin
    if not contains "$gopath_bin" $fish_user_paths
        fish_add_path $gopath_bin
        set -a manifest_lines "fish_user_paths $gopath_bin"
    end
    if not ib_ada mcp-filesystem-server
        go install github.com/mark3labs/mcp-filesystem-server@latest
        or begin
            printf '[GAGAL] go install gagal\n' >&2
            return 1
        end
        set -a manifest_lines "mcp-filesystem-server $gopath_bin/mcp-filesystem-server"
    end
    if not ib_ada mcp-filesystem-server
        printf '[GAGAL] mcp-filesystem-server tidak ditemukan\n' >&2
        return 1
    end
    set -g FS_BIN (command -v mcp-filesystem-server)
    ib_ok "mcp-filesystem-server: $FS_BIN"
end
function install_coding_mcp
    ib_langkah "Memasang coding-mcp"
    set -l root "/home/saputraangga214"
    if not ib_ada coding-mcp
        npm install -g @kieutrongthien/coding-mcp
        or begin
            printf '[GAGAL] npm install coding-mcp gagal\n' >&2
            return 1
        end
    end
    if not ib_ada coding-mcp
        printf '[GAGAL] coding-mcp tidak ditemukan setelah instalasi\n' >&2
        return 1
    end
    set -g CODING_BIN (command -v coding-mcp)
    if not contains "npm-global @kieutrongthien/coding-mcp" $manifest_lines
        set -a manifest_lines "npm-global @kieutrongthien/coding-mcp"
    end
    if not test -d $root
        printf '[PERINGATAN] Root %s tidak ada, memakai HOME\n' $root
        set root $HOME
    end
    coding-mcp init $root
    and set -a manifest_lines "coding-mcp-root $root"
    and ib_ok "coding-mcp: $CODING_BIN (root $root)"
    or begin
        printf '[GAGAL] coding-mcp init gagal\n' >&2
        return 1
    end
end
function install_github_mcp
    ib_langkah "Memasang github-mcp-server-kosta"
    if not ib_ada github-mcp-server-kosta
        npm install -g github-mcp-server-kosta
        or begin
            printf '[GAGAL] npm install github-mcp-server-kosta gagal\n' >&2
            return 1
        end
    end
    set -l npmbin (npm config get prefix)/bin
    if test -f "$npmbin/github-mcp-server"
        rm -f "$npmbin/github-mcp-server"
        ib_warn "Binary lama github-mcp-server dihapus (konflik dengan -kosta)"
    end
    if not ib_ada github-mcp-server-kosta
        printf '[GAGAL] github-mcp-server-kosta tidak ditemukan\n' >&2
        return 1
    end
    set -g GITHUB_BIN (command -v github-mcp-server-kosta)
    if not contains "npm-global github-mcp-server-kosta" $manifest_lines
        set -a manifest_lines "npm-global github-mcp-server-kosta"
    end
    ib_ok "github-mcp-server-kosta: $GITHUB_BIN"
end
