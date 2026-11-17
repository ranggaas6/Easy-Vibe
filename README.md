# Easy-Vibe

Vibe coding lokal: DeepSeek Web Chat memakai tool MCP lokal lewat Web MCP Bridge. AI berjalan di cloud; yang lokal adalah penyimpanan, Git, dan eksekusi tool.

Dokumen ini mencerminkan kondisi repo setelah penambahan server `github`, pemicu native messaging, perekam panggilan (`mcp-audit` + `audit-brief`), penyimpanan token GitHub di keyring (libsecret) untuk push non-interaktif, dan alur kerja **Opsi B**.

## Ringkasan

- AI (DeepSeek Web) memanggil tool lewat blok JSON `mcp_call`; ekstensi Web MCP Bridge menjalankannya di komputer Anda.
- Tiga server MCP lokal: `coding-mcp` (berkas + Git), `github` (GitHub API), `filesystem` (berkas independen).
- **Opsi B** adalah alur kerja default: semua perubahan berkas dan Git dikerjakan di disk lokal lewat `coding-mcp`; server `github` hanya untuk hal yang ada di remote (PR, issue, release, hapus branch, verifikasi). Lihat [docs/opsi-b.md](docs/opsi-b.md).
- Push dari `coding-mcp` berjalan tanpa prompt kredensial karena installer menyimpan token di keyring dan menyiapkan `git-credential-libsecret` sebagai credential helper.

## Topologi

```
DeepSeek (cloud)
    | internet
    v
Brave + Web MCP Bridge (fork)
    | native messaging (start/stop)
    v
Native host -> start-easy-vibe.fish -> mcp_ws_bridge.py
    | 127.0.0.1
    v
+-- coding-mcp  (8190)  Git & berkas lintas repo di $HOME
+-- github      (8191)  GitHub API (PR, issue, branch, release)
+-- filesystem  (8192)  Akses berkas independen

(opsional) tiap server dibungkus mcp-audit -> ~/.easy-vibe/audit/*.jsonl
           audit-brief.py memantau log -> snapshot wip + brief.txt
```

Bridge hanya hidup selama tab `chat.deepseek.com` terbuka. Saat tab terakhir ditutup, native host mematikan bridge dan semua child server. Port kontrol bridge 8199, port launcher 8198.

## Komponen

| Komponen | Peran |
|---|---|
| DeepSeek Web Chat | AI cloud |
| Web MCP Bridge (fork `ranggaas6/web-mcp-bridge`) | Izin tool, validasi, pemicu native host |
| coding-mcp (`@kieutrongthien/coding-mcp`) | Git & berkas lintas repo via `project_id` |
| github-mcp-server-kosta | GitHub API langsung: PR, issue, branch, release, delete_branch |
| mcp-filesystem-server | Berkas di luar repo terdaftar |
| Native host (`easy-vibe-host`) | On/off bridge sesuai tab DeepSeek |
| Watcher (`easy-vibe-watcher`) | Menambah repo baru ke registry selama bridge hidup (inotify) |
| mcp-audit (opsional) | Merekam panggilan tool ke log JSONL |
| audit-brief.py (opsional) | Snapshot Git `refs/wip/autosave` dan `brief.txt` untuk melanjutkan sesi |

## Prasyarat

CachyOS/Arch dengan `pacman` dan shell `fish`. Python 3.9+, Go, Node.js + npm, Git, Brave 116+. Paket dasar dipasang installer lewat pacman: `git python python-pip go curl base-devel nodejs npm inotify-tools libsecret`. Installer berhenti bila `pacman` tidak ditemukan.

Periksa lingkungan sebelum atau sesudah instalasi:

```fish
fish scripts/check-prerequisites.fish
```

Versi bash (`scripts/check-prerequisites.sh`) hanya memeriksa perangkat dasar dan berkas konfigurasi.

## Instalasi

```fish
git clone https://github.com/ranggaas6/Easy-Vibe
cd Easy-Vibe
fish install.fish --extension-id <ID_EXTENSION> --github-token <TOKEN>
```

