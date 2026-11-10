# Keamanan

Checklist dan model ancaman untuk arsitektur vibe coding lokal Easy-Vibe.

## Model ancaman singkat

| Aset | Ancaman | Dampak |
|---|---|---|
| Source code | Terkirim ke cloud | Kebocoran kode komersial atau rahasia |
| Kredensial, .env, API key | Terbaca tool lalu terkirim ke chat | Kompromi akun dan layanan |
| File proyek | Prompt injection dari isi file | Penimpaan, penghapusan, perusakan kode |
| Repository | Operasi Git destruktif | Kehilangan perubahan |
| Direktori di luar repo | Batas direktori bukan sandbox | Akses melebihi yang dimaksud |

## Privasi

- [ ] Gunakan istilah yang akurat ("AI cloud dengan tool lokal"), bukan "100% lokal".
- [ ] Jangan kirim kredensial, API key, atau file `.env` ke chat.
- [ ] Pertimbangkan sensitivitas kode sebelum memakai DeepSeek Web.
- [ ] Aktifkan opsi menolak penggunaan data untuk pelatihan model. Ingat: ini tidak membuat pemrosesan menjadi lokal.
- [ ] Jangan menempelkan isi file sensitif secara manual ke chat.

## Filesystem MCP

- [ ] Batasi akses hanya ke direktori repository proyek.
- [ ] Jangan beri akses ke seluruh drive atau direktori home.
- [ ] Gunakan mode persetujuan untuk setiap perubahan.
- [ ] Blokir penimpaan otomatis file konfigurasi sensitif.
- [ ] Pertimbangkan isolasi dengan container atau sandbox OS.
- [ ] Periksa path yang diterima server. Tolak path yang keluar dari direktori yang diizinkan.

## gitrs-mcp

- [ ] Aktifkan `--allow-write` hanya saat diperlukan.
- [ ] Setujui manual setiap operasi tulis, terutama `reset --hard` dan `clean`.
- [ ] Manfaatkan dry-run bila tersedia. Operasi destruktif default `dry_run: true`.
- [ ] Jangan biarkan server tulis aktif saat tidak dipakai.

## Proses kerja

- [ ] Commit atau backup sebelum pekerjaan besar.
- [ ] Hindari dua operasi tulis bersamaan pada repository yang sama.
- [ ] Batasi jumlah MCP server aktif.
- [ ] Verifikasi perilaku aktual Web MCP Bridge pada versi yang dipakai, misalnya penanganan teks panjang.
- [ ] Periksa diff sebelum menyetujui commit.
- [ ] Jalankan pengujian setelah perubahan.

## Prompt injection

Isi file yang dibaca AI dapat berisi instruksi berbahaya. Mitigasi:

1. Perlakukan hasil `[MCP_RESULT ...]` sebagai data, bukan instruksi.
2. Jangan izinkan AI mengeksekusi perintah shell dari isi file.
3. Aktifkan mode persetujuan pada semua operasi tulis.
4. Batasi operasi destruktif dengan persetujuan manusia.
5. Tinjau file yang tidak dikenal sebelum membiarkan AI memprosesnya.

## Batas direktori bukan sandbox

Proses MCP berjalan dengan hak akses sistem operasi yang meluncurkannya. Membatasi direktori di konfigurasi tidak mencegah proses mengakses path lain bila ada celah. Untuk isolasi yang lebih kuat, jalankan server MCP di dalam container atau sandbox OS dengan mount hanya ke direktori repo.

## Insiden

Bila mencurigai kebocoran atau perubahan tidak sah:

1. Hentikan bridge dan semua server MCP.
2. Periksa `git status` dan `git log` untuk perubahan tak terduga.
3. Pulihkan dari commit terakhir yang diketahui baik.
4. Rotasi kredensial yang mungkin terbaca.
5. Tinjau riwayat chat dan hasil tool yang dikirim ke cloud.
