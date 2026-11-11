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
    sudo pacman -S --needed --noconfirm git python python-pip go curl base-devel
    or begin
        printf '[GAGAL] Paket dasar gagal dipasang\n' >&2
        return 1
    end
    ib_ok "Paket dasar terpasang"
end

function install_gitrs
    ib_langkah "Memasang gitrs-mcp"
    if ib_ada gitrs-mcp
        ib_ok "gitrs-mcp sudah terpasang: "(command -v gitrs-mcp)
        return 0
    end
    curl -fsSL https://raw.githubusercontent.com/prasenjit-net/gitrs-mcp/master/install.sh | sh
    if ib_ada gitrs-mcp
        ib_ok "gitrs-mcp terpasang di "(command -v gitrs-mcp)
        set -a manifest_lines "gitrs-mcp "(command -v gitrs-mcp)
    else
        ib_warn "gitrs-mcp belum ada di PATH. Jalankan: fish_add_path ~/.local/bin"
    end
end

function install_filesystem
    ib_langkah "Memasang mcp-filesystem-server"
    if ib_ada mcp-filesystem-server
        ib_ok "mcp-filesystem-server sudah terpasang"
        return 0
    end
    go install github.com/mark3labs/mcp-filesystem-server@latest
    or begin
        printf '[GAGAL] go install gagal\n' >&2
        return 1
    end
    set -l gopath_bin (go env GOPATH)/bin
    fish_add_path $gopath_bin
    set -a manifest_lines "fish_user_paths $gopath_bin"
    set -a manifest_lines "mcp-filesystem-server $gopath_bin/mcp-filesystem-server"
    if ib_ada mcp-filesystem-server
        ib_ok "mcp-filesystem-server terpasang di $gopath_bin"
    else
        ib_warn "Binary ada di $gopath_bin. Jalankan: fish_add_path $gopath_bin"
    end
end
