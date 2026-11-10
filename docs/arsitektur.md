# Arsitektur

Topologi yang dipakai:

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

Bridge hanya melihat satu server, yaitu GitDesktop MCP. GitDesktop menjadi hub yang meneruskan tool dari server anak. Server anak tidak ditulis ke `servers.json` bridge.

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
2. Satu titik masuk: bridge hanya bicara ke GitDesktop MCP.
3. Server anak dikelola di Settings MCP GitDesktop.
4. Manusia memegang keputusan staging, commit, dan operasi destruktif.
5. Isolasi penuh terhadap upstream: nama, storage, penanda, Web Lock, dan port fork berbeda.

## Alur data

Ketika DeepSeek membaca kode melalui filesystem yang diteruskan GitDesktop, hasil pembacaan dikirim kembali ke halaman chat. Data yang dibaca tool keluar dari komputer.

## Pembagian peran

| Komponen | Peran | Dikonfigurasi di |
|---|---|---|
| DeepSeek Web Chat | Analisis, perencanaan, penulisan kode | Browser |
| Web MCP Bridge (fork) | Tool signature ringkas, izin, validasi | servers.json bridge |
| GitDesktop MCP | Hub: teruskan tool anak + tool Git/forge sendiri | servers.json bridge |
| gitrs-mcp | Status, diff, branch, staging, commit | Settings MCP GitDesktop |
| mcp-filesystem-server | Baca, tulis, modifikasi file | Settings MCP GitDesktop |
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
      "command": ["gitdesktop-mcp"]
    }
  ]
}
```

Dengan `--upstream`, installer menulis `control_port: 8099`, `launcher_port: 8098`, dan `port: 8090`.

## Konfigurasi GitDesktop (Settings MCP)

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

## Dua jalur tulis tetap berlaku

Meski lewat satu hub, dua jalur tulis masih ada:

```
GitDesktop MCP
  +-- gitrs-mcp   (reset, restore, stage, commit, branch)
  +-- filesystem  (write, modify, move, delete file)
```

Urutan kerja di `alur-kerja.md` wajib dipakai agar keduanya tidak saling menimpa.

## Batasan

- Bridge bergantung pada format respons model dan struktur UI website.
- Klaim hemat token 50% adalah klaim pengembang, bukan benchmark independen.
- Batas direktori filesystem bukan sandbox OS mutlak.
- GitDesktop MCP menambah satu lapisan. Jika GitDesktop tidak berjalan atau gitdesktop-mcp gagal start, seluruh rantai tool ikut gagal meski gitrs-mcp dan filesystem sehat.
- Fork memakai protokol MCP yang sama dengan upstream (`2025-03-26`), sehingga server MCP yang sama bisa dipakai oleh kedua bridge.
