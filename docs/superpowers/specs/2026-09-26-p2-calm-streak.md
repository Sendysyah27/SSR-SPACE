# P2: Calm streak tanpa nuansa judi

## Problem

Konsistensi mencatat membantu, tetapi streak ala game (api, angka
beruntun, takut putus) menciptakan tekanan dan rasa bersalah yang
bertentangan dengan nada tenang produk.

## Pola Ollo

Ollo menghindari angka beruntun. Sebagai gantinya ada penanda lembut
berbasis minggu (contoh: "3 minggu terakhir tercatat") tanpa penalti
visual saat minggu kosong.

## Adaptasi SSR

Kartu kecil di Beranda: dot per minggu dalam 8 minggu terakhir, terisi
bila ada minimal satu transaksi di minggu itu. Tidak ada angka streak,
tidak ada api, tidak ada pesan "jangan putus". Copy netral: minggu
kosong ditampilkan sebagai dot redup biasa, bukan peringatan. Data dari
transaksi lokal yang sudah dimuat, tanpa query tambahan.

## Data dan prefs

Tanpa migration. Tidak ada prefs baru. Hitungan fungsi murni dari list
tanggal transaksi (minggu Senin sampai Minggu, ikut locale tanggal app).

## Edge cases

Workspace baru tanpa histori: tampilkan ajakan catat, bukan deret dot
kosong. Zona waktu: batas minggu dihitung dari waktu device. Transaksi
masa depan (jam custom): tidak dihitung. Ganti workspace: hitung ulang
dari data workspace aktif.

## Daftar test

Minggu terisi dan kosong dari tanggal buatan. Batas Senin dan Minggu.
Transaksi future diabaikan. List kosong menampilkan ajakan, bukan dot.

## Dampak Supabase dan RLS

Tanpa migration. Tidak ada tulis baru, baca memakai data transaksi yang
sudah lewat RLS yang ada.