ID extension dilihat di `brave://extensions` (mode Developer). Token GitHub berupa PAT dengan scope `repo` (format `ghp_...` atau `github_pat_...`). Scope `repo` diperlukan agar `delete_branch`, pembuatan PR, dan push berfungsi.

Urutan sumber token: `--github-token` lalu variabel `EASY_VIBE_GITHUB_TOKEN` lalu keyring (service `easy-vibe`, account `github`) lalu lokasi lama (hanya untuk migrasi). Pada terminal interaktif, installer menawarkan tempel token baru lewat input tersembunyi (tanpa token di argumen perintah); jika belum ada token, installer menanyakannya. Menekan Enter melewati token; server `github` tidak akan aktif. Token disimpan di keyring, bukan berkas di `$HOME`.

Opsi installer:

| Opsi | Efek |
|---|---|
| `--clean` | Menjalankan `uninstall.fish --yes` dulu, lalu memasang ulang |
| `--force` | Menimpa instalasi lama (tanpa ini, instalasi lama yang terdeteksi lewat `manifest.txt` ditolak) |
| `--extension-id ID` | Wajib; dipakai untuk `allowed_origins` native host |
| `--github-token TOKEN` | Token untuk clone, GitHub API, dan push |
| `--skip-gitdesktop` | Diterima tetapi tidak berefek (sisa kompatibilitas) |
| `--upstream` | Ditolak: native messaging hanya ada di fork |

### Yang dilakukan installer

1. Membaca argumen dan menentukan token (`gh_token_resolve`), memvalidasi format, lalu menawarkan tempel token baru lewat input tersembunyi pada terminal interaktif.
2. Menyimpan token ke keyring (`gh_token_save`) dan menyiapkan kredensial git (`gh_setup_git_credential`): `credential.helper` diganti ke `git-credential-libsecret`, `credential.username` diatur, dan kredensial `github.com` disimpan di keyring. Helper `store` (plaintext) lama dibuang; helper lain dipertahankan.
3. Memasang paket dasar via pacman (termasuk `libsecret`).
4. Memasang `mcp-filesystem-server` (`go install`), memastikan `$GOPATH/bin` ada di `fish_user_paths`.
5. Memasang global `@kieutrongthien/coding-mcp` (prefix npm `~/.npm-global`), lalu `coding-mcp init` pada root. Jika direktori root yang tertulis di skrip tidak ada, installer memakai `$HOME`. Root tambahan: `~/.cargo` dan `~/.easy-vibe` bila ada.
6. Memasang global `github-mcp-server-kosta`; binary lama `github-mcp-server` dihapus bila ada.
7. Clone `ranggaas6/web-mcp-bridge` ke `~/.easy-vibe/web-mcp-bridge` (token dipakai di URL clone, lalu remote dikembalikan ke HTTPS polos), menghapus sisa helper `store` (plaintext) pada level repo bila ada, membuat venv di `~/.easy-vibe/venv`, memasang `server/requirements.txt`. Lalu `coding-mcp init` untuk folder bridge.
8. Menulis manifest native host ke folder Brave dan menyalin host serta watcher ke `~/.easy-vibe/native-host/`.
9. Memasang `mcp-audit` (clone `firatmio/mcp-audit-proxy`, `go build`) dan menyalin `audit-brief.py`. Jika `go` tidak ada atau build gagal, tahap ini dilewati dan server berjalan tanpa perekam.
10. Menulis `server/servers.json` (path absolut, chmod 600) dan launcher `~/.easy-vibe/start-easy-vibe.fish`.
11. Menulis `manifest.txt` untuk uninstaller.

Server `coding-mcp` di `servers.json` mendapat `env.ALLOWED_COMMANDS` = `cargo,rustc,git,pgrep,node,npm,pacman,busctl,fish,diff,python3`. Token GitHub tidak ditulis ke `servers.json`: entri `github` memakai wrapper yang mengambil token dari keyring.

### Setelah instalasi

