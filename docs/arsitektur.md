# Arsitektur

```
DeepSeek (cloud) -> Brave + Bridge (fork) -> Native host -> start-easy-vibe.fish -> mcp_ws_bridge.py
    +-- coding-mcp (8190)  Git & berkas lokal
    +-- github     (8191)  GitHub API
    +-- filesystem (8192)  Berkas independen

(opsional) tiap server dibungkus mcp-audit -> ~/.easy-vibe/audit/<server>.jsonl
           audit-brief.py -> refs/wip/autosave + ~/.easy-vibe/brief.txt
```

## Prinsip

1. Tool lokal, AI cloud.
2. Tiga server independen: `coding-mcp` (Git + berkas lintas repo), `github` (GitHub API), `filesystem`.
3. Opsi B sebagai default: perubahan berkas dan Git lewat `coding-mcp` di disk lokal; `github` hanya untuk hal yang ada di remote. Lihat [opsi-b.md](opsi-b.md).
4. Bridge hidup hanya selama tab DeepSeek terbuka; native host memegang on/off.
5. Manusia memegang commit dan operasi destruktif.
6. `servers.json` memakai path absolut; file disimpan chmod 600 (token GitHub tidak ada di berkas ini, diambil dari keyring lewat wrapper).

## Pemicu on/off

1. Tab DeepSeek dibuka -> service worker (`background/index.js`) memuat `background/native_host.js`.
2. Kirim `{action:"start"}` ke native host `com.ranggaas6.easy_vibe`.
3. Host menjalankan `coding-mcp init <root>` (rescan), lalu `fish ~/.easy-vibe/start-easy-vibe.fish`, mencatat PID ke `bridge.pid`, lalu menyalakan watcher (`watcher.pid`).
4. Launcher menjalankan `audit-brief.py` (bila ada) lalu `server/mcp_ws_bridge.py --config server/servers.json`.
5. Tab terakhir ditutup -> `{action:"stop"}` -> watcher, bridge, dan child server dimatikan.
6. Brave ditutup -> stdin EOF -> host mematikan bridge.

Aksi lain yang dikenali host: `status` dan `rescan`.

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
| mcp-audit (opsional) | Merekam panggilan tool ke JSONL |
| audit-brief.py (opsional) | Snapshot wip dan brief.txt |

## Konfigurasi

Contoh `servers.json` yang ditulis installer (tanpa mcp-audit):

```json
{
  "control_port": 8199,
  "launcher_port": 8198,
  "servers": [
    { "name": "coding-mcp", "port": 8190, "command": ["/home/user/.npm-global/bin/coding-mcp", "serve", "--transport", "stdio"], "env": { "ALLOWED_COMMANDS": "cargo,rustc,git,pgrep,node,npm,pacman,busctl,fish,diff,python3,llvm,llvm-mc" } },
    { "name": "github", "port": 8191, "command": ["/home/user/.easy-vibe/bin/github-mcp-wrapper"] },
    { "name": "filesystem", "port": 8192, "command": ["/home/user/go/bin/mcp-filesystem-server", "/home/user"] }
  ]
}
```

Jika `mcp-audit` terpasang, `command` setiap server menjadi `<mcp-audit> run --log ~/.easy-vibe/audit/<nama>.jsonl --server-name <nama> --quiet -- <binary asli>`. Port bridge: kontrol 8199, launcher 8198.

## Kredensial

| Lokasi | Dipakai oleh | Mekanisme |
|---|---|---|
| Keyring sistem (service `easy-vibe`, account `github`) | Server `github` | Wrapper `~/.easy-vibe/bin/github-mcp-wrapper` mengambil token dari keyring saat start; `servers.json` tanpa token |
| Keyring sistem (lewat libsecret) | Git CLI (termasuk `git_push` dari coding-mcp) | `credential.helper` global `git-credential-libsecret`, kredensial `github.com` |

Token harus punya scope `repo` untuk operasi tulis seperti push, `delete_branch`, dan pembuatan PR. Clone awal bridge memakai token di URL satu kali; setelahnya remote dikembalikan ke HTTPS polos.

## Batasan

- Bergantung pada format respons model dan UI situs.
- Batas direktori tool bukan sandbox OS mutlak.
- `coding-mcp` memindai root saat init dan hanya mendeteksi proyek satu level di bawah root; repo baru perlu `refresh_project_index` atau watcher.
- Server `github` memerlukan koneksi internet; `coding-mcp` dan `filesystem` tetap lokal.
- PAT tersimpan di keyring sistem (Secret Service) dan membutuhkan sesi dengan keyring aktif; tidak ada berkas token plaintext di `$HOME`.
