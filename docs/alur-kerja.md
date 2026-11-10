# Alur Kerja

Urutan kerja yang disarankan antara AI dan manusia, serta pola hemat payload.

## Urutan kerja AI dan manusia

| Langkah | Pelaku | Aktivitas |
|---|---|---|
| 1 | DeepSeek | Membaca status repository |
| 2 | DeepSeek | Membaca file yang dibutuhkan |
| 3 | DeepSeek | Mengubah file melalui filesystem |
| 4 | Manusia | Menjalankan atau memeriksa hasil pengujian |
| 5 | DeepSeek | Membaca diff |
| 6 | Manusia | Menyetujui staging dan commit |

Manusia memegang keputusan pada langkah 4 dan 6. AI tidak melakukan commit tanpa persetujuan.

## Pola hemat payload (pembacaan bertahap)

```
git status
    |
git diff --stat
    |
Pilih file relevan
    |
Baca bagian yang diperlukan
    |
Lakukan perubahan
    |
git diff --stat
    |
Baca patch per file
    |
Review dan commit
```

Pola ini lebih efektif daripada meminta model membaca semua file dan seluruh riwayat Git pada setiap percakapan.

## Aturan urutan tulis

Gunakan urutan berikut agar dua jalur tulis tidak saling menimpa:

1. Baca status dan diff terbaru.
2. Tulis file melalui filesystem.
3. Baca diff hasil perubahan.
4. Jalankan pengujian.
5. Stage dan commit melalui gitrs.

Hindari urutan berikut:

1. Tulis file melalui filesystem.
2. Jalankan `restore` atau `reset` melalui gitrs tanpa membaca diff.

Pada urutan terakhir, perubahan yang baru dibuat dapat hilang.

## Mencegah konflik dua jalur tulis

- Jangan menjalankan operasi tulis filesystem dan gitrs secara bersamaan.
- Setelah operasi tulis selesai, baca diff sebelum operasi berikutnya.
- Gunakan satu sesi kerja per repository.
- Commit atau stash sebelum operasi Git yang mengubah working tree.

## Siklus kerja tipikal

### 1. Memulai tugas

```
git status
git diff --stat
```

Baca file yang relevan dengan tugas. Jangan membaca seluruh repository bila tidak perlu.

### 2. Mengubah kode

Tulis atau modifikasi file melalui filesystem MCP. Baca kembali file yang diubah untuk memastikan isinya benar.

### 3. Memverifikasi

Manusia menjalankan pengujian. AI tidak menganggap perubahan berhasil tanpa bukti pengujian.

### 4. Meninjau diff

```
git diff --stat
git diff -- <path>
```

Baca patch per file. Periksa apakah perubahan sesuai maksud.

### 5. Commit

Manusia menyetujui staging dan commit. Gunakan pesan commit yang menjelaskan maksud perubahan.

## Penanganan kegagalan tool

- Jika tool gagal, baca pesan error.
- Jangan mengulang panggilan yang sama tanpa perubahan.
- Jika error disebabkan path atau argumen, perbaiki argumen.
- Jika error disebabkan izin, minta manusia menyesuaikan konfigurasi.
- Jika error berulang, hentikan dan laporkan.

## Batas konteks

- Baca file secara bertahap. Gunakan `diff --stat` sebelum membaca patch penuh.
- Hindari mengirim seluruh isi file besar bila hanya sebagian yang relevan.
- Perhatikan batas konteks model. Lampiran utuh tetap dapat melebihi batas.
