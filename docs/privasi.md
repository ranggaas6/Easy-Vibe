# Privasi

Dokumen ini meluruskan klaim privasi pada arsitektur vibe coding lokal Easy-Vibe.

## Masalah utama

Arsitektur ini **tidak bisa disebut 100% privat atau 100% lokal**. Data dikirim ke DeepSeek melalui internet.

Alur yang sebenarnya:

```
                 INTERNET
                     |
           DeepSeek Web Chat
                     |
             Prompt + kode
             + hasil MCP
                     |
                     v
             Web MCP Bridge
                     |
              Komputer lokal
                     |
       File, Git lokal, dan tool coding-mcp
```

Ketika DeepSeek membaca kode melalui `filesystem`, atau memeriksa riwayat Git melalui `coding-mcp`, hasil pembacaan dikirim kembali ke halaman chat dan menjadi bagian percakapan.

## Yang memang benar

- Repository tidak pernah diunggah sebagai ZIP.
- Tidak menggunakan GitHub API untuk operasi harian.
- Tidak menggunakan API berbayar.
- Git dan branch tetap berada di SSD internal.

## Yang tetap dapat keluar dari komputer

- Potongan kode (dibaca via `filesystem` atau `read_file` di coding-mcp)
- Diff, log, dan status Git (dibaca via `coding-mcp`)
- Nama file dan struktur direktori
- Konfigurasi
- Hasil tool yang diberikan kepada DeepSeek

## Kebijakan privasi DeepSeek

Kebijakan privasi DeepSeek yang berlaku menyebutkan bahwa prompt, input, file unggahan, dan riwayat chat dapat dikumpulkan; pemrosesan dan penyimpanan dapat dilakukan di luar yurisdiksi pengguna; data dapat digunakan untuk pengembangan layanan; dan tersedia pilihan untuk menolak penggunaan data bagi pelatihan model. Pilihan menolak pelatihan **tidak** membuat pemrosesan menjadi lokal.

## Istilah yang disarankan

| Klaim awal | Istilah yang lebih tepat |
|---|---|
| 100% lokal | Penyimpanan dan operasi Git lokal |
| Tidak ada data keluar | Tidak mengunggah seluruh repository secara otomatis |
| Privasi 100% | Mengurangi eksposur data melalui pemilihan konteks |
| AI sepenuhnya lokal | AI berbasis cloud dengan tool lokal |

## Implikasi praktis

1. Tentukan klasifikasi sensitivitas proyek.
2. Jangan pernah mengirim kredensial, API key, atau `.env`.
3. Pilih konteks yang dikirim ke model secara sadar (batasi `filesystem` dan root `coding-mcp` jika tidak ingin seluruh `$HOME` terbaca).
4. Aktifkan opsi menolak penggunaan data untuk pelatihan bila tersedia.
5. Untuk proyek sangat sensitif, pertimbangkan model lokal penuh, bukan arsitektur ini.
