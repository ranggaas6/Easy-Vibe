# Register Risiko

Daftar risiko arsitektur vibe coding lokal Easy-Vibe beserta mitigasinya.

| Risiko | Sumber | Dampak | Mitigasi |
|---|---|---|---|
| Kebocoran kode atau konfigurasi ke cloud | Alur DeepSeek Web | Data dikumpulkan dan diproses di luar kendali pengguna | Pemilihan konteks, hindari data sensitif, istilah yang akurat |
| Prompt injection via isi file | mcp-filesystem + akses tulis | Timpa, hapus, atau rusak file | Mode persetujuan, batas direktori, sandbox |
| Batas direktori bukan sandbox | Hak akses OS proses MCP | Akses melebihi yang dimaksud | Container atau sandbox OS |
| Operasi Git destruktif | gitrs-mcp --allow-write | Kehilangan perubahan | Persetujuan manual, dry-run, commit atau backup |
| Konflik dua jalur tulis | gitrs-mcp dan filesystem | Perubahan hilang | Urutan kerja konsisten |
| Tool tumpang tindih | Banyak MCP aktif | Konteks membengkak, model bingung | Kurangi server aktif; GitDesktop hanya GUI |
| Ketergantungan format atau UI | Web MCP Bridge | Alur putus bila UI atau format berubah | Uji berkala, pantau versi |
| Klaim hemat token dibesar-besarkan | README proyek | Ekspektasi keliru | Ukur sendiri |
| Lampiran panjang melebihi konteks | Bridge mengirim teks utuh | Panggilan gagal atau terpotong | Baca bertahap, batasi ukuran |
| Kredensial terbaca tool | Akses filesystem terlalu luas | Kompromi akun | Batasi direktori, blokir .env, rotasi kredensial |

## Tingkat perhatian

| No | Temuan | Tingkat perhatian |
|---|---|---|
| 1 | Klaim 100% lokal tidak akurat | Tinggi |
| 2 | mcp-filesystem-server adalah komponen berisiko terbesar | Tinggi |
| 3 | gitrs-mcp --allow-write mencakup operasi destruktif | Sedang-tinggi |
| 4 | Fungsi MCP tumpang tindih | Sedang |
| 5 | Dua jalur tulis ke repository yang sama | Sedang |
| 6 | Bridge bergantung pada format respons dan UI | Sedang |
| 7 | Klaim hemat token sekitar 50% adalah klaim pengembang | Rendah-sedang |

## Prioritas penanganan

1. Perbaiki istilah privasi di seluruh dokumentasi dan komunikasi.
2. Batasi akses filesystem ke direktori repo dan aktifkan persetujuan.
3. Kendalikan gitrs-mcp --allow-write dengan persetujuan manual dan dry-run.
4. Tetapkan urutan kerja tulis yang konsisten.
5. Kurangi jumlah server MCP aktif.
6. Verifikasi perilaku bridge pada versi yang dipakai.

## Catatan

Register ini bersifat hidup. Perbarui saat komponen berubah versi, saat ditemukan risiko baru, atau saat mitigasi diterapkan. Dokumentasi proyek open-source dapat berubah, jadi verifikasi ulang README dan kebijakan terbaru sebelum mengandalkannya.
