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
| PAT GitHub di keyring | Keyring sistem (Secret Service), memori proses server `github` dan wrapper | Kompromi akun GitHub bila sesi desktop terbuka dan proses lain membaca keyring, atau bila sisa berkas plaintext lama masih ada | Token tidak lagi disimpan sebagai berkas di `$HOME`; scope minimal, fine-grained PAT, rotasi token berkala, pastikan sisa `~/.git-credentials` dan `~/.easy-vibe/github-token` sudah terhapus |
| Operasi tulis remote lewat server github | Token scope `repo` | PR, merge, atau hapus branch yang tidak diinginkan | Persetujuan manual per panggilan, batasi PAT ke repo yang perlu |
| Push langsung ke main | `git_push` non-interaktif | Perubahan terdorong tanpa tinjauan | Review diff sebelum commit, setujui push secara manual, uji di branch (`set_upstream`) |
| Penghapusan folder salah sasaran | `coding_mcp.delete_file` dengan `path: "."` | Repo asli terhapus | Verifikasi `get_project`/`absolute_path`, hanya hapus salinan buatan sesi, daftarkan root agar salinan tidak perlu |
| Log audit memuat data sensitif | `~/.easy-vibe/audit/*.jsonl`, `brief.txt` | Kebocoran argumen panggilan | Direktori chmod 700, jangan dibagikan, rotasi otomatis 5 MB |
| Kegagalan penghapusan via filesystem | `filesystem.delete_file` (dilaporkan, penyebab belum diketahui) | Folder sisa | Gunakan `coding_mcp.delete_file`, konfirmasi dengan `get_file_info` |

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

Register ini bersifat hidup. Perbarui saat komponen berubah, ditemukan risiko baru, atau mitigasi diterapkan. Arsitektur saat ini memakai tiga server (coding-mcp, github, filesystem) dengan Opsi B sebagai alur default: berkas dan Git lokal lewat coding-mcp, remote lewat github. Tetap perlu kehati-hatian dalam memberikan instruksi ke AI.
