# Alur Kerja

Urutan kerja antara AI dan manusia menggunakan `coding-mcp` dan `filesystem`.

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
| 8 | Manusia | Setujui push jika perlu | Manual |

Manusia memegang keputusan pada langkah 5 dan 8.

## Repo baru

`coding-mcp` memindai root saat `init`. Repo yang di-clone setelah itu tidak otomatis terdeteksi:

1. Panggil `refresh_project_index` dari DeepSeek.
2. Panggil `list_projects` untuk mendapatkan `project_id` baru.
3. Lanjutkan seperti biasa. Tidak perlu restart bridge.

## Pola hemat payload

```
list_projects
  -> git_status(project_id)
  -> git_diff(project_id, --stat)
  -> pilih berkas relevan
  -> read_file(project_id, path)
  -> write_file / apply_patch
  -> git_diff lagi
  -> git_add, git_commit
```

Jangan membaca seluruh repo bila tidak perlu.

## Aturan urutan tulis

1. Baca status dan diff terbaru.
2. Tulis berkas.
3. Baca diff hasil perubahan.
4. Manusia menguji.
5. Stage dan commit.

Hindari menulis lalu menjalankan `git_restore` tanpa membaca diff; perubahan bisa hilang.

## Penanganan kegagalan

- `coding-mcp` tidak menemukan repo: panggil `refresh_project_index`.
- `filesystem` gagal: cek direktori ada dan punya izin.
- Bridge tidak menyala: cek `~/.easy-vibe/native-host.log` dan manifest native host.
- Error berulang: hentikan dan laporkan.

## Batas konteks

Baca berkas bertahap. Gunakan `git_diff --stat` sebelum patch penuh. Perhatikan batas konteks model.
