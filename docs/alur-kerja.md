# Alur Kerja

Urutan kerja antara AI dan manusia menggunakan `coding-mcp`, `filesystem`, dan `github`, mengikuti [Opsi B](opsi-b.md): berkas dan Git dikerjakan lokal lewat `coding-mcp`; `github` hanya untuk hal yang ada di remote.

## Urutan kerja

| Langkah | Pelaku | Aktivitas | Tool |
|---|---|---|---|
| 1 | DeepSeek | Lihat repo yang tersedia | `coding-mcp` -> `list_projects` |
| 2 | DeepSeek | Pilih `project_id`, baca status/diff | `git_status`, `git_diff` |
| 3 | DeepSeek | Baca berkas relevan | `read_file` (coding-mcp) atau filesystem |
| 4 | DeepSeek | Ubah berkas | `write_file` / `apply_patch` |
| 5 | Manusia | Jalankan pengujian | Terminal / browser |
| 6 | DeepSeek | Baca diff lagi | `git_diff` |
| 7 | DeepSeek | Stage dan commit | `git_add`, `git_commit` |
| 8 | Manusia | Setujui push | Manual |
| 9 | DeepSeek | Push (non-interaktif) | `git_push` (cabang baru: `set_upstream: true`) |
| 10 | DeepSeek | Verifikasi di remote | `github_list_contents`, `github_get_file_content` |
| 11 | DeepSeek | PR, issue, release, hapus branch uji | server `github` |

Manusia memegang keputusan pada langkah 5 dan 8. Push berhasil tanpa prompt kredensial karena installer menyimpan token di keyring dan menyiapkan `git-credential-libsecret` sebagai `credential.helper`.

## Repo baru atau belum terdaftar

`coding-mcp` memindai root saat `init` dan hanya mendeteksi proyek satu level di bawah root. Watcher menambahkan repo baru selama bridge hidup. Jika repo tetap tidak muncul:

1. Panggil `refresh_project_index` dari DeepSeek.
2. Panggil `list_projects` untuk mendapatkan `project_id`.
3. Jika repo berada lebih dalam dari satu level (misalnya `~/.easy-vibe/web-mcp-bridge`), salin dengan `filesystem.copy_file` ke `~/nama-sementara`, refresh, dan gunakan `project_id` salinan. Hapus salinan sesudahnya dengan `coding_mcp.delete_file` (aturan lengkap di [opsi-b.md](opsi-b.md)).

Tidak perlu restart bridge.

## Pola hemat payload

```
list_projects
  -> git_status(project_id)
  -> git_diff(project_id)
  -> pilih berkas relevan
  -> read_file(project_id, path)
  -> write_file / apply_patch
  -> git_diff lagi
  -> git_add, git_commit
```

Jangan membaca seluruh repo bila tidak perlu. Untuk berkas besar, tulis lewat `coding-mcp` (uji 30 KB lewat `write_file` berhasil), bukan lewat `github_create_or_update_file`.

## Aturan urutan tulis

1. Baca status dan diff terbaru.
2. Tulis berkas.
3. Baca diff hasil perubahan.
4. Manusia menguji.
5. Stage dan commit.

Hindari menulis lalu menjalankan `git_restore` tanpa membaca diff; perubahan bisa hilang. Jika `audit-brief` aktif, snapshot otomatis tersedia di `refs/wip/autosave`.

## Melanjutkan sesi yang terputus

Jika `audit-brief` aktif, baca `~/.easy-vibe/brief.txt`: berisi 10 panggilan terakhir, peringatan bila panggilan terakhir belum punya hasil, dan status Git proyek terkait. Lalu jalankan `git_status` dan `git_diff` pada proyek itu sebelum melanjutkan.

## Penanganan kegagalan

- `coding-mcp` tidak menemukan repo: panggil `refresh_project_index`.
- `git_push` meminta username: periksa `git config --global --get-all credential.helper` (harus memuat `git-credential-libsecret`) dan pastikan Secret Service (keyring) aktif.
- `run_command_safe` menolak `git`: gunakan tool `git_*`.
- `filesystem` gagal: cek direktori ada dan punya izin. Jangan memakai `filesystem.delete_file` untuk folder.
- Bridge tidak menyala: cek `~/.easy-vibe/native-host.log` dan manifest native host.
- Error berulang: hentikan dan laporkan.

## Batas konteks

Baca berkas bertahap. Gunakan `git_diff` sebelum patch penuh dan perhatikan batas konteks model.
