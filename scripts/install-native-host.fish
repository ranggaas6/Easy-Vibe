#!/usr/bin/env fish
set -g NH_NAME com.ranggaas6.easy_vibe
function nh_hosts
    set -l h "$HOME/.config/BraveSoftware/Brave-Browser/NativeMessagingHosts"
    set -l f "$HOME/.var/app/com.brave.Browser/config/BraveSoftware/Brave-Browser/NativeMessagingHosts"
    set -l c "$HOME/.config/BraveSoftware/Brave-Browser-Beta/NativeMessagingHosts"
    for d in $h $f $c
        if test -d (dirname $d); printf '%s\n' $d; end
    end
end
# Tanpa parameter manifest_lines: variabel global milik pemanggil dipakai langsung.
function install_native_host -a src extension_id
    if test -z "$extension_id"
        printf '[GAGAL] extension_id kosong\n' >&2; return 1
    end
    set -l t "$HOME/.easy-vibe/native-host/easy-vibe-host"
    mkdir -p (dirname $t); cp "$src" "$t"; chmod +x "$t"
    set -g manifest_lines $manifest_lines "native-host-script $t"
    for d in (nh_hosts)
        mkdir -p $d; set -l mf "$d/$NH_NAME.json"
        printf '{\n  "name": "%s",\n  "description": "Easy-Vibe bridge trigger",\n  "path": "%s",\n  "type": "stdio",\n  "allowed_origins": ["chrome-extension://%s/"]\n}\n' $NH_NAME $t $extension_id > $mf
        set -g manifest_lines $manifest_lines "native-host-manifest $mf"
        printf '[OK]   Manifest native host: %s\n' $mf
    end
    return 0
end
function uninstall_native_host
    for d in (nh_hosts)
        set -l mf "$d/$NH_NAME.json"
        if test -e "$mf"; rm -f "$mf"; printf 'dihapus: %s\n' $mf; end
    end
    set -l s "$HOME/.easy-vibe/native-host"
    if test -d "$s"; rm -rf "$s"; printf 'dihapus: %s\n' $s; end
end
