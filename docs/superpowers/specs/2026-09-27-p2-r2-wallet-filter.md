# P2-R2: Filter statistik per dompet

## Problem

Laporan SSR selalu menghitung semua dompet sekaligus. Pengguna yang
ingin tahu "bulan ini jajan dari DANA habis berapa" harus menebak dari
rekap global, padahal datanya sudah ada per baris.

## Pola Ollo

Ollo 1.6.0 punya Filter Statistics by wallet: grafik dan rincian kategori
mengikuti dompet yang dipilih. Referensi alur saja, tanpa salin kode.

## Adaptasi SSR

State session-only `selectedWalletId` (null berarti Semua) di
`ReportsScreen`, kontrol dropdown reuse pola form yang ada. Semua turunan
(donut masuk/belanja/tabungan, Top-8 plus Others, total, hints transfer)
dihitung ulang dari list yang sudah difilter fungsi murni
`filterByWallet(items, id)`. Transfer ikut bila sisi asal atau sisi tujuan
cocok. Tanpa prefs di fase ini agar scope tetap P2 kecil.

## Data dan prefs

Tanpa migration. Tanpa prefs baru (session-only). Filter jalan di memori
dari `listMonth` yang sudah ada.

## Edge cases

Dompet dihapus setelah dipilih: fallback ke Semua tanpa error. Dompet
tanpa transaksi bulan itu: grafik kosong dengan EmptyView lama, bukan nol
yang menyesatkan. Ganti bulan: pilihan dompet dipertahankan, data dimuat
ulang. Mask ON: angka ikut `amt()`.

## Daftar test

All menghitung semua baris. Filter satu dompet hanya berisi baris sisi
asal, sisi tujuan, dan transfer terkait. ID dompet asing menghasilkan
list kosong. Ganti filter tidak mengubah list sumber.

## Dampak Supabase dan RLS

Tanpa migration. Tidak ada query baru, tidak ada tulis baru. Filter
memakai data yang sudah lewat RLS yang ada.
