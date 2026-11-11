# Easy-Vibe

Implementasi arsitektur **vibe coding lokal** yang menghubungkan DeepSeek Web Chat ke tool MCP lokal lewat GitDesktop sebagai hub.

> **Penting:** ini **bukan** sistem "100% lokal". AI tetap berjalan di cloud, dan prompt, potongan kode, diff, serta hasil tool dikirim ke DeepSeek. Yang lokal adalah penyimpanan, Git, dan eksekusi tool. Baca `docs/privasi.md`.

## Topologi

```
DeepSeek (LLM)
    |  internet
    v
Web MCP Bridge (fork ranggaas6)
    |  127.0.0.1
    v
GitDesktop MCP  <-- hub, satu-satunya entry di servers.json
    |
    +-- gitrs-mcp               (child, di Settings MCP GitDesktop)
    +-- mcp-filesystem-server   (child, di Settings MCP GitDesktop)
```

Bridge hanya melihat satu server: **GitDesktop MCP**. GitDesktop meneruskan tool dari server anak yang terdaftar di dalamnya. Server anak tidak ditulis ke `servers.json` bridge.

## Sumber bridge

Easy-Vibe memakai **fork Web MCP Bridge** milik proyek ini sebagai sumber utama:

> [ranggaas6/web-mcp-bridge](https://github.com/ranggaas6/web-mcp-bridge)

Fork ini adalah salinan dari [AstraxOf/web-mcp-bridge](https://github.com/AstraxOf/web-mcp-bridge) yang disesuaikan agar:

- Memakai nama ekstensi **Web MCP Bridge (Fork)** sehingga bisa dipasang berdampingan dengan upstream di browser yang sama.
- Memakai namespace storage, `sessionStorage`, penanda injeksi, dan Web Lock `wmbx_*` sehingga tidak bentrok dengan upstream di halaman yang sama.
- Memakai port kontrol `8199`, port launcher `8198`, dan port hub `8190` sehingga tidak berebut port dengan upstream (`8099`, `8098`, `8090`).

### Tabel isolasi

| Aspek | Upstream | Fork Easy-Vibe |
|---|---|---|
| Nama ekstensi | Web MCP Bridge | Web MCP Bridge (Fork) |
| `chrome.storage` | `wmb_*` | `wmbx_*` |
| `sessionStorage` | `wmb:*` | `wmbx:*` |
| Penanda DOM | `[WMB:…]` | `[WMBX:…]` |
| Web Lock | `wmb-alive` | `wmbx-alive` |
| Port kontrol | 8099 | 8199 |
| Port launcher | 8098 | 8198 |
| Port hub (gitdesktop) | 8090 | 8190 |

Jika Anda ingin memakai upstream alih-alih fork, jalankan installer dengan `--upstream`.

## Komponen

| Komponen | Peran | Dikonfigurasi di |
|---|---|---|
| DeepSeek Web Chat | Analisis, perencanaan, penulisan kode (AI cloud) | Browser |
| Web MCP Bridge (fork) | Tool signature ringkas, izin, validasi | `servers.json` bridge |
| GitDesktop MCP | Hub: teruskan tool anak + tool Git/forge sendiri | `servers.json` bridge |
| gitrs-mcp | Status, diff, branch, staging, commit | `.mcp.json` repo / Settings MCP |
| mcp-filesystem-server | Baca, tulis, modifikasi file | `.mcp.json` repo / Settings MCP |
| GitDesktop GUI | Review visual oleh manusia | Aplikasi desktop |

## Prasyarat

- Python 3.9+
- Go 1.21+ (untuk filesystem server)
- Git
- Chrome/Edge/Brave 116+

GitDesktop **tidak lagi** menjadi prasyarat manual: installer memasangnya otomatis dari rilis resmi. Lihat bagian **GitDesktop (dipasang otomatis)** di bawah.

## GitDesktop (dipasang otomatis)

GitDesktop adalah hub MCP, jadi wajib ada. Sejak versi ini `install.fish` **memasangnya sendiri** tanpa langkah manual, dengan cara:

1. Mengambil rilis terbaru dari GitHub API:
   `https://api.github.com/repos/theBGuy/GitDesktop/releases/latest`
2. Memilih aset **`GitDesktop_<versi>_amd64.AppImage`** (arsip macOS `.app.tar.gz`, `.deb`, dan `.rpm` sengaja tidak dipakai — lihat catatan di bawah).
3. Mengunduhnya ke `~/Applications/GitDesktop.AppImage`, lalu `chmod +x`.
4. Membuat symlink `~/.local/bin/gitdesktop-mcp` yang menunjuk ke AppImage tersebut. Ini menggantikan langkah GUI **Settings -> Use GitDesktop as an MCP server -> Add to PATH**.
5. Memverifikasi dengan `timeout 5 gitdesktop-mcp mcp </dev/null`. Perintah ini menguji **mode MCP**, bukan `--version`. Exit 0/1 (termasuk pesan `connection closed: initialize request`) berarti CLI MCP aktif; exit 124 berarti AppImage menggantung (GUI terbuka).

> **Kenapa bukan `--version`?** AppImage Tauri tidak menangani flag `--version` di mode CLI. Saat dipanggil via symlink, AppImage me-mount dirinya dan menjalankan GUI, sehingga perintah menggantung tanpa batas. Verifikasi mode MCP + `timeout` menghindari hal itu.

### Kenapa AppImage, bukan `.app.tar.gz` atau paket lain

- **`GitDesktop_<versi>_universal.app.tar.gz` bukan paket Linux.** Itu bundel *updater* Tauri untuk **macOS** (berisi direktori `GitDesktop.app`). Artefak updater Linux justru bernama `.AppImage.tar.gz`.
- **AUR (`gitdesktop-bin`) sudah usang.** Rilis terakhir di AUR tertahan di awal 2025, sedangkan rilis resmi jauh lebih baru.
- **Flatpak `io.github.thebguy.GitDesktop` tidak tersedia di Flathub.** Perintah `flatpak install` akan gagal.
- **`.deb` dan `.rpm` tidak native di Arch.** Keduanya butuh manajer paket distro lain.
- **AppImage adalah satu-satunya format Linux resmi yang portabel** dan bisa dipasang tanpa pacman, AUR, atau Flatpak.

### Jika verifikasi menggantung

Jika installer melaporkan `gitdesktop-mcp menggantung saat dipanggil mode MCP`, berarti AppImage membuka GUI saat dipanggil via symlink. Lakukan sekali:

1. Jalankan `~/Applications/GitDesktop.AppImage`.
2. Buka **Settings -> Use GitDesktop as an MCP server -> Add to PATH**.
3. Buka terminal baru, lalu uji: `timeout 5 gitdesktop-mcp mcp </dev/null; echo "exit: $status"`.

AppImage tetap sudah terpasang; hanya jalur MCP via symlink yang perlu dipastikan.

### Melewati pemasangan otomatis

Jika Anda sudah punya GitDesktop sendiri:

```fish
fish install.fish --skip-gitdesktop
```

## Instalasi CachyOS + fish

Target resmi saat ini: **CachyOS (Arch-based) dengan fish**.

Installer berada **di dalam repositori ini** sebagai `install.fish`. Karena itu Anda harus meng-clone repositori lebih dulu, lalu menjalankan installer dari dalam direktori hasil clone.

### 1. Clone repositori

```fish
git clone https://github.com/ranggaas6/Easy-Vibe
cd Easy-Vibe
```

Installer memeriksa bahwa direktori kerja adalah repositori Git. Bila dijalankan di luar direktori ini, installer gagal dengan pesan `Bukan repositori Git`.

### 2. Cek prasyarat (opsional)

```fish
fish scripts/check-prerequisites.fish
```

### 3. Jalankan installer

Dari dalam direktori repositori yang baru di-clone:

```fish
fish install.fish
```

Installer akan meng-clone **fork `ranggaas6/web-mcp-bridge`** secara default, dan memasang **GitDesktop** otomatis.

Dengan layanan systemd pengguna:

```fish
set -Ux EASY_VIBE_INSTALL_SERVICE 1
fish install.fish
```

Untuk memakai upstream `AstraxOf/web-mcp-bridge`:

```fish
fish install.fish --upstream
```

Opsi lain:

| Opsi | Efek |
|---|---|
| `--clean` | Jalankan `uninstall.fish --yes` dulu, lalu pasang ulang |
| `--force` | Timpa instalasi lama tanpa bertanya |
| `--upstream` | Pakai upstream (port `8099`/`8098`/`8090`) |
| `--skip-gitdesktop` | Lewati pemasangan otomatis GitDesktop |

Installer akan:

1. Memasang `git`, `python`, `python-pip`, `go`, `curl`, `base-devel` via pacman.
2. Memasang `gitrs-mcp` ke `~/.local/bin`.
3. Memasang `mcp-filesystem-server` ke `~/go/bin` dan menambahkannya ke fish PATH dengan `fish_add_path`.
4. **Memasang GitDesktop otomatis**: unduh AppImage x86_64 terbaru, pasang di `~/Applications/GitDesktop.AppImage`, buat symlink `~/.local/bin/gitdesktop-mcp`, lalu verifikasi mode MCP dengan `timeout`.
5. Meng-clone Web MCP Bridge dari fork (atau upstream bila `--upstream`) dan memasang dependensi Python di venv `~/.easy-vibe/venv` (menghindari blokir PEP 668).
6. Menulis `servers.json` dengan **satu entry: gitdesktop**, port `8199`/`8198`/`8190` (atau `8099`/`8098`/`8090` bila `--upstream`).
7. **Menulis `.mcp.json` di root repo** berisi `gitrs` dan `filesystem`. GitDesktop akan mendeteksinya otomatis saat repo dibuka (lihat `discover_mcp_servers` di source GitDesktop).
8. Menulis snippet referensi `~/.easy-vibe/gitdesktop-mcp-servers.json` (isi sama dengan `.mcp.json`).
9. Membuat launcher `~/.easy-vibe/start-easy-vibe.fish`.
10. Menulis manifest `~/.easy-vibe/manifest.txt` untuk uninstaller, termasuk entri `gitdesktop-appimage` dan `gitdesktop-mcp-link`.

### Daftarkan server anak di GitDesktop

Installer sudah menulis **`.mcp.json` di root repo**. GitDesktop membaca berkas itu lewat command internal `discover_mcp_servers` ketika repo dibuka, sehingga langkah yang tersisa hanya **satu klik**:

1. Buka repo `Easy-Vibe` di GitDesktop.
2. Buka **Settings -> MCP**.
3. Klik **Import** pada server `gitrs` dan `filesystem` yang sudah terdeteksi.
4. Aktifkan kedua server (hasil import default `enabled: false`).

Jika Anda ingin menambahkannya manual, isi `.mcp.json` adalah:

```json
{
  "mcpServers": {
    "gitrs": {
      "command": "gitrs-mcp",
      "args": ["--repo", "/path/ke/repo"]
    },
    "filesystem": {
      "command": "mcp-filesystem-server",
      "args": ["/path/ke/repo"]
    }
  }
}
```

Ganti `/path/ke/repo` dengan path repo Anda. Gunakan selalu garis miring `/`.

> **Catatan:** `.mcp.json` berisi path absolut pengguna, jadi sudah dimasukkan ke `.gitignore` dan **tidak boleh di-commit**.

> **Kenapa tidak 100% otomatis?** GitDesktop merancang import MCP sebagai *reviewed import*: nilai yang cocok dengan pola rahasia (`SECRET_KEY_RE`) dipindahkan ke keychain OS, dan setiap entri masuk dengan status `enabled: false`. Keduanya hanya bisa dilakukan dari dalam GUI GitDesktop, bukan dari skrip fish.

### Setelah instalasi

Dua langkah tetap manual karena dibatasi browser dan situs DeepSeek:

1. Muat folder `~/.easy-vibe/web-mcp-bridge` sebagai ekstensi unpacked di `chrome://extensions`.
2. Buka DeepSeek, klik **Inject instructions** di panel bridge.

Mulai bridge:

```fish
~/.easy-vibe/start-easy-vibe.fish
```

## Uninstalasi CachyOS + fish

Bersihkan sistem sebelum installer dijalankan ulang, atau hapus total.

### Hapus instalasi Easy-Vibe saja

Dari dalam direktori repositori hasil clone:

```fish
fish uninstall.fish
```

Uninstaller kini **membaca manifest** `~/.easy-vibe/manifest.txt` dan menghapus persis apa yang dicatat installer. Artinya, **GitDesktop ikut terhapus otomatis** bila Easy-Vibe yang memasangnya — tanpa flag tambahan.

Yang dilakukan secara default:

1. Menghapus artefak yang tercatat di manifest: `gitdesktop-appimage` (AppImage di `~/Applications`) dan `gitdesktop-mcp-link` (symlink di `~/.local/bin`).
2. Menghentikan dan menonaktifkan layanan systemd pengguna terkait Easy-Vibe.
3. Menghentikan proses `mcp_ws_bridge.py`, `gitdesktop-mcp`, `gitrs-mcp`, `mcp-filesystem-server`.
4. Menghapus direktori `~/.easy-vibe` (bridge, venv, launcher, snippet, manifest).
5. Menghapus entri `~/go/bin` dari `fish_user_paths`.

Tool (`gitrs-mcp`, `mcp-filesystem-server`) tetap **tidak** dihapus kecuali diminta dengan `--with-tools`.

> `.mcp.json` di root repo **tidak** dihapus otomatis karena berada di dalam repo pengguna. Hapus manual bila perlu, atau gunakan `git clean -f .mcp.json`.

### Opsi uninstaller

| Opsi | Efek |
|---|---|
| `--dry-run` | Tampilkan rencana tanpa mengubah apa pun |
| `--with-tools` | Hapus juga `gitrs-mcp` dan `mcp-filesystem-server` |
| `--with-gitdesktop` | Jalur warisan: hapus GitDesktop secara eksplisit (untuk instalasi lama yang manifest-nya belum mencatat GitDesktop) |
| `--full` | Setara `--with-tools --with-gitdesktop`, tanya sebelum hapus paket dasar pacman |
| `--yes` | Lewati konfirmasi |

Contoh bersih total dengan konfirmasi:

```fish
fish uninstall.fish --dry-run
fish uninstall.fish --full
```

### Instal ulang dari kondisi bersih

```fish
fish install.fish --clean
```

`--clean` memanggil `uninstall.fish --yes` dulu, lalu memasang ulang. Jika instalasi lama terdeteksi tanpa `--clean`, installer berhenti dan meminta konfirmasi.

### Troubleshooting fish

- Jika `gitrs-mcp` atau `mcp-filesystem-server` tidak ditemukan, jalankan `fish_add_path ~/.local/bin ~/go/bin` lalu buka terminal baru.
- Jika installer melaporkan `gitdesktop-mcp menggantung saat dipanggil mode MCP`, buka GitDesktop sekali dan jalankan **Settings -> Use GitDesktop as an MCP server -> Add to PATH**, lalu buka terminal baru dan uji `timeout 5 gitdesktop-mcp mcp </dev/null`.
- Jika server `gitrs`/`filesystem` tidak muncul di **Settings -> MCP** GitDesktop, pastikan repo yang dibuka di GitDesktop adalah root `Easy-Vibe` (tempat `.mcp.json` berada), lalu klik **Refresh** atau buka ulang dialog.
- Jika unduhan AppImage gagal (misalnya tidak ada koneksi ke GitHub API), pasang manual dari halaman rilis resmi, lalu jalankan `install.fish --skip-gitdesktop`.
- Jika `paru -S gitdesktop-bin` atau `flatpak install io.github.thebguy.GitDesktop` gagal, itu memang diharapkan. Kedua kanal tidak lagi sinkron dengan rilis resmi. Pakai AppImage dari halaman rilis.
- Jika pip mengeluh `externally-managed-environment`, installer sudah memakai venv sehingga masalah ini tidak muncul.
- Jika bridge gagal start, periksa `~/.easy-vibe/web-mcp-bridge/server/servers.json`.
- Jika tool tidak muncul di DeepSeek, pastikan GitDesktop berjalan dan mode MCP `gitdesktop-mcp` bisa dipanggil dari terminal.
- Jika installer menolak berjalan dengan pesan `Bukan repositori Git`, pastikan Anda menjalankannya dari dalam direktori hasil `git clone`.
- Jika installer menolak berjalan dengan pesan `pacman tidak ditemukan`, berarti sistem Anda bukan CachyOS/Arch; gunakan bagian instalasi manual.
- Jika uninstaller bilang direktori tidak ditemukan, berarti instalasi sudah bersih.

## Instalasi manual (platform lain)

Platform selain CachyOS + fish belum didukung installer resmi.

### 1. Pasang GitDesktop

Unduh aset yang cocok dari halaman rilis resmi:

> https://github.com/theBGuy/GitDesktop/releases/latest

- **Windows** — `GitDesktop_<versi>_x64-setup.exe` atau `.msi`.
- **macOS** — `GitDesktop_<versi>_universal.dmg`.
- **Linux x86_64** — `GitDesktop_<versi>_amd64.AppImage` (disarankan), atau `.deb` / `.rpm` bila distro Anda memakainya.

Jangan memakai `GitDesktop_<versi>_universal.app.tar.gz`: itu bundel *updater* macOS, bukan paket Linux.

Setelah aplikasi terpasang dan dibuka, jalankan **Settings -> Use GitDesktop as an MCP server -> Add to PATH**. Di Linux/macOS ini membuat symlink `~/.local/bin/gitdesktop-mcp`; di Windows ini menambahkan direktori launcher ke PATH pengguna. Verifikasi dari terminal baru dengan `timeout 5 gitdesktop-mcp mcp </dev/null; echo "exit: $status"` — nilai selain 124 berarti CLI MCP aktif.

GitDesktop **wajib** karena menjadi hub MCP. Jangan mengandalkan paket AUR `gitdesktop-bin` (usang) atau Flatpak `io.github.thebguy.GitDesktop` (tidak tersedia di Flathub).

### 2. gitrs-mcp dan mcp-filesystem-server

```bash
# gitrs-mcp (lihat halaman rilis untuk installer platform Anda)
brew install prasenjit-net/tap/gitrs-mcp

# mcp-filesystem-server
go install github.com/mark3labs/mcp-filesystem-server@latest
```

### 3. Web MCP Bridge (fork)

```bash
git clone https://github.com/ranggaas6/web-mcp-bridge
cd web-mcp-bridge
pip install -r server/requirements.txt
```

Muat folder proyek sebagai ekstensi unpacked di `chrome://extensions` (aktifkan Developer mode).

### 4. Konfigurasi bridge

Salin `config/bridge-servers.example.json` ke `web-mcp-bridge/server/servers.json`. File ini hanya berisi satu entry: `gitdesktop`, dengan port fork `8199`/`8198`/`8190`.

### 5. Daftarkan server anak di GitDesktop

Tulis `.mcp.json` di root repo (isi di atas), buka repo itu di GitDesktop, lalu **Settings -> MCP -> Import**. Atau tempel manual di dialog MCP.

### 6. Jalankan bridge

```bash
python server/mcp_ws_bridge.py --config server/servers.json
```

### 7. DeepSeek

Buka `https://chat.deepseek.com`, buka panel Web MCP Bridge, klik **Inject instructions**. Gunakan isi `prompts/system-prompt-id.md` bila perlu. Biarkan izin pada **Ask every time**.

## Alur kerja

1. AI membaca status dan file yang relevan lewat tool yang diteruskan GitDesktop.
2. AI mengubah file lewat filesystem.
3. Manusia menjalankan pengujian.
4. AI membaca diff.
5. Manusia menyetujui staging dan commit.

Detail: `docs/alur-kerja.md`.

## Keamanan

- Batasi filesystem ke direktori repo saja.
- Jangan pernah mengirim kredensial, API key, atau `.env` ke chat.
- Aktifkan `--allow-write` gitrs hanya saat diperlukan.
- Setujui manual setiap operasi destruktif.
- Commit atau backup sebelum pekerjaan besar.
- `.mcp.json` berisi path absolut dan sudah masuk `.gitignore`; jangan di-commit.

Checklist lengkap: `docs/keamanan.md`.

## Dokumentasi

- `docs/arsitektur.md` — topologi hub GitDesktop dan pembagian peran
- `docs/keamanan.md` — checklist dan model ancaman
- `docs/alur-kerja.md` — urutan kerja dan pola hemat payload
- `docs/privasi.md` — istilah yang akurat dan batas privasi
- `docs/risiko.md` — register risiko

## Lisensi

MIT
