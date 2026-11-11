# Keamanan

Checklist dan model ancaman untuk arsitektur vibe coding lokal Easy-Vibe dengan tiga jalur independen.

## Model ancaman singkat

| Aset | Ancaman | Dampak |
|---|---|---|
| Source code | Terkirim ke cloud | Kebocoran kode komersial atau rahasia |
| Kredensial, .env, API key | Terbaca tool lalu terkirim ke chat | Kompromi akun dan layanan |
| File di seluruh `$HOME` | `filesystem` dikonfigurasi ke `$HOME` | AI dapat membaca/mengubah file di luar proyek |
| Repositori lain di `$HOME` | `git` (multi-git) dapat diarahkan ke path mana pun | Operasi Git destruktif pada repo yang salah |
| File proyek | Prompt injection dari isi file | Penimpaan, penghapusan, perusakan kode |
| Direktori di luar repo | Batas direktori bukan sandbox | Akses melebihi yang dimaksud |

## Privasi

- [ ] Gunakan istilah yang akurat ("AI cloud dengan tool lokal"), bukan "100% lokal".
- [ ] Jangan kirim kredensial, API key, atau file `.env` ke chat.
- [ ] Pertimbangkan sensitivitas kode sebelum memakai DeepSeek Web.
- [ ] Sadari bahwa `filesystem` dan `git` dikonfigurasi ke `$HOME` secara default.
- [ ] Aktifkan opsi menolak penggunaan data untuk pelatihan model.

## Filesystem MCP

- [ ] Karena installer mengonfigurasi `filesystem` ke `$HOME`, pertimbangkan untuk membatasinya hanya ke direktori proyek jika Anda tidak membutuhkan akses lintas direktori.
- [ ] Gunakan mode persetujuan untuk setiap perubahan.
- [ ] Blokir penimpaan otomatis file konfigurasi sensitif (misal `.ssh/`, `.env`).
- [ ] Pertimbangkan isolasi dengan container atau sandbox OS.

## multi-git-mcp (Server Git Independen)

- [ ] Server `git` dapat melakukan operasi pada repo mana pun di `$HOME` jika AI memberikan argumen `repo_path` yang sesuai.
- [ ] Selalu periksa `repo_path` yang dikirim oleh AI sebelum menyetujui operasi destruktif.
- [ ] Batasi pemberian instruksi ke AI agar tidak menyentuh repositori yang tidak relevan.

## GitDesktop MCP

- [ ] Karena hanya berfungsi untuk repo yang sedang dibuka di GUI, risiko operasi ke repo lain lebih kecil.
- [ ] Tetap verifikasi operasi staging dan commit yang dilakukan melalui tool GitDesktop.

## Proses kerja

- [ ] Commit atau backup sebelum pekerjaan besar.
- [ ] Hindari tiga operasi tulis bersamaan pada repository yang sama.
- [ ] Verifikasi perilaku aktual Web MCP Bridge pada versi yang dipakai.
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

Proses MCP berjalan dengan hak akses sistem operasi yang meluncurkannya. Membatasi direktori di konfigurasi tidak mencegah proses mengakses path lain bila ada celah. Dengan `filesystem` dan `git` yang diarahkan ke `$HOME`, proses memiliki akses ke seluruh file pengguna. Untuk isolasi yang lebih kuat, jalankan server MCP di dalam container atau sandbox OS.

## Insiden

Bila mencurigai kebocoran atau perubahan tidak sah:

1. Hentikan bridge dan semua server MCP.
2. Periksa `git status` dan `git log` di repo utama DAN repo lain di `$HOME` untuk perubahan tak terduga.
3. Pulihkan dari commit terakhir yang diketahui baik.
4. Rotasi kredensial yang mungkin terbaca.
5. Tinjau riwayat chat dan hasil tool yang dikirim ke cloud.
