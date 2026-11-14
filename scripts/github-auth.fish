#!/usr/bin/env fish
# Helper token GitHub untuk install.fish
#
# Sumber token (prioritas):
#   1. Argumen --github-token TOKEN
#   2. Environment EASY_VIBE_GITHUB_TOKEN
#   3. File ~/.easy-vibe/github-token (chmod 600)
#
# Format yang didukung:
#   - Classic PAT: ghp_xxxxxxxx
#   - Fine-grained PAT: github_pat_xxxxxxxx

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

    set -l token_file "$HOME/.easy-vibe/github-token"

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

    if test -f "$token_file"
        set -l from_file (string trim < "$token_file")
        if test -n "$from_file"
            set -g GH_TOKEN_RESOLVED $from_file
            set -g GH_TOKEN_SOURCE "file"
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

function gh_token_save
    set -l t $argv[1]
    if test -z "$t"
        return 1
    end
    set -l dir "$HOME/.easy-vibe"
    mkdir -p $dir
    set -l f "$dir/github-token"
    printf '%s\n' $t > $f
    chmod 600 $f
    return 0
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

# Menyiapkan credential.helper store global dan menulis entri github.com
# ke ~/.git-credentials supaya git push non-interaktif (dari coding_mcp
# atau subprocess lain tanpa TTY) tetap berhasil.
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

    # Aktifkan helper store secara global (tanpa prompt TTY)
    git config --global credential.helper store 2>/dev/null
    git config --global credential.username $user 2>/dev/null

    set -l cred_file "$HOME/.git-credentials"
    set -l entry "https://$user:$t@github.com"

    # Buang entri github.com lama, pertahankan host lain
    if test -f "$cred_file"
        set -l filtered
        for line in (cat "$cred_file")
            if not string match -q "*github.com*" -- "$line"
                set -a filtered $line
            end
        end
        if test (count $filtered) -gt 0
            printf '%s\n' $filtered > "$cred_file"
        else
            : > "$cred_file"
        end
    end

    printf '%s\n' $entry >> "$cred_file"
    chmod 600 "$cred_file"
    return 0
end

# Menghapus entri github.com dari ~/.git-credentials tanpa menyentuh host lain.
function gh_cleanup_git_credential
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
