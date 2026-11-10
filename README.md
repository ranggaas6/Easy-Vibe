# Easy-Vibe

Implementasi arsitektur **vibe coding lokal** yang menghubungkan DeepSeek Web Chat ke tool MCP di komputer sendiri: membaca Git, mengedit file, dan mengelola commit.

> **Penting:** ini **bukan** sistem "100% lokal". AI tetap berjalan di cloud, dan prompt, potongan kode, diff, serta hasil tool dikirim ke DeepSeek. Yang lokal adalah penyimpanan, Git, dan eksekusi tool. Baca `docs/privasi.md`.

## Komponen

| Komponen | Peran |
|---|---|
| DeepSeek Web Chat | Analisis, perencanaan, penulisan kode (AI cloud) |
| Web MCP Bridge | Menghubungkan chat ke MCP lokal lewat WebSocket |
| gitrs-mcp | Status, diff, branch, staging, commit |
| mcp-filesystem-server | Baca/tulis file di direktori repo |
| GitDesktop | GUI manusia untuk review perubahan |

## Instalasi CachyOS + fish

Target resmi saat ini: **CachyOS (Arch-based) dengan fish**.

### Jalankan installer

Dari terminal fish, di direktori repositori:

```fish
fish install.fish
```

Dengan layanan systemd pengguna:

```fish
set -Ux EASY_VIBE_INSTALL_SERVICE 1
fish install.fish
```

Installer akan:

1. Memasang `git`, `python`, `python-pip`, `go`, `curl`, `base-devel` via pacman.
2. Memasang `gitrs-mcp` ke `~/.local/bin`.
3. Memasang `mcp-filesystem-server` ke `~/go/bin` dan menambahkannya ke fish PATH dengan `fish_add_path`.
4. Meng-clone Web MCP Bridge dan memasang dependensi Python di venv `~/.easy-vibe/venv` (menghindari blokir PEP 668).
5. Menulis `servers.json` dengan path repo Anda.
6. Membuat launcher `~/.easy-vibe/start-easy-vibe.fish`.

### Setelah instalasi

Dua langkah tetap manual karena dibatasi browser dan situs DeepSeek:

1. Muat folder `~/.easy-vibe/web-mcp-bridge` sebagai ekstensi unpacked di `chrome://extensions`.
2. Buka DeepSeek, klik **Inject instructions** di panel bridge.

Mulai bridge:

```fish
~/.easy-vibe/start-easy-vibe.fish
```

### Troubleshooting fish

- Jika `gitrs-mcp` atau `mcp-filesystem-server` tidak ditemukan, jalankan `fish_add_path ~/.local/bin ~/go/bin` lalu buka terminal baru.
- Jika pip mengeluh `externally-managed-environment`, installer sudah memakai venv sehingga masalah ini tidak muncul.
- Jika bridge gagal start, periksa `~/.easy-vibe/web-mcp-bridge/server/servers.json`.

## Instalasi manual (platform lain)

Platform selain CachyOS + fish belum didukung installer resmi.

### 1. gitrs-mcp

```bash
brew install prasenjit-net/tap/gitrs-mcp
```

Windows/Linux: gunakan installer dari halaman release gitrs-mcp.

### 2. mcp-filesystem-server

```bash
go install github.com/mark3labs/mcp-filesystem-server@latest
```

### 3. Web MCP Bridge

```bash
git clone https://github.com/AstraxOf/web-mcp-bridge
cd web-mcp-bridge
pip install -r server/requirements.txt
```

Muat folder proyek sebagai ekstensi unpacked di `chrome://extensions` (aktifkan Developer mode).

### 4. Konfigurasi server

Salin `config/bridge-servers.example.json` ke `web-mcp-bridge/server/servers.json`, lalu ganti path contoh dengan path repo Anda. Gunakan selalu garis miring `/`.

### 5. Jalankan bridge

```bash
python server/mcp_ws_bridge.py --config server/servers.json
```

### 6. DeepSeek

Buka `https://chat.deepseek.com`, buka panel Web MCP Bridge, klik **Inject instructions**. Gunakan isi `prompts/system-prompt-id.md` bila perlu. Biarkan izin pada **Ask every time**.

## Alur kerja

1. AI membaca status dan file yang relevan.
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

Checklist lengkap: `docs/keamanan.md`.

## Dokumentasi

- `docs/arsitektur.md` — alur data dan pembagian peran
- `docs/keamanan.md` — checklist dan model ancaman
- `docs/alur-kerja.md` — urutan kerja dan pola hemat payload
- `docs/privasi.md` — istilah yang akurat dan batas privasi
- `docs/risiko.md` — register risiko

## Lisensi

MIT
