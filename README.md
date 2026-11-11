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
    +-- gitrs-mcp               (child, otomatis terdaftar)
    +-- mcp-filesystem-server   (child, otomatis terdaftar)
```

Bridge hanya melihat satu server: **GitDesktop MCP**. GitDesktop meneruskan tool dari server anak yang terdaftar di dalamnya. Server anak tidak ditulis ke `servers.json` bridge.

## Sumber bridge

Easy-Vibe memakai **fork Web MCP Bridge** milik proyek ini sebagai sumber utama:

> [ranggaas6/web-mcp-bridge](https://github.com/ranggaas6/web-mcp-bridge)

Fork ini adalah salinan dari [AstraxOf/web-mcp-bridge](https://github.com/AstraxOf/web-mcp-bridge) yang disesuaikan agar:

- Memakai nama ekstensi **Web MCP Bridge (Fork)** sehingga bisa dipasang berdampingan dengan upstream di browser yang sama.
- Memakai namespace storage, `sessionStorage`, penanda injeksi, dan Web Lock `wmbx_*` sehingga tidak bentrok dengan upstream.
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
| gitrs-mcp | Status, diff, branch, staging, commit | Otomatis via skrip Python |
| mcp-filesystem-server | Baca, tulis, modifikasi file | Otomatis via skrip Python |
| GitDesktop GUI | Review visual oleh manusia | Aplikasi desktop |

## Prasyarat

- Python 3.9+
- Go 1.21+ (untuk filesystem server)
- Git
- Chrome/Edge/Brave 116+

GitDesktop **tidak lagi** menjadi prasyarat manual: installer memasangnya otomatis dari rilis resmi.

## GitDesktop (dipasang otomatis)

GitDesktop adalah hub MCP, jadi wajib ada. `install.fish` **memasangnya sendiri** tanpa langkah manual:

1. Mengambil rilis terbaru dari GitHub API.
2. Memilih aset **`GitDesktop_<versi>_amd64.AppImage`** (arsip macOS `.app.tar.gz`, `.deb`, dan `.rpm` sengaja tidak dipakai).
3. Mengunduhnya ke `~/Applications/GitDesktop.AppImage`, lalu `chmod +x`.
4. Membuat symlink `~/.local/bin/gitdesktop-mcp` ke AppImage. Ini menggantikan langkah GUI **Settings -> Use GitDesktop as an MCP server -> Add to PATH**.
5. Memverifikasi dengan `timeout 5 gitdesktop-mcp mcp </dev/null`. Exit 0/1 berarti CLI MCP aktif; exit 124 berarti AppImage menggantung.

> **Kenapa bukan `--version`?** AppImage Tauri tidak menangani flag `--version` di mode CLI. Saat dipanggil via symlink, AppImage me-mount dirinya dan menjalankan GUI, sehingga perintah menggantung tanpa batas.

### Kenapa AppImage, bukan `.app.tar.gz` atau paket lain

- **`GitDesktop_<versi>_universal.app.tar.gz` bukan paket Linux.** Itu bundel *updater* Tauri untuk **macOS**.
- **AUR (`gitdesktop-bin`) sudah usang.** Rilis terakhir di AUR tertahan di awal 2025.
- **Flatpak `io.github.thebguy.GitDesktop` tidak tersedia di Flathub.**
- **`.deb` dan `.rpm` tidak native di Arch.**
- **AppImage adalah satu-satunya format Linux resmi yang portabel.**

## Instalasi CachyOS + fish

Target resmi saat ini: **CachyOS (Arch-based) dengan fish**.

### 1. Clone repositori

```fish
git clone https://github.com/ranggaas6/Easy-Vibe
cd Easy-Vibe
```

Installer memeriksa bahwa direktori kerja adalah repositori Git. Bila dijalankan di luar direktori ini, installer gagal.

### 2. Cek prasyarat (opsional)

```fish
fish scripts/check-prerequisites.fish
```

### 3. Jalankan installer

```fish
fish install.fish
```

Installer akan meng-clone fork `ranggaas6/web-mcp-bridge` dan memasang GitDesktop otomatis.

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

1. Memasang paket dasar via pacman.
2. Memasang `gitrs-mcp` dan `mcp-filesystem-server`.
3. **Memasang GitDesktop otomatis** (AppImage + symlink).
4. Meng-clone Web MCP Bridge dan memasang dependensi Python di venv.
5. Menulis `servers.json` dengan satu entry: `gitdesktop`.
6. **Menyuntikkan konfigurasi MCP secara otomatis** ke database internal GitDesktop menggunakan skrip Python.
7. Membuat skrip **wrapper** (`launch-gitdesktop.fish`) dan ikon menu aplikasi (`.desktop`).
8. Menulis manifest untuk uninstaller.

### Otomatisasi Konfigurasi MCP (Tanpa Klik)

Installer sudah menyuntikkan server `gitrs` dan `filesystem` secara langsung ke file konfigurasi GitDesktop (`~/.local/share/com.thebguy.gitdesktop/settings.json`) via skrip Python.

**Anda tidak perlu membuka menu Settings atau melakukan Import manual.** Saat GitDesktop dibuka, server sudah dalam keadaan aktif.

### Siklus Hidup Bridge (Otomatis)

Ikon menu GitDesktop yang dibuat oleh installer sebenarnya adalah sebuah *wrapper*. Cara kerjanya:

1. Saat Anda mengklik ikon GitDesktop, *wrapper* membuka GUI GitDesktop.
2. *Wrapper* menunggu hingga port `8190` aktif.
3. *Wrapper* menyalakan Web MCP Bridge di latar belakang.
4. Saat Anda **menutup** GUI GitDesktop, *wrapper* otomatis mematikan bridge.

Anda tidak perlu menjalankan terminal untuk menyalakan bridge lagi.

### Setelah instalasi

Dua langkah tetap manual karena dibatasi browser dan situs DeepSeek:

1. Muat folder `~/.easy-vibe/web-mcp-bridge` sebagai ekstensi unpacked di `chrome://extensions`.
2. Buka DeepSeek, klik **Inject instructions** di panel bridge.

