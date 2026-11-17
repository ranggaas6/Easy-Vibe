#!/usr/bin/env fish
# Helper token GitHub untuk install.fish dan uninstall.fish
#
# Token TIDAK lagi disimpan sebagai berkas di $HOME. Penyimpanan ada di keyring
# sistem (Secret Service) lewat scripts/token-vault.fish.
#
# Sumber token (prioritas):
#   1. Argumen --github-token TOKEN
#   2. Environment EASY_VIBE_GITHUB_TOKEN
#   3. Keyring (service=easy-vibe account=github)
#   4. Lokasi lama (github-token, servers.json, ~/.git-credentials): hanya untuk migrasi
#
# Format yang didukung:
#   - Classic PAT: ghp_xxxxxxxx
#   - Fine-grained PAT: github_pat_xxxxxxxx

set -l _ga_dir (realpath (dirname (status --current-filename)))
if test -f "$_ga_dir/token-vault.fish"
    source "$_ga_dir/token-vault.fish"
end

function gh_token_resolve
    set -l cli_token ""
    set -l i 1
    while test $i -le (count $argv)
        if test "$argv[$i]" = "--github-token"
            set i (math $i + 1)
            if test $i -le (count $argv)
                set cli_token $argv[$i]
            end
        end
        set i (math $i + 1)
    end

    if test -n "$cli_token"
        set -g GH_TOKEN_RESOLVED $cli_token
        set -g GH_TOKEN_SOURCE "argumen"
        return 0
    end

    if test -n "$EASY_VIBE_GITHUB_TOKEN"
        set -g GH_TOKEN_RESOLVED $EASY_VIBE_GITHUB_TOKEN
        set -g GH_TOKEN_SOURCE "env"
        return 0
    end

    if functions -q tv_lookup
        set -l from_vault (tv_lookup)
        if test -n "$from_vault"
            set -g GH_TOKEN_RESOLVED $from_vault
            set -g GH_TOKEN_SOURCE "keyring"
            return 0
        end
    end

    if functions -q tv_legacy_token
        set -l legacy (tv_legacy_token)
        if test -n "$legacy"
            set -g GH_TOKEN_RESOLVED $legacy
            set -g GH_TOKEN_SOURCE "lama"
            return 0
        end
    end

    set -g GH_TOKEN_RESOLVED ""
    set -g GH_TOKEN_SOURCE ""
    return 1
end

function gh_token_validate
    set -l t $argv[1]
    if test -z "$t"
        return 1
    end
    if string match -qr '^ghp_[A-Za-z0-9]+$' -- "$t"
        return 0
    end
    if string match -qr '^github_pat_[A-Za-z0-9_]+$' -- "$t"
        return 0
    end
    return 1
end

# Menyimpan token ke keyring (bukan ke berkas). Gagal bila keyring tidak siap.
function gh_token_save
    set -l t $argv[1]
    if test -z "$t"
        return 1
    end
    if not functions -q tv_ready; or not tv_ready
        printf '[PERINGATAN] Keyring (Secret Service) tidak siap; token tidak disimpan.\n' >&2
        return 1
    end
    tv_store $t
end

function gh_url_with_token
    set -l url $argv[1]
    set -l t $argv[2]
    if test -z "$t"
        printf '%s' $url
        return 0
    end
    set -l stripped (string replace -r '^https://' '' -- $url)
    printf 'https://%s@%s' $t $stripped
end

function gh_url_mask
    set -l url $argv[1]
    printf '%s' (string replace -r 'https://[^@]+@' 'https://***@' -- $url)
end

# Menyiapkan git credential helper libsecret (keyring) dan menyimpan kredensial github.com
# ke sana, supaya git push non-interaktif (coding_mcp) tetap berhasil tanpa
# ~/.git-credentials plaintext. Token dikirim lewat stdin.
#
# Argumen:
#   $argv[1] token PAT (wajib)
#   $argv[2] username GitHub (opsional, default: ranggaas6)
function gh_setup_git_credential
    set -l t $argv[1]
    set -l user "ranggaas6"
    if test (count $argv) -ge 2; and test -n "$argv[2]"
        set user $argv[2]
    end
    if test -z "$t"
        return 1
    end
    if not command -v git >/dev/null 2>&1
        return 1
    end
    set -l helper /usr/lib/git-core/git-credential-libsecret
    if not test -x $helper
        return 1
    end
    if not functions -q tv_ready; or not tv_ready
        return 1
    end

    # Ganti helper store (plaintext) dengan libsecret; helper lain dipertahankan.
    git config --global --fixed-value --unset-all credential.helper store 2>/dev/null
    if not contains -- $helper (git config --global --get-all credential.helper 2>/dev/null)
        git config --global --add credential.helper $helper 2>/dev/null
    end
    git config --global credential.username $user 2>/dev/null

    printf 'protocol=https\nhost=github.com\nusername=%s\npassword=%s\n\n' $user $t | timeout 30 $helper store >/dev/null 2>&1
    or return 1
    return 0
end

# Menghapus kredensial github.com dari ~/.git-credentials (sisa lama) dan dari keyring
# tanpa menyentuh host lain.
function gh_cleanup_git_credential
    set -l helper /usr/lib/git-core/git-credential-libsecret
    if test -x $helper
        if functions -q tv_dbus
            tv_dbus
        end
        printf 'protocol=https\nhost=github.com\n\n' | timeout 30 $helper erase >/dev/null 2>&1
    end
    set -l cred_file "$HOME/.git-credentials"
    if not test -f "$cred_file"
        return 0
    end
    set -l filtered
    for line in (cat "$cred_file")
        if not string match -q "*github.com*" -- "$line"
            set -a filtered $line
        end
    end
    if test (count $filtered) -eq 0
        rm -f "$cred_file"
    else
        printf '%s\n' $filtered > "$cred_file"
        chmod 600 "$cred_file"
    end
    return 0
end
