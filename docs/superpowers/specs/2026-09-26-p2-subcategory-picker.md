# P2: Subkategori plus color dan icon picker

## Problem

Satu lapis kategori terlalu kasar (contoh: Makanan tercampur antara
masak dan jajan) dan daftar kategori panjang sulit dipindai cepat tanpa
penanda visual.

## Pola Ollo

Ollo memakai dua lapis (kategori dan subkategori opsional) plus satu
warna dan satu ikon per kategori dari palet terbatas yang sudah
dikurasi, bukan color wheel bebas.

## Adaptasi SSR

Subkategori sebagai string opsional per transaksi (contoh: Makanan >
Jajan), dikelola di `CategoriesScreen` yang sudah ada. Tiap kategori
mendapat warna dari palet 8 warna dan ikon dari `AppIcons` yang sudah
ada, dipilih lewat picker kecil di layar yang sama. Laporan dan budget
tetap grup di lapis kategori agar angka tidak berubah.

## Data dan prefs

Tanpa migration bila subkategori disimpan sebagai bagian dari nilai
kategori (format `Kategori > Sub`), karena kolom `category` sudah teks
bebas. Peta warna dan ikon per kategori disimpan di prefs
`app_category_meta` (JSON kecil). Bila format gabungan terbukti rapuh
saat implementasi, opsi kolom baru dibahas ulang dengan migration
sendiri, bukan di spec ini.

## Edge cases

Kategori lama tanpa meta: warna dan ikon default netral. Subkategori
dengan pemisah di namanya ditolak saat input. Hapus kategori induk
menawarkan pindah ke Lainnya, tidak menghapus histori. Budget dan Top-N
mengabaikan lapis sub agar konsisten.

## Daftar test

Parse dan format nilai gabungan dua lapis. Tolak nama berisi pemisah.
Meta hilang memakai default. Grup laporan tidak berubah oleh subkategori.

## Dampak Supabase dan RLS

Tanpa migration pada desain ini. Tidak ada tabel atau policy baru.
Kolom `category` yang dipakai tetap dalam RLS transaksi yang sudah ada.
