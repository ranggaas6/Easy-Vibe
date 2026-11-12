# Modul prasyarat dasar untuk install.fish
# Mengharapkan: manifest_lines (array global)
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
    set -l paket git python python-pip go curl base-devel nodejs npm
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
    ib_ok "Paket dasar terpasang"
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
    # Selalu catat paket npm global, terlepas dari apakah baru dipasang atau sudah ada,
    # agar uninstaller tahu harus mencopotnya.
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
