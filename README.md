# Easy-Vibe

Vibe coding lokal: DeepSeek Web Chat memakai tool MCP lokal lewat Web MCP Bridge. AI berjalan di cloud; yang lokal adalah penyimpanan, Git, dan eksekusi tool.

## Topologi

```
DeepSeek (cloud)
    | internet
    v
Brave + Web MCP Bridge (fork)
    | native messaging (start/stop)
    v
Native host -> mcp_ws_bridge.py
    | 127.0.0.1
    v
+-- coding-mcp  (8190)  Git & berkas lintas repo di $HOME
+-- github      (8191)  GitHub API (PR, issue, branch, release)
+-- filesystem  (8192)  Akses berkas independen
```

Bridge hanya hidup selama tab `chat.deepseek.com` terbuka. Saat tab terakhir ditutup, native host mematikan bridge dan semua child server.

## Komponen

| Komponen | Peran |
|---|---|
| DeepSeek Web Chat | AI cloud |
| Web MCP Bridge (fork) | Izin tool, validasi, pemicu native host |
| coding-mcp | Git & berkas lintas repo via `project_id` |
| github-mcp-server-kosta | GitHub API langsung: PR, issue, branch, release, delete_branch |
| mcp-filesystem-server | Berkas di luar repo |
| Native host | On/off sesuai tab DeepSeek |
| Watcher | Tambah repo baru ke registry selama bridge hidup |

## Perubahan dari versi lama

- GitDesktop dihapus dari alur.
- `gitdesktop` dan `multi-git-mcp` digantikan `coding-mcp`.
- Server `github` ditambahkan untuk akses GitHub API tanpa clone lokal.
- Pemicu on/off berpindah ke tab DeepSeek via native messaging.
- `servers.json` memakai path absolut dan disimpan chmod 600 karena memuat token.
- Repo baru terdeteksi otomatis: rescan saat start, watcher inotify selama bridge hidup.

## Prasyarat

Python 3.9+, Go 1.21+, Node.js + npm, Git, Brave 116+. `inotify-tools` dipasang otomatis.

## Instalasi CachyOS + fish

```fish
git clone https://github.com/ranggaas6/Easy-Vibe
cd Easy-Vibe
fish install.fish --extension-id <ID_EXTENSION> --github-token <TOKEN>
```

ID extension dilihat di `brave://extensions` (mode Developer). Token GitHub perlu scope `repo` agar `delete_branch` dan operasi tulis lain berfungsi. Token disimpan di `~/.easy-vibe/github-token` (chmod 600).

Opsi installer:

| Opsi | Efek |
|---|---|
| `--clean` | Uninstall dulu, lalu pasang ulang |
| `--force` | Timpa instalasi lama |
| `--extension-id ID` | Wajib; untuk `allowed_origins` native host |
| `--github-token TOKEN` | Token untuk clone privat, GitHub API, dan rate limit |

Fitur pemicu tab DeepSeek hanya ada di fork `ranggaas6/web-mcp-bridge`. Upstream tidak menyediakan `nativeMessaging`, sehingga installer menolak `--upstream`.

Langkah installer:

1. Pasang paket dasar via pacman (termasuk nodejs, npm, inotify-tools).
2. Pasang `mcp-filesystem-server`; pastikan `$GOPATH/bin` di `fish_user_paths`.
3. Pasang global `@kieutrongthien/coding-mcp`; jalankan `coding-mcp init /home/<user>`.
4. Pasang global `github-mcp-server-kosta`; hapus `github-mcp-server` lama bila ada.
5. Clone `ranggaas6/web-mcp-bridge`; pasang dependensi Python di venv.
6. Tulis manifest native host ke folder Brave; salin host dan watcher.
7. Tulis `servers.json` dengan path absolut; entri `github` memuat `GITHUB_TOKEN` di `env`.
8. Tulis `manifest.txt` untuk uninstaller.

Setelah instalasi:

1. Reload extension di `brave://extensions`.
2. Buka tab `chat.deepseek.com`; bridge menyala, `bridge.pid` dan `watcher.pid` muncul.
3. Tutup tab DeepSeek; bridge dan watcher mati.

Log: `~/.easy-vibe/native-host.log`.

## Repo baru terdeteksi otomatis

1. **Saat bridge start**: native host menjalankan `coding-mcp init <root>`.
2. **Selama bridge hidup**: `easy-vibe-watcher` memakai `inotifywait` dan menjalankan `coding-mcp add <folder>`.
3. **Saat bridge mati**: watcher dimatikan.

Tidak ada polling. Jika `inotifywait` gagal atau `max_user_watches` terlampaui, watcher berhenti dan mencatat di `native-host.log`. Panggil `refresh_project_index` sebagai cadangan.

## Alur kerja

1. AI memanggil `list_projects` di `coding-mcp`.
2. AI memilih `project_id`, lalu `git_status`, `git_diff`, `read_file`, `write_file`, `apply_patch`.
3. AI melakukan `git_add` dan `git_commit` bila perlu.
4. Untuk operasi GitHub (PR, issue, release, delete_branch), AI memakai server `github` dengan `repo_url`.
5. Manusia menguji.

## Uninstalasi

```fish
fish uninstall.fish --dry-run
fish uninstall.fish
```

Yang dibersihkan:

- Manifest native host di semua lokasi Brave.
- Skrip host dan watcher.
- `bridge.pid`, `watcher.pid`, `native-host.log`.
- Proses `easy-vibe-watcher`, `github-mcp-server-kosta`, `github-mcp-server`.
- Paket npm global `@kieutrongthien/coding-mcp` dan `github-mcp-server-kosta`.
- Registry `coding-mcp`.
- Direktori `~/.easy-vibe`, termasuk `github-token`.
- Entri `$GOPATH/bin` dari `fish_user_paths`.

Opsi: `--dry-run`, `--with-tools`, `--with-gitdesktop`, `--full`, `--yes`.

## Troubleshooting

| Gejala | Perbaikan |
|---|---|
| Bridge tidak menyala | Cek manifest `com.ranggaas6.easy_vibe.json` dan `allowed_origins` |
| Access forbidden (native host) | Jalankan ulang installer dengan `--extension-id` benar |
| filesystem Connection error | Path absolut di `servers.json` salah |
| github Connection error | Token kosong atau tidak valid; jalankan installer dengan `--github-token` |
| delete_branch gagal 403 | Token tidak punya scope `repo` |
| Repo baru tidak terdeteksi | Cek `watcher.pid` dan `inotifywait` |
| Watcher mati max_user_watches | Tingkatkan `fs.inotify.max_user_watches` |

## Keamanan

`servers.json` memuat token GitHub di `env`, jadi installer menyimpannya dengan chmod 600. Jangan commit `servers.json`. Batasi direktori tool. Jangan kirim kredensial ke chat. Setujui operasi destruktif secara manual. Native host hanya menerima pesan dari extension dengan ID terdaftar.

## Lisensi

MIT
