# Opsi B: alur kerja lokal sebagai default

Prinsip: semua perubahan berkas dan Git dikerjakan di disk lokal lewat `coding-mcp`. Server `github` hanya dipakai untuk hal yang ada di remote.

## Latar belakang

Jalur lama menulis file lewat `github_create_or_update_file`, sehingga isi file ikut dalam argumen `mcp_call` ke GitHub API. Pada satu kegagalan yang tercatat, payload sekitar 6,9 KB tidak berhasil. Dengan Opsi B isi file ditulis langsung ke disk oleh `coding-mcp` (`write_file`, `apply_patch`), lalu di-commit dan di-push lewat tool `git_*`.

Status bukti (lihat bagian hasil uji): penyebab pasti kegagalan lama **belum terbukti**. Pengujian menunjukkan `coding-mcp.write_file` menerima 30 KB lewat `mcp_call` tanpa terpotong, jadi batas parser sekitar 1,5 KB tidak berlaku umum. Kegagalan lama mungkin spesifik ke `github_create_or_update_file` atau kondisi sesi tertentu; tool itu belum diuji.

## Pembagian tugas server

| Server | Tugas utama | Jangan dipakai untuk |
|---|---|---|
| `coding-mcp` | Baca dan tulis berkas (`write_file`, `apply_patch`, `replace_in_file`, `create_file`), seluruh alur Git (`git_status`, `git_diff`, `git_add`, `git_commit`, `git_push`, `git_pull`, `git_checkout_new_branch`, `git_checkout_branch`, `git_log`, `git_show`), dan `delete_file` | Repo yang tidak terdaftar sebagai proyek; merge, rebase, force push (tool-nya tidak ada) |
| `filesystem` | Operasi baca dan bantu: `list_directory`, `read_file`, `get_file_info`, `search_files`, `copy_file` | Menghapus folder (dilaporkan gagal); menjalankan Git |
| `github` | PR, issue, label, review, merge, release, membaca repo yang belum di-clone, `github_compare`, `github_delete_branch`, verifikasi isi branch | `github_create_or_update_file` untuk file besar (belum terbukti aman) |

## Prasyarat Git: push tanpa prompt

`git push` dari `coding-mcp` berjalan sebagai subprocess tanpa TTY. Installer menyiapkan:

- `git config --global credential.helper store` dan `credential.username`.
- Entri `https://<username>:<PAT>@github.com` di `~/.git-credentials` (chmod 600).
- Pada repo bridge: `credential.helper store` dan `credential.username` di level repo.
- Remote berupa HTTPS polos (tanpa token di URL).

Koreksi atas catatan lama yang menyebut Git belum punya akses: pada pemeriksaan terakhir, `~/.gitconfig` berisi `helper = store` dan `username = ranggaas6`, dan `.git/config` repo Easy-Vibe memakai remote `https://github.com/ranggaas6/Easy-Vibe` (polos). Push `coding_mcp.git_push` terbukti berhasil pada uji di bawah. Isi `~/.git-credentials` sengaja tidak dibuka.

Tanpa helper, error yang muncul: `fatal: could not read Username for 'https://github.com': No such device or address`.

## Alur kerja

1. **Cek lokasi repo.** `coding-mcp` hanya mendeteksi proyek satu level di bawah root (home). Jika repo belum terdaftar (misalnya `~/.easy-vibe/web-mcp-bridge`), salin dengan `filesystem.copy_file` ke `~/nama-sementara`, panggil `refresh_project_index`, lalu catat `project_id` dari `list_projects`. Alternatif: daftarkan folder itu sebagai root di konfigurasi `coding-mcp` (lihat saran di bawah).
2. **Edit** dengan `write_file` atau `apply_patch`.
3. **Verifikasi** dengan `git_status` dan `git_diff`.
4. **Commit dan push** dengan `git_add`, `git_commit`, `git_push`. Untuk branch baru gunakan `set_upstream: true`.
5. **Verifikasi di remote** dengan `github_list_contents` atau `github_get_file_content`.
6. **Bersihkan**: hapus branch uji dengan `github_delete_branch`, dan folder salinan dengan `coding_mcp.delete_file`.

## Aturan menghapus folder

- Hapus folder salinan buatan sesi hanya dengan `coding_mcp.delete_file` (`recursive: true`, `confirm: true`). Jangan memakai `filesystem.delete_file`.
- Untuk menghapus root proyek, `path` harus `"."`. Sebelumnya verifikasi `project_id` dengan `get_project` dan pastikan `absolute_path` memang folder salinan, bukan repo asli.
- Jangan pernah menghapus proyek yang bukan salinan buatan sesi ini.
- Setelah menghapus, konfirmasi dengan `filesystem.get_file_info`; hasil yang diharapkan: `no such file or directory`.

## Hasil uji yang dilaporkan

Catatan ini berasal dari sesi sebelumnya dan belum diverifikasi ulang pada sesi dokumentasi ini.

**Uji 1: commit dan push `base_adapter.js`.** `git_status` hanya menunjukkan satu file modified, `git_diff` 5 baris ditambah dan 2 dihapus. Commit `3445634`, push `8703f29..3445634 main -> main` tanpa prompt kredensial.

**Uji 2: file 30 KB.** `coding_mcp.write_file` menulis 30.150 byte (450 baris) lewat `mcp_call` tanpa terpotong. Commit `79bf1d9` di branch `test/payload-30k`, push berhasil dengan `set_upstream`. GitHub menampilkan ukuran 30.150 byte (sama dengan lokal). `github_delete_branch` berhasil, folder salinan terhapus dan terkonfirmasi.

## Temuan dan batasan

- `run_command_safe` menolak `git` pada uji; gunakan tool `git_*` bawaan. Perhatikan bahwa `servers.json` yang ditulis installer memuat `git` di `ALLOWED_COMMANDS`; hubungan kedua hal ini belum diverifikasi.
- `filesystem.delete_file` dilaporkan gagal empat kali dengan `recursive: true` (dua sesi); penyebab belum diketahui. `coding_mcp.delete_file` berhasil di kedua sesi.
- Penyebab payload terpotong belum terbukti (lihat latar belakang).
- Isi file di remote hanya dicocokkan ukurannya, bukan byte per byte.
- `github_list_branches` dilaporkan hanya menampilkan 5 dari 10 branch pada uji, jadi hilangnya branch uji tidak terkonfirmasi lewat daftar itu; perintah hapusnya sendiri berhasil.
- Opsi B hanya untuk repo yang ada di disk. Jika target belum di-clone, clone dulu (installer melakukannya untuk bridge) atau baca lewat server `github`.
- Pada pemeriksaan dokumentasi ini, `~/.easy-vibe/web-mcp-bridge` tidak muncul di `list_projects` walau installer menjalankan `coding-mcp init` untuknya. Penyebab belum diverifikasi.

## Saran lanjutan

Daftarkan `~/.easy-vibe` atau `~/.easy-vibe/web-mcp-bridge` sebagai root di konfigurasi `coding-mcp` (`~/.coding-mcp`). Langkah salin dan hapus tidak lagi diperlukan, dan risiko menghapus dengan `path: "."` hilang. Setelah mengubah konfigurasi, verifikasi dengan `list_projects`.
