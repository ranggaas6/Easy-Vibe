#!/usr/bin/env fish
set -g NH_NAME com.ranggaas6.easy_vibe
function nh_hosts
    set -l h "$HOME/.config/BraveSoftware/Brave-Browser/NativeMessagingHosts"
    set -l f "$HOME/.var/app/com.brave.Browser/config/BraveSoftware/Brave-Browser/NativeMessagingHosts"
    set -l c "$HOME/.config/BraveSoftware/Brave-Browser-Beta/NativeMessagingHosts"
    for d in $h $f $c
        if test -d (dirname $d)
            printf '%s\n' $d
        end
    end
end
function install_native_host -a src manifest_lines
    set -l target "$HOME/.easy-vibe/native-host/easy-vibe-host"
    mkdir -p (dirname $target)
    cp "$src" "$target"
    chmod +x "$target"
    set -a manifest_lines "native-host-script $target"
    for d in (nh_hosts)
        mkdir -p $d
        set -l mf "$d/$NH_NAME.json"
        printf '{\n  "name": "%s",\n  "description": "Easy-Vibe bridge trigger",\n  "path": "%s",\n  "type": "stdio",\n  "allowed_origins": ["chrome-extension://*/"]\n}\n' $NH_NAME $target > $mf
        set -a manifest_lines "native-host-manifest $mf"
        printf '[OK]   Manifest native host: %s\n' $mf
    end
    return 0
end
function uninstall_native_host -a manifest_lines
    for d in (nh_hosts)
        set -l mf "$d/$NH_NAME.json"
        if test -e "$mf"
            rm -f "$mf"
            printf 'dihapus: %s\n' $mf
        end
    end
    set -l s "$HOME/.easy-vibe/native-host"
    if test -d "$s"
        rm -rf "$s"
        printf 'dihapus: %s\n' $s
    end
end