1. Reload extension di `brave://extensions`.
2. Buka tab `chat.deepseek.com`; bridge menyala, `bridge.pid` dan `watcher.pid` muncul di `~/.easy-vibe`.
3. Tutup tab DeepSeek; bridge dan watcher mati.
4. Tempelkan isi [prompts/system-prompt-id.md](prompts/system-prompt-id.md) sebagai aturan pemakaian tool bila diperlukan.

Log native host: `~/.easy-vibe/native-host.log`.

## Lokasi file penting di mesin

| Path | Isi |
|---|---|
| Keyring sistem (service `easy-vibe`, account `github`) | PAT GitHub; dibaca server `github` lewat `~/.easy-vibe/bin/github-mcp-wrapper` dan git CLI lewat `git-credential-libsecret` |
| `~/.easy-vibe/bin/github-mcp-wrapper` | Wrapper yang mengambil token dari keyring saat server `github` start (tanpa token di berkas) |
| `~/.easy-vibe/web-mcp-bridge/` | Clone fork bridge dan `server/servers.json` |
| `~/.easy-vibe/venv/` | Python venv bridge |
| `~/.easy-vibe/native-host/` | `easy-vibe-host`, `easy-vibe-watcher` |
| `~/.easy-vibe/start-easy-vibe.fish` | Launcher bridge (menjalankan `audit-brief.py` bila ada) |
| `~/.easy-vibe/audit/*.jsonl` | Log panggilan tool (hanya pemilik) |
| `~/.easy-vibe/brief.txt` | Ringkasan 10 panggilan terakhir dan status Git proyek |
| `~/.easy-vibe/manifest.txt` | Daftar artefak untuk uninstaller |

## Opsi B (alur kerja default)

Prinsip: ubah berkas dan kerjakan Git di disk lokal lewat `coding-mcp`. Gunakan `github` hanya untuk hal yang ada di remote.

| Server | Pakai untuk | Jangan pakai untuk |
|---|---|---|
| `coding-mcp` | Baca/tulis berkas (`write_file`, `apply_patch`, `replace_in_file`), seluruh alur Git (`git_status`, `git_diff`, `git_add`, `git_commit`, `git_push`, `git_pull`, cabang lokal), `delete_file` | Repo yang belum terdaftar sebagai proyek; merge, rebase, force push (tool-nya tidak ada) |
| `filesystem` | Baca dan bantu: `list_directory`, `read_file`, `get_file_info`, `search_files`, `copy_file` | Menjalankan Git; menghapus folder (dilaporkan gagal, lihat docs/opsi-b.md) |
| `github` | PR, issue, label, review, merge, release, membaca repo yang belum di-clone, `github_compare`, `github_delete_branch`, verifikasi isi branch | `github_create_or_update_file` untuk file besar (belum teruji) |

Ringkas:

1. `list_projects` lalu pilih `project_id`. Jika repo belum terdaftar, salin ke satu level di bawah `$HOME`, `refresh_project_index`, catat `project_id`.
2. Ubah dengan `write_file` atau `apply_patch`.
3. Verifikasi dengan `git_status` dan `git_diff`.
4. `git_add`, `git_commit`, `git_push` (cabang baru: `set_upstream: true`).
5. Verifikasi di remote dengan `github_list_contents` atau `github_get_file_content`.
6. Bersihkan branch uji dengan `github_delete_branch`.

Detail, aturan penghapusan, hasil uji, dan batasan: [docs/opsi-b.md](docs/opsi-b.md).

## Push non-interaktif (credential.helper libsecret)

`git push` dari `coding-mcp` berjalan sebagai subprocess tanpa TTY. Tanpa helper, git gagal dengan `fatal: could not read Username for 'https://github.com': No such device or address`. Installer menyimpan token di keyring (Secret Service) dan menyiapkan `git-credential-libsecret` sebagai `credential.helper` global, sehingga git membaca kredensial dari keyring tanpa berkas plaintext.

Catatan:

