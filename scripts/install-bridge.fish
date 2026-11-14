function install_bridge -a bridge_repo bridge_dir venv_dir token
    printf '\n== Web MCP Bridge ==\n'
    set -l clone_url $bridge_repo
    if test -n "$token"
        set -l stripped (string replace -r '^https://' '' -- $bridge_repo)
        set clone_url "https://$token@$stripped"
    end

    if test -d "$bridge_dir/.git"
        set -l cur (git -C "$bridge_dir" remote get-url origin 2>/dev/null)
        if test "$cur" != "$bridge_repo"; and test "$cur" != "$clone_url"
            git -C "$bridge_dir" remote set-url origin "$clone_url"
        end
        git -C "$bridge_dir" pull --ff-only
    else
        git clone "$clone_url" "$bridge_dir"
        or return 1
        git -C "$bridge_dir" remote set-url origin "$bridge_repo"
    end

    # Lapisan kedua: pastikan repo ini bisa push non-interaktif,
    # bahkan jika credential.helper global belum disiapkan.
    if test -d "$bridge_dir/.git"
        git -C "$bridge_dir" config credential.helper store 2>/dev/null
        if test -n "$token"
            git -C "$bridge_dir" config credential.username ranggaas6 2>/dev/null
        end
    end

    if not test -f "$bridge_dir/server/requirements.txt"
        printf '[GAGAL] Struktur bridge tidak dikenali\n' >&2
        return 1
    end
    if not test -d "$venv_dir"
        python -m venv "$venv_dir"
        or return 1
    end
    "$venv_dir/bin/pip" install --upgrade pip
    "$venv_dir/bin/pip" install -r "$bridge_dir/server/requirements.txt"
    or return 1
    printf '[OK] Dependensi bridge terpasang\n'
end
