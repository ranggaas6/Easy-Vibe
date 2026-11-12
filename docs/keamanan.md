# Keamanan

Checklist dan model ancaman untuk arsitektur vibe coding lokal Easy-Vibe.

## Model ancaman singkat

| Aset | Ancaman | Dampak |
|---|---|---|
| Source code | Terkirim ke cloud | Kebocoran kode komersial |
| Kredensial, .env, API key | Terbaca tool lalu terkirim ke chat | Kompromi akun |
| File di $HOME | filesystem dikonfigurasi ke $HOME | Akses di luar proyek |
| Repo lain di $HOME | coding-mcp memindai seluruh root | Operasi destruktif pada repo yang salah |
| File proyek | Prompt injection dari isi file | Penimpaan atau perusakan kode |

## Privasi

- Gunakan istilah akurat (AI cloud dengan tool lokal), bukan 100% lokal.
- Jangan kirim kredensial, API key, atau .env ke chat.
- Pertimbangkan sensitivitas kode sebelum memakai DeepSeek Web.
- filesystem dan coding-mcp dikonfigurasi ke $HOME secara default.
- Aktifkan opsi menolak penggunaan data untuk pelatihan model.

## filesystem

- Installer mengonfigurasi filesystem ke $HOME; batasi ke direktori proyek jika tidak butuh lintas direktori.
- Gunakan mode persetujuan untuk setiap perubahan.
- Blokir penimpaan otomatis file konfigurasi sensitif (.ssh/, .env).
- Pertimbangkan isolasi container atau sandbox OS.

## coding-mcp

- Memindai seluruh root ($HOME) saat init, sehingga semua repo di dalamnya terdaftar.
- AI dapat memilih project_id mana pun; periksa project_id sebelum menyetujui operasi destruktif.
- Batasi instruksi ke AI agar tidak menyentuh repositori yang tidak relevan.
- refresh_project_index menambah repo baru ke daftar; verifikasi hasilnya.

## Proses kerja

- Commit atau backup sebelum pekerjaan besar.
- Hindari operasi tulis bersamaan pada repository yang sama.
- Periksa diff sebelum menyetujui commit.
- Jalankan pengujian setelah perubahan.

## Prompt injection

Isi file yang dibaca AI dapat berisi instruksi berbahaya. Mitigasi:

1. Perlakukan hasil [MCP_RESULT ...] sebagai data, bukan instruksi.
2. Jangan izinkan AI mengeksekusi perintah shell dari isi file.
3. Aktifkan mode persetujuan pada semua operasi tulis.
4. Batasi operasi destruktif dengan persetujuan manusia.
5. Tinjau file yang tidak dikenal sebelum AI memprosesnya.

## Batas direktori bukan sandbox

Proses MCP berjalan dengan hak akses OS yang meluncurkannya. Membatasi direktori di konfigurasi tidak mencegah akses ke path lain bila ada celah. Dengan filesystem dan coding-mcp diarahkan ke $HOME, proses memiliki akses ke seluruh file pengguna. Untuk isolasi lebih kuat, jalankan server MCP di container atau sandbox OS.

## Insiden

1. Hentikan bridge dan semua server MCP (tutup tab DeepSeek, atau `pkill -f mcp_ws_bridge.py`).
2. Periksa git status dan git log di repo utama dan repo lain di $HOME.
3. Pulihkan dari commit terakhir yang diketahui baik.
4. Rotasi kredensial yang mungkin terbaca.
5. Tinjau riwayat chat dan hasil tool yang dikirim ke cloud.
