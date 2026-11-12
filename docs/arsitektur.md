# Arsitektur

```
DeepSeek (cloud) -> Brave + Bridge (fork) -> Native host -> mcp_ws_bridge.py
    +-- coding-mcp (8190)
    +-- filesystem (8192)
```

## Prinsip

1. Tool lokal, AI cloud.
2. Dua server independen: `coding-mcp` (Git + berkas lintas repo) dan `filesystem`.
3. Bridge hidup hanya selama tab DeepSeek terbuka; native host memegang on/off.
4. Manusia memegang commit dan operasi destruktif.
5. `servers.json` memakai path absolut hasil `command -v`.

## Pemicu on/off

1. Tab DeepSeek dibuka -> service worker memuat `background/native_host.js`.
2. Kirim `{action:"start"}` ke native host `com.ranggaas6.easy_vibe`.
3. Host jalankan `start-easy-vibe.fish`, catat PID ke `bridge.pid`.
4. Tab terakhir ditutup -> `{action:"stop"}` -> bridge dan child server mati.
5. Brave ditutup -> stdin EOF -> host matikan bridge.

Native host dan manifest dipasang `install.fish`; `allowed_origins` berisi ID extension dari `--extension-id`.

## Peran

| Komponen | Peran |
|---|---|
| DeepSeek | Analisis, kode |
| Bridge fork | Izin tool, validasi, pemicu |
| coding-mcp | Git & berkas lintas repo via project_id; `refresh_project_index` |
| filesystem | Berkas di luar repo |
| Native host | On/off sesuai tab |

## Konfigurasi

```json
{
  "control_port": 8199,
  "launcher_port": 8198,
  "servers": [
    { "name": "coding-mcp", "port": 8190, "command": ["/home/user/.npm-global/bin/coding-mcp", "serve", "--transport", "stdio"] },
    { "name": "filesystem", "port": 8192, "command": ["/home/user/go/bin/mcp-filesystem-server", "/home/user"] }
  ]
}
```

## Batasan

- Bergantung pada format respons model dan UI situs.
- Batas direktori tool bukan sandbox OS mutlak.
- `coding-mcp` memindai root saat init; repo baru perlu `refresh_project_index`.
