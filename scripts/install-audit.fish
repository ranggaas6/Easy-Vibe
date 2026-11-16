# Modul mcp-audit: perekam panggilan tool (dipanggil dari install.fish)
function audit_wrap -a name bin
    # Hasilnya disisipkan ke dalam array JSON: ["%s", "serve", ...]
    # Tanpa mcp-audit, server dijalankan langsung seperti biasa.
    if test -z "$AUDIT_BIN"
        printf '%s' $bin
        return 0
    end
    printf '%s", "run", "--log", "%s/%s.jsonl", "--server-name", "%s", "--quiet", "--", "%s' $AUDIT_BIN $AUDIT_DIR $name $name $bin
end
function install_audit -a install_dir script_dir
    ib_langkah "Memasang mcp-audit (perekam panggilan tool)"
    set -g AUDIT_BIN ""
    set -g AUDIT_DIR "$install_dir/audit"
    set -l src "$install_dir/src/mcp-audit-proxy"
    set -l out "$install_dir/bin/mcp-audit"
    mkdir -p "$install_dir/bin" "$install_dir/src" "$AUDIT_DIR"
    chmod 700 "$AUDIT_DIR"
    if not ib_ada go
        ib_warn "go tidak ditemukan, mcp-audit dilewati"
        return 1
    end
    if test -d "$src/.git"
        git -C "$src" pull --ff-only
        or ib_warn "git pull mcp-audit gagal, memakai salinan lokal"
    else
        git clone --depth 1 https://github.com/firatmio/mcp-audit-proxy "$src"
        or begin
            ib_warn "clone mcp-audit gagal, dilewati"
            return 1
        end
    end
    go build -C "$src" -o "$out" ./cmd/mcp-audit
    or begin
        ib_warn "go build mcp-audit gagal, server berjalan tanpa perekam"
        return 1
    end
    if not test -x "$out"
        ib_warn "binary mcp-audit tidak ditemukan setelah build"
        return 1
    end
    cp "$script_dir/scripts/audit-brief.py" "$install_dir/audit-brief.py"
    chmod +x "$install_dir/audit-brief.py"
    set -g AUDIT_BIN "$out"
    set -a manifest_lines "audit-bin $out"
    set -a manifest_lines "audit-dir $AUDIT_DIR"
    ib_ok "mcp-audit: $out (commit "(git -C "$src" rev-parse --short HEAD)")"
    ib_ok "log panggilan: $AUDIT_DIR (hanya pemilik yang bisa membaca)"
end
