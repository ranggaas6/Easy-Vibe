# Alur Kerja

Urutan kerja yang disarankan antara AI dan manusia, serta pola hemat payload dengan arsitektur tiga jalur independen.

## Urutan kerja AI dan manusia

| Langkah | Pelaku | Aktivitas | Tool yang Digunakan |
|---|---|---|---|
| 1 | DeepSeek | Membaca status repository | `git` (lintas repo) atau `gitdesktop` (repo aktif) |
| 2 | DeepSeek | Membaca file yang dibutuhkan | `filesystem` |
| 3 | DeepSeek | Mengubah file | `filesystem` |
| 4 | Manusia | Menjalankan atau memeriksa hasil pengujian | Terminal / Browser |
| 5 | DeepSeek | Membaca diff | `git` atau `gitdesktop` |
| 6 | Manusia | Menyetujui staging dan commit | GUI GitDesktop atau instruksi ke AI |

Manusia memegang keputusan pada langkah 4 dan 6. AI tidak melakukan commit tanpa persetujuan eksplisit.

## Pola hemat payload (pembacaan bertahap)

```
git_status (sebutkan repo_path)
    |
git_diff --stat
    |
Pilih file relevan
    |
Baca bagian yang diperlukan via filesystem
    |
Lakukan perubahan via filesystem
    |
git_diff --stat
    |
Baca patch per file
    |
Review dan commit
```

Pola ini lebih efektif daripada meminta model membaca semua file dan seluruh riwayat Git pada setiap percakapan. Server `git` sangat berguna untuk memeriksa repositori referensi lain di folder `$HOME` tanpa harus membuka GUI GitDesktop untuk repo tersebut.

## Aturan urutan tulis

Gunakan urutan berikut agar tiga jalur tidak saling menimpa:

1. Baca status dan diff terbaru (via `git` atau `gitdesktop`).
2. Tulis file melalui `filesystem`.
3. Baca diff hasil perubahan.
4. Jalankan pengujian (manusia).
5. Stage dan commit (via GUI `gitdesktop` untuk repo utama, atau via tool `git` untuk repo lain).

Hindari urutan berikut:

1. Tulis file melalui `filesystem`.
2. Jalankan `restore` atau `reset` melalui tool `git` tanpa membaca diff.

Pada urutan terakhir, perubahan yang baru dibuat dapat hilang.

## Mencegah konflik antar jalur tulis

- Jangan menjalankan operasi tulis `filesystem` dan operasi Git yang mengubah working tree secara bersamaan pada repo yang sama.
- Setelah operasi tulis selesai, baca diff sebelum operasi berikutnya.
- Gunakan satu sesi kerja per repository untuk menghindari kebingungan konteks.
- Commit atau stash sebelum operasi Git yang mengubah working tree.

## Siklus kerja tipikal

### 1. Memulai tugas

```
git_status (repo_path: "/home/user/proyek-utama")
git_diff --stat
```

Baca file yang relevan dengan tugas via `filesystem`. Jangan membaca seluruh repository bila tidak perlu.

### 2. Mengubah kode

Tulis atau modifikasi file melalui `filesystem`. Baca kembali file yang diubah untuk memastikan isinya benar.

### 3. Memverifikasi

Manusia menjalankan pengujian. AI tidak menganggap perubahan berhasil tanpa bukti pengujian.

### 4. Meninjau diff

```
git_diff --stat
git_diff (dengan argumen file spesifik jika didukung)
```

Baca patch per file. Periksa apakah perubahan sesuai maksud.

### 5. Commit

Manusia menyetujui staging dan commit. Gunakan pesan commit yang menjelaskan maksud perubahan. Untuk repo yang sedang dibuka di GitDesktop, gunakan GUI-nya. Untuk repo referensi, gunakan tool `git_commit` via AI.

## Penanganan kegagalan tool

- Jika tool `git` (port 8191) gagal terhubung, periksa apakah `~/.easy-vibe/run-multi-git.sh` memiliki path absolut yang valid dan dapat dieksekusi.
- Jika tool `filesystem` gagal, periksa apakah direktori yang dituju ada dan memiliki izin baca/tulis.
- Jika tool `gitdesktop` gagal, pastikan GUI GitDesktop sedang berjalan.
- Jika error berulang, hentikan dan laporkan.

## Batas konteks

- Baca file secara bertahap. Gunakan `diff --stat` sebelum membaca patch penuh.
- Hindari mengirim seluruh isi file besar bila hanya sebagian yang relevan.
- Perhatikan batas konteks model. Lampiran utuh tetap dapat melebihi batas.