- PAT tersimpan di keyring sistem, bukan di `~/.git-credentials`. Instalasi lama dimigrasikan otomatis dan sisa plaintext dibersihkan.
- Keyring harus aktif (sesi desktop dengan Secret Service, mis. KWallet atau gnome-keyring); jika tidak, token tidak tersimpan dan push non-interaktif gagal.
- Username default di skrip adalah `ranggaas6` (nilai bawaan `gh_setup_git_credential` di `scripts/github-auth.fish`); ganti jika memakai akun lain.
- Remote repo memakai HTTPS polos tanpa token di URL.
- Uninstaller menghapus item keyring `easy-vibe/github`, kredensial `github.com` di helper libsecret, dan sisa entri `github.com` di `~/.git-credentials`; entri host lain dipertahankan. Konfigurasi `git config --global credential.helper` tidak diubah uninstaller.

## Repo baru terdeteksi otomatis

1. **Saat bridge start**: native host menjalankan `coding-mcp init <root>` (root = `$EASY_VIBE_ROOT`, default `$HOME`).
2. **Selama bridge hidup**: `easy-vibe-watcher` memakai `inotifywait` dan menjalankan `coding-mcp add <folder>` saat folder `.git` baru muncul.
3. **Saat bridge mati**: watcher dimatikan.

Tidak ada polling. Jika `inotifywait` gagal atau `max_user_watches` terlampaui, watcher berhenti dan mencatat di `native-host.log`. Panggil `refresh_project_index` sebagai cadangan.

Penting: `coding-mcp` hanya mendeteksi proyek satu level di bawah root. Repo yang lebih dalam (misalnya `~/.easy-vibe/web-mcp-bridge`) mungkin tidak muncul di `list_projects`; lihat Opsi B.

## Audit dan brief (opsional)

Jika `go` tersedia saat instalasi, setiap server dibungkus `mcp-audit` dan mencatat panggilan ke `~/.easy-vibe/audit/<server>.jsonl`. Launcher menjalankan `audit-brief.py` yang:

- Setelah panggilan tulis (`write_file`, `create_file`, `apply_patch`, `replace_in_file`, `move_file`, `delete_file`) menyimpan snapshot pohon kerja ke `refs/wip/autosave` tanpa menyentuh branch, index, atau riwayat. Lihat dengan `git show refs/wip/autosave`.
- Menulis `~/.easy-vibe/brief.txt` berisi 10 panggilan terakhir dan status Git proyek, untuk melanjutkan sesi di akun lain.
- Merotasi log yang melebihi 5 MB (satu cadangan `.1`).

## Alur kerja harian

1. AI memanggil `list_projects` di `coding-mcp`.
2. AI memilih `project_id`, lalu `git_status`, `git_diff`, `read_file`, `write_file` / `apply_patch`.
3. AI melakukan `git_add` dan `git_commit`; `git_push` bila disetujui.
4. Untuk PR, issue, release, `delete_branch`, AI memakai server `github` dengan `repo_url`.
5. Manusia menguji dan menyetujui operasi destruktif.

Detail: [docs/alur-kerja.md](docs/alur-kerja.md).

## Struktur repo

```
Easy-Vibe/
├── install.fish              Installer utama
├── uninstall.fish            Uninstaller berbasis manifest
├── config/
│   ├── bridge-servers.example.json   Contoh servers.json
│   └── mcp.json                      Contoh konfigurasi klien MCP
├── docs/                     Dokumentasi (lihat bawah)
├── prompts/system-prompt-id.md       Aturan pemakaian tool untuk AI
├── scripts/
│   ├── github-auth.fish      Token dan kredensial git
│   ├── install-base.fish     Prasyarat, filesystem, coding-mcp, github-mcp
│   ├── install-bridge.fish   Clone dan venv bridge
│   ├── install-native-host.fish  Manifest native host Brave
│   ├── install-audit.fish    mcp-audit
│   ├── audit-brief.py        Snapshot wip dan brief.txt
│   ├── check-prerequisites.fish / .sh
│   ├── start-bridge.sh       Jalankan bridge manual (tanpa installer)
│   └── native-host/          easy-vibe-host, easy-vibe-watcher
└── .github/workflows/validate.yml    CI: validasi JSON dan ShellCheck
```

