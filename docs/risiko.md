# Register Risiko

Daftar risiko arsitektur vibe coding lokal Easy-Vibe beserta mitigasinya.

| Risiko | Sumber | Dampak | Mitigasi |
|---|---|---|---|
| Kebocoran kode ke cloud | DeepSeek Web | Data diproses di luar kendali | Pemilihan konteks, hindari data sensitif, istilah akurat |
| Prompt injection via isi file | filesystem dan coding-mcp | Timpa/hapus/rusak file | Mode persetujuan, batasi direktori, sandbox |
| Akses melebihi proyek | filesystem dan coding-mcp di $HOME | Kebocoran di luar repo | Pilih project_id spesifik, hati-hati saat instruksi ke AI |
| Operasi Git destruktif | git_add, git_commit, git_restore | Kehilangan perubahan | Review manual, commit rutin |
| Konflik dua jalur akses | coding-mcp dan filesystem | Perubahan tidak sinkron | Urutan kerja konsisten |
| Tool tumpang tindih | coding-mcp sudah mencakup Git dan berkas | Konteks membengkak | Gunakan coding-mcp untuk repo, filesystem hanya untuk berkas di luar repo |
| Ketergantungan format/UI | Web MCP Bridge | Alur putus bila UI berubah | Uji berkala, pantau versi |
| Lampiran panjang melebihi konteks | Bridge mengirim teks utuh | Panggilan gagal | Baca bertahap, batasi ukuran |
| Kredensial terbaca tool | Akses filesystem terlalu luas | Kompromi akun | Batasi direktori, blokir .env dan SSH |
| Pemicu native host gagal | allowed_origins salah | Bridge tidak menyala | Jalankan installer dengan --extension-id yang benar |

## Tingkat perhatian

| No | Temuan | Tingkat |
|---|---|---|
| 1 | Klaim 100% lokal tidak akurat | Tinggi |
| 2 | filesystem dan coding-mcp punya akses ke seluruh $HOME | Tinggi |
| 3 | Dua jalur akses ke repo yang sama berpotensi konflik | Sedang |
| 4 | Bridge bergantung pada format respons dan UI | Sedang |
| 5 | allowed_origins salah membuat pemicu gagal | Sedang |
| 6 | Klaim hemat token adalah klaim pengembang | Rendah-sedang |

## Prioritas penanganan

1. Perbaiki istilah privasi di seluruh dokumentasi.
2. Pahami implikasi akses $HOME; batasi jika tidak perlu.
3. Tetapkan urutan kerja tulis yang konsisten antara coding-mcp dan filesystem.
4. Verifikasi perilaku bridge dan native host pada versi yang dipakai.

## Catatan

Register ini bersifat hidup. Perbarui saat komponen berubah, ditemukan risiko baru, atau mitigasi diterapkan. Arsitektur dua jalur (coding-mcp dan filesystem) lebih sederhana dari versi tiga jalur sebelumnya, tetapi tetap menuntut kehati-hatian dalam memberikan instruksi ke AI.
