# Modul token-vault: token GitHub disimpan di keyring sistem (Secret Service), bukan sebagai berkas di $HOME.
# Dipakai oleh install.fish dan uninstall.fish.
set -g TV_SERVICE easy-vibe
set -g TV_ACCOUNT github
set -g TV_GIT_HELPER /usr/lib/git-core/git-credential-libsecret
set -g TV_GIT_USER ranggaas6
set -g TV_OK ""

# Pastikan secret-tool menemukan bus D-Bus sesi.
function tv_dbus
    if test -z "$DBUS_SESSION_BUS_ADDRESS"
        set -l bus "/run/user/"(id -u)"/bus"
        if test -S "$bus"
            set -gx DBUS_SESSION_BUS_ADDRESS "unix:path=$bus"
        end
    end
end

# Uji nyata: simpan, baca, hapus item percobaan. Hasil di-cache per proses. Semua panggilan dibatasi timeout agar tidak menggantung.
function tv_ready
    if test "$TV_OK" = 1
        return 0
    end
    if test "$TV_OK" = 0
        return 1
    end
    set -g TV_OK 0
    command -v secret-tool >/dev/null 2>&1; or return 1
    command -v timeout >/dev/null 2>&1; or return 1
    tv_dbus
    printf '%s' probe | timeout 30 secret-tool store --label 'easy-vibe probe' service easy-vibe-probe account probe >/dev/null 2>&1
    or return 1
    set -l got (timeout 30 secret-tool lookup service easy-vibe-probe account probe 2>/dev/null)
    timeout 30 secret-tool clear service easy-vibe-probe account probe >/dev/null 2>&1
    if test "$got" = probe
        set -g TV_OK 1
        return 0
    end
    return 1
end

function tv_lookup
    tv_dbus
    timeout 30 secret-tool lookup service $TV_SERVICE account $TV_ACCOUNT 2>/dev/null
end

# Token dikirim lewat stdin, tidak pernah lewat argumen perintah. Disimpan lalu dibaca ulang untuk verifikasi.
function tv_store -a t
    test -n "$t"; or return 1
    tv_dbus
    printf '%s' $t | timeout 30 secret-tool store --label 'Easy-Vibe GitHub token' service $TV_SERVICE account $TV_ACCOUNT >/dev/null 2>&1
    or return 1
    set -l got (tv_lookup)
    test "$got" = "$t"
end

function tv_clear
    command -v secret-tool >/dev/null 2>&1; or return 0
    tv_dbus
    timeout 30 secret-tool clear service $TV_SERVICE account $TV_ACCOUNT >/dev/null 2>&1
    return 0
end

