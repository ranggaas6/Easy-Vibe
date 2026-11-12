# Easy-Vibe

Arsitektur vibe coding lokal yang menghubungkan DeepSeek Web Chat ke tool MCP lokal lewat Web MCP Bridge.

Bukan sistem 100% lokal: AI berjalan di cloud. Yang lokal adalah penyimpanan, Git, dan eksekusi tool.

## Topologi

```
DeepSeek (LLM cloud)
    | internet
    v
Brave + Web MCP Bridge (fork)
    | native messaging (start/stop)
    v
Native host -> mcp_ws_bridge.py
    | 127.0.0.1
    v
+-- coding-mcp  (8190)  Git & berkas lintas repo di bawah $HOME
+-- filesystem  (8192)  Akses berkas independen di $HOME
```

Bridge hanya hidup selama tab `chat.deepseek.com` terbuka. Saat tab terakhir ditutup, native host mematikan bridge dan semua child server. Tidak ada proses 24 jam.

## Komponen

| Komponen | Peran |
|---|---|
| DeepSeek Web Chat | AI cloud: analisis, perencanaan, penulisan kode |
| Web MCP Bridge (fork) | Izin tool, validasi, pemicu native host |
| coding-mcp | Git & berkas lintas repo via `project_id` |
| mcp-filesystem-server | Baca/tulis berkas di luar repo |
| Native host | Menyalakan/mematikan bridge sesuai tab DeepSeek |
| Watcher | Menambah repo baru ke registry selama bridge hidup |

## Perubahan dari versi lama

- GitDesktop dihapus dari alur: tidak ada AppImage, symlink, atau ikon menu.
- `gitdesktop` dan `multi-git-mcp` digantikan `coding-mcp`.
- Pemicu on/off berpindah ke tab DeepSeek via native messaging.
- `servers.json` memakai path absolut hasil `command -v`.
- Repo baru terdeteksi otomatis: rescan saat start, watcher inotify selama bridge hidup.

## Prasyarat

Python 3.9+, Go 1.21+, Node.js + npm, Git, Brave 116+. `inotify-tools` dipasang otomatis oleh installer.

## Instalasi CachyOS + fish

```fish
git clone https://github.com/ranggaas6/Easy-Vibe
cd Easy-Vibe
fish install.fish --extension-id <ID_EXTENSION>
```

ID extension dilihat di `brave://extensions` (mode Developer).

Opsi installer:

| Opsi | Efek |
|---|---|
| `--clean` | Uninstall dulu, lalu pasang ulang |
| `--force` | Timpa instalasi lama |
| `--extension-id ID` | Wajib; dipakai di `allowed_origins` manifest native host |
| `--github-token TOKEN` | Token untuk clone privat / hindari rate limit |

Fitur pemicu tab DeepSeek hanya ada di fork `ranggaas6/web-mcp-bridge`. Upstream tidak menyediakan `nativeMessaging`, sehingga installer menolak `--upstream`.

Langkah installer:

1. Pasang paket dasar via pacman (termasuk nodejs, npm, inotify-tools).
2. Pasang `mcp-filesystem-server`; pastikan `$GOPATH/bin` di `fish_user_paths`.
3. Pasang global `@kieutrongthien/coding-mcp`; jalankan `coding-mcp init /home/<user>`.
4. Clone `ranggaas6/web-mcp-bridge`; pasang dependensi Python di venv.
5. Tulis manifest native host `com.ranggaas6.easy_vibe.json` ke folder Brave (native dan Flatpak).
6. Salin `easy-vibe-host` dan `easy-vibe-watcher` ke `~/.easy-vibe/native-host/`.
7. Tulis `servers.json` dengan path absolut.
8. Tulis `manifest.txt` untuk uninstaller.

Setelah instalasi:

1. Reload extension di `brave://extensions` karena izin `nativeMessaging` baru aktif.
2. Buka tab `chat.deepseek.com`; bridge menyala, `bridge.pid` dan `watcher.pid` muncul.
3. Tutup tab DeepSeek; bridge dan watcher mati, kedua file PID hilang.

Log pemicu dan watcher: `~/.easy-vibe/native-host.log`.

## Repo baru terdeteksi otomatis

1. **Saat bridge start**: native host menjalankan `coding-mcp init <root>`. Repo yang di-clone saat bridge mati langsung terdaftar.
2. **Selama bridge hidup**: `easy-vibe-watcher` memakai `inotifywait` untuk mendeteksi `.git` baru dan menjalankan `coding-mcp add <folder>`. Deteksi berlangsung dalam hitungan detik.
3. **Saat bridge mati**: watcher dimatikan, tidak ada proses tersisa.

Watcher hanya memakai inotify; tidak ada polling. Jika `inotifywait` tidak tersedia atau batas `max_user_watches` terlampaui, watcher berhenti dan mencatat alasannya di `native-host.log`. Panggil `refresh_project_index` dari DeepSeek sebagai cadangan manual.

## Alur kerja

1. AI memanggil `list_projects` di `coding-mcp`.
2. AI memilih `project_id`, lalu `git_status`, `git_diff`, `read_file`, `write_file`, `apply_patch`.
3. AI melakukan `git_add` dan `git_commit` bila perlu.
4. Manusia menguji.

## Uninstalasi

```fish
fish uninstall.fish --dry-run
fish uninstall.fish
```

Yang dibersihkan:

- Manifest native host di semua lokasi Brave.
- Skrip host dan watcher di `~/.easy-vibe/native-host/`.
- `bridge.pid`, `watcher.pid`, `native-host.log`.
- Proses `easy-vibe-watcher` yang masih berjalan.
- Paket npm global `@kieutrongthien/coding-mcp`.
- Registry `coding-mcp` (`~/.coding-mcp`, `~/.config/coding-mcp`).
- Direktori `~/.easy-vibe`.
- Entri `$GOPATH/bin` dari `fish_user_paths`.

Opsi: `--dry-run`, `--with-tools`, `--with-gitdesktop`, `--full`, `--yes`.

## Troubleshooting

| Gejala | Perbaikan |
|---|---|
| Bridge tidak menyala saat tab DeepSeek dibuka | Cek manifest `com.ranggaas6.easy_vibe.json` di NativeMessagingHosts Brave; `allowed_origins` harus memuat ID extension |
| Access forbidden (native host) | Jalankan ulang installer dengan `--extension-id` yang benar |
| filesystem Connection error | Path absolut di `servers.json` salah |
| Repo baru tidak terdeteksi | Cek `native-host.log`; pastikan `watcher.pid` ada dan `inotifywait` terpasang |
| Watcher mati karena max_user_watches | Tingkatkan `fs.inotify.max_user_watches` lewat sysctl |
| Installer menolak berjalan | Jalankan dari direktori hasil clone, `--extension-id` tidak kosong |

## Keamanan

Batasi `filesystem` dan `coding-mcp` ke direktori yang diinginkan. Jangan kirim kredensial ke chat. Setujui manual setiap operasi destruktif. Native host hanya menerima pesan dari extension dengan ID terdaftar.

## Lisensi

MIT
