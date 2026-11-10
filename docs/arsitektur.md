# Arsitektur

Topologi yang dipakai:

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

Bridge hanya melihat satu server, yaitu GitDesktop MCP. GitDesktop menjadi hub yang meneruskan tool dari server anak. Server anak tidak ditulis ke `servers.json` bridge.

## Prinsip dasar

1. Tool lokal, AI cloud.
2. Satu titik masuk: bridge hanya bicara ke GitDesktop MCP.
3. Server anak dikelola di Settings MCP GitDesktop.
4. Manusia memegang keputusan staging, commit, dan operasi destruktif.

## Alur data

Ketika DeepSeek membaca kode melalui filesystem yang diteruskan GitDesktop, hasil pembacaan dikirim kembali ke halaman chat. Data yang dibaca tool keluar dari komputer.

## Pembagian peran

| Komponen | Peran | Dikonfigurasi di |
|---|---|---|
| DeepSeek Web Chat | Analisis, perencanaan, penulisan kode | Browser |
| Web MCP Bridge | Tool signature ringkas, izin, validasi | servers.json bridge |
| GitDesktop MCP | Hub: teruskan tool anak + tool Git/forge sendiri | servers.json bridge |
| gitrs-mcp | Status, diff, branch, staging, commit | Settings MCP GitDesktop |
| mcp-filesystem-server | Baca, tulis, modifikasi file | Settings MCP GitDesktop |
| GitDesktop GUI | Review visual oleh manusia | Aplikasi desktop |

## Konfigurasi bridge

```json
{
  "control_port": 8099,
  "servers": [
    {
      "name": "gitdesktop",
      "port": 8090,
      "command": ["gitdesktop-mcp"]
    }
  ]
}
```

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