## Uninstalasi

```fish
fish uninstall.fish --dry-run
fish uninstall.fish
```

Yang dibersihkan: artefak di `manifest.txt` (manifest dan skrip native host, paket npm global `@kieutrongthien/coding-mcp` dan `github-mcp-server-kosta`), manifest native host di semua lokasi Brave, `bridge.pid`, `watcher.pid`, `native-host.log`, layanan systemd pengguna terkait, proses (`easy-vibe-watcher`, `audit-brief.py`, `mcp-audit`, `mcp_ws_bridge.py`, `coding-mcp`, `github-mcp-server-kosta`, `mcp-filesystem-server`, `easy-vibe-host`), root tambahan di registry `coding-mcp`, `~/.coding-mcp`, item keyring `easy-vibe/github`, entri `github.com` di helper libsecret dan sisa di `~/.git-credentials`, direktori `~/.easy-vibe`, dan entri `$GOPATH/bin` di `fish_user_paths`.

Opsi: `--dry-run`, `--with-tools`, `--with-gitdesktop` (sisa kompatibilitas), `--full` (juga paket pacman dasar, dengan konfirmasi), `--yes`.

## Troubleshooting

| Gejala | Perbaikan |
|---|---|
| Bridge tidak menyala | Cek manifest `com.ranggaas6.easy_vibe.json` dan `allowed_origins`; lihat `~/.easy-vibe/native-host.log` |
| Access forbidden (native host) | Jalankan ulang installer dengan `--extension-id` yang benar |
| filesystem Connection error | Path absolut di `servers.json` salah |
| github Connection error | Token kosong atau tidak valid; jalankan installer dengan `--github-token` |
| `delete_branch` / push gagal 403 | Token tidak punya scope `repo` |
| `could not read Username for 'https://github.com'` | Helper libsecret atau keyring belum aktif; jalankan ulang installer dengan token, periksa `git config --global --get-all credential.helper`, dan pastikan Secret Service (KWallet atau gnome-keyring) berjalan |
| Repo tidak ada di `list_projects` | Panggil `refresh_project_index`; repo harus satu level di bawah root; lihat Opsi B |
| Repo baru tidak terdeteksi | Cek `watcher.pid` dan `inotifywait` |
| Watcher mati `max_user_watches` | Tingkatkan `fs.inotify.max_user_watches` |
| `mcp-audit` dilewati | `go` tidak ada atau build gagal; server tetap jalan tanpa perekam |
| `run_command_safe` menolak `git` | Gunakan tool `git_*` bawaan `coding-mcp` |

## Keamanan

Token GitHub disimpan di keyring sistem, bukan di `servers.json` atau berkas di `$HOME`; `servers.json` tetap chmod 600. Jangan commit berkas konfigurasi lokal. Batasi direktori tool. Jangan kirim kredensial ke chat. Setujui operasi destruktif secara manual. Native host hanya menerima pesan dari extension dengan ID terdaftar. Log audit berisi argumen panggilan tool, jadi perlakukan sebagai data sensitif. Lihat [docs/keamanan.md](docs/keamanan.md) dan [docs/privasi.md](docs/privasi.md).

## Dokumentasi lanjutan

| Dokumen | Isi |
|---|---|
| [docs/opsi-b.md](docs/opsi-b.md) | Alur kerja Opsi B, pembagian tugas server, aturan hapus, hasil uji, batasan |
| [docs/alur-kerja.md](docs/alur-kerja.md) | Urutan kerja AI dan manusia |
| [docs/arsitektur.md](docs/arsitektur.md) | Topologi, pemicu on/off, konfigurasi, token |
| [docs/keamanan.md](docs/keamanan.md) | Model ancaman dan checklist |
| [docs/privasi.md](docs/privasi.md) | Klaim privasi yang akurat |
| [docs/risiko.md](docs/risiko.md) | Register risiko |

Repo bridge (fork): [ranggaas6/web-mcp-bridge](https://github.com/ranggaas6/web-mcp-bridge).

## Lisensi

MIT
