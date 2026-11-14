#!/usr/bin/env fish
set -g DRY 0
set -g TOOLS 0
set -g GD 0
set -g FULL 0
set -g YES 0
set -g PKGS_TO_REMOVE
set -g NH_MANIFESTS
set -g CODING_ROOTS
for a in $argv
  switch $a
    case --dry-run
      set DRY 1
    case --with-tools
      set TOOLS 1
    case --with-gitdesktop
      set GD 1
    case --full
      set FULL 1; set TOOLS 1; set GD 1
    case --yes -y
      set YES 1
    case -h --help
      echo "Pemakaian: fish uninstall.fish [--dry-run] [--with-tools] [--with-gitdesktop] [--full] [--yes]"
      exit 0
    case '*'
      echo "Opsi tidak dikenal: $a" >&2; exit 1
  end
end
set -l DIR "$HOME/.easy-vibe"
set -l SCRIPT_DIR (realpath (dirname (status --current-filename)))
if test -f "$SCRIPT_DIR/scripts/github-auth.fish"
  source "$SCRIPT_DIR/scripts/github-auth.fish"
end
set -l MANIFEST "$DIR/manifest.txt"
set -l GOBIN (go env GOPATH 2>/dev/null)/bin
set -g NH_NAME com.ranggaas6.easy_vibe
function say -a m; printf "%s\n" "$m"; end
function rm_path -a p
  if test -e "$p"
    if test $DRY -eq 1
      say "akan dihapus: $p"
    else
      rm -rf "$p"; say "dihapus: $p"
    end
  end
end
say "== Uninstaller Easy-Vibe =="
if test $DRY -eq 1; say "mode dry-run"; end
if test -f "$MANIFEST"
  say "== Artefak dari manifest =="
  for line in (cat "$MANIFEST")
    set -l parts (string split " " -- $line)
    if test (count $parts) -lt 2; continue; end
    switch $parts[1]
      case gitdesktop-appimage gitdesktop-mcp-link gitdesktop-desktop-file
        rm_path $parts[2]
      case mcp-filesystem-server gitrs-mcp
        if test $TOOLS -eq 1; rm_path $parts[2]; end
      case native-host-script native-host-watcher
        rm_path $parts[2]
      case native-host-manifest
        set -a NH_MANIFESTS $parts[2]
      case npm-global
        if test $DRY -eq 1
          say "akan dicopot via npm: $parts[2]"
        else
          npm uninstall -g $parts[2]; say "dicopot via npm: $parts[2]"
        end
      case coding-mcp-root
        set -a CODING_ROOTS $parts[2]
      case pacman-pkg
        set -a PKGS_TO_REMOVE $parts[2]
      case git-credentials-file
        if functions -q gh_cleanup_git_credential
          if test $DRY -eq 1
            say "akan membersihkan entri github.com di: $parts[2]"
          else
            gh_cleanup_git_credential
            say "entri github.com dibersihkan dari: $parts[2]"
          end
        end
    end
  end
else
  say "== Manifest tidak ditemukan (fallback) =="
end
say "== Native host di Brave =="
for d in "$HOME/.config/BraveSoftware/Brave-Browser/NativeMessagingHosts" "$HOME/.config/BraveSoftware/Brave-Browser-Beta/NativeMessagingHosts" "$HOME/.var/app/com.brave.Browser/config/BraveSoftware/Brave-Browser/NativeMessagingHosts"
  set -l mf "$d/$NH_NAME.json"
  if test -e "$mf"; and not contains "$mf" $NH_MANIFESTS
    rm_path "$mf"
  end
end
for mf in $NH_MANIFESTS; rm_path "$mf"; end
rm_path "$DIR/native-host"
rm_path "$DIR/bridge.pid"
rm_path "$DIR/watcher.pid"
rm_path "$DIR/native-host.log"
say "== Layanan systemd pengguna =="
for f in (ls "$HOME/.config/systemd/user" 2>/dev/null)
  if string match -q "*easy-vibe*" "$f"; or string match -q "*mcp-ws-bridge*" "$f"; or string match -q "*web-mcp-bridge*" "$f"
    if test $DRY -eq 0
      systemctl --user stop "$f" 2>/dev/null
      systemctl --user disable "$f" 2>/dev/null
    end
    rm_path "$HOME/.config/systemd/user/$f"
  end
end
say "== Proses berjalan =="
for n in easy-vibe-watcher mcp_ws_bridge.py coding-mcp github-mcp-server-kosta github-mcp-server gitdesktop-mcp gitrs-mcp mcp-filesystem-server easy-vibe-host
  if pgrep -f "$n" >/dev/null 2>&1
    if test $DRY -eq 0
      pkill -f "$n" 2>/dev/null; say "dihentikan: $n"
    else
      say "akan dihentikan: $n"
    end
  end
end
say "== Registry coding-mcp =="
for r in $CODING_ROOTS; say "root proyek: $r (tidak dihapus)"; end
rm_path "$HOME/.coding-mcp"
rm_path "$HOME/.config/coding-mcp"
say "== Kredensial git =="
if functions -q gh_cleanup_git_credential
  if test $DRY -eq 1
    say "akan membersihkan entri github.com di ~/.git-credentials"
  else
    gh_cleanup_git_credential
    say "entri github.com dibersihkan dari ~/.git-credentials"
  end
end
say "== Direktori instalasi =="
rm_path "$DIR"
say "== fish PATH =="
if contains "$GOBIN" $fish_user_paths
  if test $DRY -eq 0
    set -U fish_user_paths (string match -v -- "$GOBIN" $fish_user_paths)
    say "dihapus dari fish_user_paths: $GOBIN"
  else
    say "akan dihapus dari fish_user_paths: $GOBIN"
  end
end
if test $TOOLS -eq 1
  say "== Tool MCP =="
  rm_path "$HOME/.local/bin/gitrs-mcp"
  rm_path "$GOBIN/mcp-filesystem-server"
end
if test $GD -eq 1
  say "== GitDesktop (flag eksplisit) =="
  rm_path "$HOME/.local/bin/gitdesktop-mcp"
  for c in "$HOME/Applications/GitDesktop.AppImage" "$HOME/Applications/GitDesktop_"*"_amd64.AppImage"; rm_path "$c"; end
  rm_path "$HOME/.local/share/applications/gitdesktop.desktop"
end
if test $FULL -eq 1
  say "== Paket pacman dasar =="
  if test (count $PKGS_TO_REMOVE) -eq 0
    for p in git python python-pip go curl base-devel nodejs npm inotify-tools
      if pacman -Qi $p >/dev/null 2>&1; set -a PKGS_TO_REMOVE $p; end
    end
  end
  if test (count $PKGS_TO_REMOVE) -eq 0
    say "Tidak ada paket pacman yang perlu dihapus."
  else
    say "Paket pacman berikut akan dihapus:"
    for p in $PKGS_TO_REMOVE; say "  - $p"; end
    if test $YES -eq 1; set -l jawab y; else; read -l -P "Hapus paket pacman di atas? [y/N] " jawab; end
    if test "$jawab" = "y"; or test "$jawab" = "Y"
      if test $DRY -eq 0
        sudo pacman -Rns --noconfirm $PKGS_TO_REMOVE; say "paket pacman dihapus"
      else
        say "akan dihapus via pacman: $PKGS_TO_REMOVE"
      end
    else
      say "Penghapusan paket pacman dibatalkan."
    end
  end
end
say "== Selesai =="
if test $DRY -eq 1
  say "Jalankan tanpa --dry-run untuk benar-benar menghapus."
else
  say "Buka terminal baru agar PATH aktif."
end
