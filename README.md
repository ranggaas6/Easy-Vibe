# Easy-Vibe

Implementasi arsitektur **vibe coding lokal** yang menghubungkan DeepSeek Web Chat ke tool MCP lokal lewat GitDesktop sebagai hub.

> **Penting:** ini **bukan** sistem "100% lokal". AI tetap berjalan di cloud, dan prompt, potongan kode, diff, serta hasil tool dikirim ke DeepSeek. Yang lokal adalah penyimpanan, Git, dan eksekusi tool. Baca `docs/privasi.md`.

## Topologi

```
DeepSeek (LLM)
    |  internet
    v
Web MCP Bridge (WebSocket)
    |  127.0.0.1
    v
GitDesktop MCP  <-- hub, satu-satunya entry di servers.json
    |
    +-- gitrs-mcp               (child, di Settings MCP GitDesktop)
    +-- mcp-filesystem-server   (child, di Settings MCP GitDesktop)
```

Bridge hanya melihat satu server: **GitDesktop MCP**. GitDesktop meneruskan tool dari server anak yang terdaftar di dalamnya. Server anak tidak ditulis ke `servers.json` bridge.

## Komponen

| Komponen | Peran | Dikonfigurasi di |
|---|---|---|
| DeepSeek Web Chat | Analisis, perencanaan, penulisan kode (AI cloud) | Browser |
| Web MCP Bridge | Tool signature ringkas, izin, validasi | `servers.json` bridge |
| GitDesktop MCP | Hub: teruskan tool anak + tool Git/forge sendiri | `servers.json` bridge |
| gitrs-mcp | Status, diff, branch, staging, commit | Settings MCP GitDesktop |
| mcp-filesystem-server | Baca, tulis, modifikasi file | Settings MCP GitDesktop |
| GitDesktop GUI | Review visual oleh manusia | Aplikasi desktop |

## Prasyarat

- Python 3.9+
- Go 1.21+ (untuk filesystem server)
- Git
- GitDesktop (wajib, karena menjadi hub MCP)
- Chrome/Edge/Brave 116+

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
4. Memasang GitDesktop (paru/yay/flatpak, atau peringatan untuk pasang manual).
5. Meng-clone Web MCP Bridge dan memasang dependensi Python di venv `~/.easy-vibe/venv` (menghindari blokir PEP 668).
6. Menulis `servers.json` dengan **satu entry: gitdesktop**.
7. Menulis snippet `~/.easy-vibe/gitdesktop-mcp-servers.json` berisi `gitrs` dan `filesystem` untuk ditempel ke Settings MCP GitDesktop.
8. Membuat launcher `~/.easy-vibe/start-easy-vibe.fish`.
9. Menulis manifest `~/.easy-vibe/manifest.txt` untuk uninstaller.

### Daftarkan server anak di GitDesktop

Setelah installer selesai, buka **GitDesktop -> Settings -> MCP** dan tempel isi `~/.easy-vibe/gitdesktop-mcp-servers.json`:

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

```fish
fish uninstall.fish
```

Yang dilakukan:

1. Menghentikan dan menonaktifkan layanan systemd pengguna terkait Easy-Vibe.
2. Menghentikan proses `mcp_ws_bridge.py`, `gitdesktop-mcp`, `gitrs-mcp`, `mcp-filesystem-server`.
3. Menghapus direktori `~/.easy-vibe` (bridge, venv, launcher, snippet, manifest).
4. Menghapus entri `~/go/bin` dari `fish_user_paths`.

Tool (`gitrs-mcp`, `mcp-filesystem-server`) dan GitDesktop **tidak** dihapus secara default.

### Opsi uninstaller

| Opsi | Efek |
|---|---|
| `--dry-run` | Tampilkan rencana tanpa mengubah apa pun |
| `--with-tools` | Hapus juga `gitrs-mcp` dan `mcp-filesystem-server` |
| `--with-gitdesktop` | Hapus juga GitDesktop (pacman atau flatpak) |
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
- Jika pip mengeluh `externally-managed-environment`, installer sudah memakai venv sehingga masalah ini tidak muncul.
- Jika bridge gagal start, periksa `~/.easy-vibe/web-mcp-bridge/server/servers.json`.
- Jika tool tidak muncul di DeepSeek, pastikan GitDesktop berjalan dan `gitdesktop-mcp` bisa dipanggil dari terminal.
- Jika uninstaller bilang direktori tidak ditemukan, berarti instalasi sudah bersih.

## Instalasi manual (platform lain)

Platform selain CachyOS + fish belum didukung installer resmi.

### 1. Pasang GitDesktop

Unduh dari halaman rilis GitDesktop, atau via paket distro/Flatpak. GitDesktop **wajib** karena menjadi hub MCP.

### 2. gitrs-mcp dan mcp-filesystem-server

```bash
# gitrs-mcp (lihat halaman rilis untuk installer platform Anda)
brew install prasenjit-net/tap/gitrs-mcp

# mcp-filesystem-server
go install github.com/mark3labs/mcp-filesystem-server@latest
```

### 3. Web MCP Bridge

```bash
git clone https://github.com/AstraxOf/web-mcp-bridge
cd web-mcp-bridge
pip install -r server/requirements.txt
```

Muat folder proyek sebagai ekstensi unpacked di `chrome://extensions` (aktifkan Developer mode).

### 4. Konfigurasi bridge

Salin `config/bridge-servers.example.json` ke `web-mcp-bridge/server/servers.json`. File ini hanya berisi satu entry: `gitdesktop`.

### 5. Daftarkan server anak di GitDesktop

Buka **GitDesktop -> Settings -> MCP** dan tambahkan `gitrs` dan `filesystem` seperti contoh di atas.

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

Checklist lengkap: `docs/keamanan.md`.

## Dokumentasi

- `docs/arsitektur.md` — topologi hub GitDesktop dan pembagian peran
- `docs/keamanan.md` — checklist dan model ancaman
- `docs/alur-kerja.md` — urutan kerja dan pola hemat payload
- `docs/privasi.md` — istilah yang akurat dan batas privasi
- `docs/risiko.md` — register risiko

## Lisensi

MIT