## Uninstalasi CachyOS + fish

Bersihkan sistem atau hapus total.

### Hapus instalasi Easy-Vibe saja

Dari dalam direktori repositori hasil clone:

```fish
fish uninstall.fish
```

Uninstaller **membaca manifest** `~/.easy-vibe/manifest.txt` dan menghapus persis apa yang dicatat installer (termasuk AppImage GitDesktop, ikon menu, dan wrapper).

Yang dilakukan secara default:

1. Menghapus artefak dari manifest (AppImage, symlink, `.desktop`, wrapper).
2. Menghentikan proses `mcp_ws_bridge.py`, `gitdesktop-mcp`, dll.
3. Menghapus direktori `~/.easy-vibe`.
4. Menghapus entri dari `fish_user_paths`.

Tool (`gitrs-mcp`, `mcp-filesystem-server`) dan paket pacman **tidak** dihapus kecuali diminta.

### Opsi uninstaller

| Opsi | Efek |
|---|---|
| `--dry-run` | Tampilkan rencana tanpa mengubah apa pun |
| `--with-tools` | Hapus juga `gitrs-mcp` dan `mcp-filesystem-server` |
| `--with-gitdesktop` | Jalur warisan: hapus GitDesktop secara eksplisit |
| `--full` | Setara `--with-tools --with-gitdesktop`, tanya sebelum hapus paket dasar pacman |
| `--yes` | Lewati konfirmasi |

Contoh bersih total:

```fish
fish uninstall.fish --dry-run
fish uninstall.fish --full
```

### Instal ulang dari kondisi bersih

```fish
fish install.fish --clean
```

`--clean` memanggil `uninstall.fish --yes` dulu, lalu memasang ulang.

### Troubleshooting fish

- Jika `gitrs-mcp` atau `mcp-filesystem-server` tidak ditemukan, jalankan `fish_add_path ~/.local/bin ~/go/bin` lalu buka terminal baru.
- Jika ikon menu tidak muncul, jalankan `update-desktop-database ~/.local/share/applications`.
- Jika bridge macet atau CPU naik, pastikan tidak ada proses `gitdesktop-mcp` yang berjalan ganda di latar belakang dengan `pgrep -af mcp_ws_bridge`.
- Jika installer menolak berjalan dengan pesan `Bukan repositori Git`, pastikan Anda menjalankannya dari dalam direktori hasil `git clone`.
- Jika uninstaller bilang direktori tidak ditemukan, berarti instalasi sudah bersih.

## Instalasi manual (platform lain)

Platform selain CachyOS + fish belum didukung installer resmi.

### 1. Pasang GitDesktop

Unduh aset dari halaman rilis resmi:

> https://github.com/theBGuy/GitDesktop/releases/latest

- **Windows** — `GitDesktop_<versi>_x64-setup.exe` atau `.msi`.
- **macOS** — `GitDesktop_<versi>_universal.dmg`.
- **Linux x86_64** — `GitDesktop_<versi>_amd64.AppImage` (disarankan).

Setelah aplikasi terpasang dan dibuka, jalankan **Settings -> Use GitDesktop as an MCP server -> Add to PATH**. Verifikasi dari terminal baru dengan `timeout 5 gitdesktop-mcp mcp </dev/null; echo "exit: $status"`.

### 2. gitrs-mcp dan mcp-filesystem-server

```bash
brew install prasenjit-net/tap/gitrs-mcp
go install github.com/mark3labs/mcp-filesystem-server@latest
```

### 3. Web MCP Bridge (fork)

```bash
git clone https://github.com/ranggaas6/web-mcp-bridge
cd web-mcp-bridge
pip install -r server/requirements.txt
```

Muat folder proyek sebagai ekstensi unpacked di `chrome://extensions`.

### 4. Konfigurasi bridge

Salin `config/bridge-servers.example.json` ke `web-mcp-bridge/server/servers.json`.

### 5. Jalankan bridge

```bash
python server/mcp_ws_bridge.py --config server/servers.json
```

### 6. DeepSeek

Buka `https://chat.deepseek.com`, buka panel Web MCP Bridge, klik **Inject instructions**.

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

Checklist lengkap: `docs/keamanan.md`.

## Dokumentasi

- `docs/arsitektur.md` — topologi hub GitDesktop dan pembagian peran
- `docs/keamanan.md` — checklist dan model ancaman
- `docs/alur-kerja.md` — urutan kerja dan pola hemat payload
- `docs/privasi.md` — istilah yang akurat dan batas privasi
- `docs/risiko.md` — register risiko

## Lisensi

MIT
