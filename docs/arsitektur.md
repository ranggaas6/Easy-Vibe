# Arsitektur

```
DeepSeek (cloud) -> Brave + Bridge (fork) -> Native host -> mcp_ws_bridge.py
    +-- coding-mcp (8190)  Git & berkas lokal
    +-- github     (8191)  GitHub API
    +-- filesystem (8192)  Berkas independen
```

## Prinsip

1. Tool lokal, AI cloud.
2. Tiga server independen: `coding-mcp` (Git + berkas lintas repo), `github` (GitHub API), `filesystem`.
3. Bridge hidup hanya selama tab DeepSeek terbuka; native host memegang on/off.
4. Manusia memegang commit dan operasi destruktif.
5. `servers.json` memakai path absolut; file disimpan chmod 600 karena entri `github` memuat token.

## Pemicu on/off

1. Tab DeepSeek dibuka -> service worker memuat `background/native_host.js`.
2. Kirim `{action:"start"}` ke native host `com.ranggaas6.easy_vibe`.
3. Host jalankan `start-easy-vibe.fish`, catat PID ke `bridge.pid`.
4. Tab terakhir ditutup -> `{action:"stop"}` -> bridge dan child server mati.
5. Brave ditutup -> stdin EOF -> host matikan bridge.

## Peran

| Komponen | Peran |
|---|---|
| DeepSeek | Analisis, kode |
| Bridge fork | Izin tool, validasi, pemicu |
| coding-mcp | Git & berkas lintas repo via project_id |
| github-mcp-server-kosta | GitHub API: PR, issue, branch, release, delete_branch |
| filesystem | Berkas di luar repo |
| Native host | On/off sesuai tab |
| Watcher | Deteksi repo baru via inotify |

## Konfigurasi

```json
{
  "control_port": 8199,
  "launcher_port": 8198,
  "servers": [
    { "name": "coding-mcp", "port": 8190, "command": ["/home/user/.npm-global/bin/coding-mcp", "serve", "--transport", "stdio"] },
    { "name": "github", "port": 8191, "command": ["/home/user/.npm-global/bin/github-mcp-server-kosta"], "env": { "GITHUB_TOKEN": "..." } },
    { "name": "filesystem", "port": 8192, "command": ["/home/user/go/bin/mcp-filesystem-server", "/home/user"] }
  ]
}
```

## Token GitHub

Token disimpan di `~/.easy-vibe/github-token` (chmod 600) dan diteruskan ke `servers.json` sebagai `env.GITHUB_TOKEN`. Token harus punya scope `repo` untuk operasi tulis seperti `delete_branch` dan pembuatan PR.

## Batasan

- Bergantung pada format respons model dan UI situs.
- Batas direktori tool bukan sandbox OS mutlak.
- `coding-mcp` memindai root saat init; repo baru perlu `refresh_project_index` atau watcher.
- Server `github` memerlukan koneksi internet; `coding-mcp` dan `filesystem` tetap lokal.