# Mencari token di lokasi lama (instalasi sebelum keyring) untuk migrasi otomatis.
# Urutan: berkas github-token, servers.json, ~/.git-credentials.
function tv_legacy_token
    set -l f "$HOME/.easy-vibe/github-token"
    if test -f "$f"
        set -l v (string trim < "$f")
        if test -n "$v"
            printf '%s' $v
            return 0
        end
    end
    set -l sj "$HOME/.easy-vibe/web-mcp-bridge/server/servers.json"
    if test -f "$sj"; and command -v python3 >/dev/null 2>&1
        set -l v (python3 -c 'import json,sys
try:
  d=json.load(open(sys.argv[1]))
  for s in d.get("servers",[]):
    t=(s.get("env") or {}).get("GITHUB_TOKEN","")
    if s.get("name")=="github" and t:
      print(t)
      break
except Exception:
  pass' $sj 2>/dev/null)
        if test -n "$v"
            printf '%s' $v
            return 0
        end
    end
    set -l cred "$HOME/.git-credentials"
    if test -f "$cred"
        for line in (cat "$cred")
            set -l m (string match -r '^https://[^:@/]+:([^@]+)@github[.]com' -- $line)
            if test (count $m) -ge 2
                printf '%s' (string unescape --style=url -- $m[2])
                return 0
            end
        end
    end
    return 1
end

# Skrip pembungkus: server github mengambil token dari keyring saat dijalankan,
# sehingga servers.json tidak perlu memuat token.
function tv_write_github_wrapper -a real_bin out
    mkdir -p (dirname $out)
    printf '%s\n' '#!/usr/bin/env bash' '# Dibuat install.fish: token GitHub diambil dari keyring saat server dijalankan.' '# Token tidak pernah ditulis ke berkas.' > $out
    printf '%s\n' 'if [ -z "${DBUS_SESSION_BUS_ADDRESS:-}" ] && [ -S "/run/user/$(id -u)/bus" ]; then' '  export DBUS_SESSION_BUS_ADDRESS="unix:path=/run/user/$(id -u)/bus"' 'fi' >> $out
    printf '%s\n' 't="$(timeout 20 secret-tool lookup service easy-vibe account github 2>/dev/null || true)"' 'if [ -n "$t" ]; then export GITHUB_TOKEN="$t"; fi' 'unset t' >> $out
    printf 'exec "%s" "$@"\n' $real_bin >> $out
    chmod 700 $out
end

# Memindahkan entri ~/.git-credentials (semua host) ke keyring via helper libsecret,
# lalu menghapus berkasnya. Baris yang tidak bisa dipindah dipertahankan.
function tv_migrate_git_credentials
    set -l cred "$HOME/.git-credentials"
    test -f "$cred"; or return 0
    test -x $TV_GIT_HELPER; or return 1
    tv_dbus
    set -l keep
    for line in (cat "$cred")
        if test -z "$line"
            continue
        end
        set -l m (string match -r '^(https?)://([^:@/]+):([^@]+)@([^/]+)' -- $line)
        if test (count $m) -lt 5
            set -a keep $line
            continue
        end
        set -l u (string unescape --style=url -- $m[3])
        set -l p (string unescape --style=url -- $m[4])
        printf 'protocol=%s\nhost=%s\nusername=%s\npassword=%s\n\n' $m[2] $m[5] $u $p | timeout 30 $TV_GIT_HELPER store >/dev/null 2>&1
        or set -a keep $line
    end
    if test (count $keep) -eq 0
        rm -f "$cred"
    else
        printf '%s\n' $keep > "$cred"
        chmod 600 "$cred"
    end
    return 0
end

# Membuang token dari servers.json lain (di luar ~/.easy-vibe) tanpa merusak JSON. Mengembalikan 0 bila berubah.
function tv_strip_servers_token -a file
    test -f "$file"; or return 1
    command -v python3 >/dev/null 2>&1; or return 1
    python3 -c 'import json,os,sys
p=sys.argv[1]
try:
  d=json.load(open(p))
  ch=False
  for s in d.get("servers",[]):
    e=s.get("env")
    if isinstance(e,dict) and "GITHUB_TOKEN" in e:
      del e["GITHUB_TOKEN"]
      ch=True
      if not e:
        del s["env"]
  if ch:
    t=p+".tmp"
    json.dump(d,open(t,"w"),indent=2)
    os.chmod(t,0o600)
    os.replace(t,p)
    sys.exit(0)
except Exception:
  pass
sys.exit(1)' $file 2>/dev/null
end

# Pembersihan sisa token plaintext di lokasi yang bisa dibaca AI (dipanggil setelah servers.json baru ditulis dan token aman di keyring).
function tv_scrub_legacy
    set -l d "$HOME/.easy-vibe"
    rm -f "$d/github-token"
    set -l sdir "$d/web-mcp-bridge/server"
    for f in (find "$sdir" -maxdepth 1 -name 'servers*' 2>/dev/null)
        switch (basename $f)
            case servers.json servers.example.json
                continue
        end
        rm -f "$f"
    end
    command -v python3 >/dev/null 2>&1; or return 0
    set -l files
    for f in (find "$d/audit" -maxdepth 1 -name '*.jsonl' 2>/dev/null) "$d/native-host.log"
        if test -f "$f"
            set -a files $f
        end
    end
    test (count $files) -gt 0; or return 0
    python3 -c 'import os,re,sys
pat=re.compile(r"(ghp_[A-Za-z0-9]{20,}|github_pat_[A-Za-z0-9_]{20,})")
for p in sys.argv[1:]:
  try:
    if os.path.getsize(p)>50000000:
      continue
    s=open(p,encoding="utf-8",errors="surrogateescape").read()
    n=pat.sub("***",s)
    if n!=s:
      open(p,"w",encoding="utf-8",errors="surrogateescape").write(n)
  except Exception:
    pass' $files
    return 0
end
