# Arsitektur

Topologi yang dipakai:

```
DeepSeek (LLM)
    |  internet
    v
Web MCP Bridge (fork ranggaas6)
    |  127.0.0.1
    v
+-- gitdesktop (port 8190)  <-- Hub untuk repo yang sedang dibuka (GUI & visual review)
+-- git (port 8191)         <-- Server Git independen (akses lintas repo di $HOME)
+-- filesystem (port 8192)  <-- Akses file independen (seluruh $HOME)
```

Bridge melihat tiga server independen di `servers.json`. Pembagian tiga jalur ini disengaja untuk mengadaptasi semua fitur Git milik GitHub, memungkinkan AI mengakses seluruh repositori di folder `$HOME`, dan mengakses repo lain sebagai referensi saat sedang membuka repo utama untuk koding.

## Sumber bridge

Easy-Vibe memakai **fork Web MCP Bridge** milik proyek ini sebagai sumber utama:

> [ranggaas6/web-mcp-bridge](https://github.com/ranggaas6/web-mcp-bridge)

Fork ini adalah salinan dari [AstraxOf/web-mcp-bridge](https://github.com/AstraxOf/web-mcp-bridge) yang disesuaikan agar bisa dipasang berdampingan dengan upstream di browser yang sama. Perbedaannya:

| Aspek | Upstream | Fork |
|---|---|---|
| Nama ekstensi | Web MCP Bridge | Web MCP Bridge (Fork) |
| `chrome.storage` | `wmb_*` | `wmbx_*` |
| `sessionStorage` | `wmb:*` | `wmbx:*` |
| Penanda DOM | `[WMB:…]` | `[WMBX:…]` |
| Web Lock | `wmb-alive` | `wmbx-alive` |
| Port kontrol | 8099 | 8199 |
| Port launcher | 8098 | 8198 |
| Port hub (gitdesktop) | 8090 | 8190 |
| `notices.json` | AstraxOf | ranggaas6 |

Installer memakai fork secara default. Untuk memakai upstream, jalankan `fish install.fish --upstream`.

## Prinsip dasar

1. Tool lokal, AI cloud.
2. Tiga titik masuk independen: bridge berbicara langsung ke GitDesktop, server Git (multi-git), dan server Filesystem.
3. Setiap server dikelola secara terpisah di `servers.json` tanpa saling bergantung.
4. Manusia memegang keputusan staging, commit, dan operasi destruktif.
5. Isolasi penuh terhadap upstream: nama, storage, penanda, Web Lock, dan port fork berbeda.

## Alur data

Ketika DeepSeek membaca kode melalui filesystem atau git, hasil pembacaan dikirim kembali ke halaman chat. Data yang dibaca tool keluar dari komputer.

## Pembagian peran

| Komponen | Peran | Dikonfigurasi di |
|---|---|---|
| DeepSeek Web Chat | Analisis, perencanaan, penulisan kode | Browser |
| Web MCP Bridge (fork) | Tool signature ringkas, izin, validasi | servers.json bridge |
| GitDesktop MCP | Hub: tool GitDesktop khusus repo aktif (visual) | servers.json bridge |
| multi-git-mcp | Status, diff, log, commit lintas repo via `repo_path` | servers.json bridge |
| mcp-filesystem-server | Baca, tulis, modifikasi file lintas direktori | servers.json bridge |
| GitDesktop GUI | Review visual oleh manusia | Aplikasi desktop |

## Konfigurasi bridge (fork)

```json
{
  "control_port": 8199,
  "launcher_port": 8198,
  "servers": [
    {
      "name": "gitdesktop",
      "port": 8190,
      "command": ["gitdesktop-mcp", "mcp", "--repo", "/path/ke/repo"]
    },
    {
      "name": "git",
      "port": 8191,
      "command": ["/home/user/.easy-vibe/run-multi-git.sh"]
    },
    {
      "name": "filesystem",
      "port": 8192,
      "command": ["mcp-filesystem-server", "/home/user"]
    }
  ]
}
```

Dengan `--upstream`, installer menulis `control_port: 8099`, `launcher_port: 8098`, dan port `gitdesktop` menjadi `8090`.

## Skrip Wrapper multi-git

Karena `multi-git-mcp.py` berbasis Python dan membutuhkan *virtual environment* spesifik, installer membuat skrip *wrapper* di `~/.easy-vibe/run-multi-git.sh`:

```bash
#!/bin/bash
exec "/home/user/.easy-vibe/venv/bin/python" -u "/path/absolut/Easy-Vibe/scripts/multi-git-mcp.py"
```

Installer menggunakan `realpath` untuk memastikan path skrip selalu absolut, sehingga bridge dapat menjalankannya dari *current working directory* (CWD) mana pun.

## Konfigurasi GitDesktop

Installer **membersihkan** daftar `mcpServers` di file `settings.json` GitDesktop. Ini dilakukan agar GitDesktop tidak mencoba menjalankan server anaknya sendiri (yang bisa menyebabkan duplikasi tool dengan entri `git` dan `filesystem` di bridge). GitDesktop murni berfungsi sebagai *hub* untuk repo yang sedang dibuka.

## Batasan

- Bridge bergantung pada format respons model dan struktur UI website.
- Klaim hemat token 50% adalah klaim pengembang, bukan benchmark independen.
- Batas direktori filesystem bukan sandbox OS mutlak.
- Fork memakai protokol MCP yang sama dengan upstream (`2025-03-26`), sehingga server MCP yang sama bisa dipakai oleh kedua bridge.
