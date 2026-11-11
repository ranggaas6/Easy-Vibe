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
