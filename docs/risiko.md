# Register Risiko

Daftar risiko arsitektur vibe coding lokal Easy-Vibe beserta mitigasinya.

| Risiko | Sumber | Dampak | Mitigasi |
|---|---|---|---|
| Kebocoran kode atau konfigurasi ke cloud | Alur DeepSeek Web | Data dikumpulkan dan diproses di luar kendali pengguna | Pemilihan konteks, hindari data sensitif, istilah yang akurat |
| Prompt injection via isi file | `filesystem` dan `git` dengan akses luas | Timpa, hapus, atau rusak file | Mode persetujuan, batasi direktori jika tidak perlu, sandbox |
| Akses direktori melebihi batas proyek | `filesystem` dan `git` dikonfigurasi ke `$HOME` | Kebocoran data di luar repo yang sedang dikerjakan | Gunakan `repo_path` spesifik, hati-hati saat memberikan instruksi ke AI |
| Operasi Git destruktif | tool `git_commit`, `git_diff`, dll. | Kehilangan perubahan atau kebingungan status | Review manual, commit rutin, hindari perintah destruktif tanpa pengawasan |
| Konflik tiga jalur akses | `gitdesktop`, `git`, dan `filesystem` | Perubahan tidak sinkron | Urutan kerja konsisten (baca status sebelum menulis, review diff sebelum commit) |
| Tool tumpang tindih | Banyak MCP aktif (122 dari GitDesktop, 4 dari git, 14 dari filesystem) | Konteks membengkak, model bingung | Pilih tool yang paling tepat; matikan server yang tidak dipakai jika memungkinkan |
| Ketergantungan format atau UI | Web MCP Bridge | Alur putus bila UI atau format berubah | Uji berkala, pantau versi |
| Klaim hemat token dibesar-besarkan | README proyek | Ekspektasi keliru | Ukur sendiri |
| Lampiran panjang melebihi konteks | Bridge mengirim teks utuh | Panggilan gagal atau terpotong | Baca bertahap, batasi ukuran |
| Kredensial terbaca tool | Akses `filesystem` terlalu luas | Kompromi akun | Batasi direktori, blokir akses ke `.env` atau kredensial SSH |

## Tingkat perhatian

| No | Temuan | Tingkat perhatian |
|---|---|---|
| 1 | Klaim 100% lokal tidak akurat | Tinggi |
| 2 | `filesystem` dan `git` memiliki akses ke seluruh `$HOME` | Tinggi |
| 3 | Tiga jalur akses ke repository yang sama berpotensi konflik | Sedang-tinggi |
| 4 | Fungsi MCP tumpang tindih (GitDesktop vs git) | Sedang |
| 5 | Bridge bergantung pada format respons dan UI | Sedang |
| 6 | Klaim hemat token sekitar 50% adalah klaim pengembang | Rendah-sedang |

## Prioritas penanganan

1. Perbaiki istilah privasi di seluruh dokumentasi dan komunikasi.
2. Pahami implikasi keamanan dari memberikan akses `$HOME` ke `filesystem` dan `git`; batasi jika tidak diperlukan.
3. Tetapkan urutan kerja tulis yang konsisten antara `filesystem`, `git`, dan `gitdesktop`.
4. Verifikasi perilaku bridge pada versi yang dipakai.

## Catatan

Register ini bersifat hidup. Perbarui saat komponen berubah versi, saat ditemukan risiko baru, atau saat mitigasi diterapkan. Arsitektur tiga jalur (GitDesktop, Git lintas repo, dan Filesystem) memberikan fleksibilitas maksimal, namun menuntut kehati-hatian ekstra dalam memberikan instruksi kepada AI agar tidak menyentuh file atau repositori yang salah.
