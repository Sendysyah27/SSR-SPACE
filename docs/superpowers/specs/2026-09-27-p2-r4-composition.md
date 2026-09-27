# P2-R4: Komposisi aset Liquid, Savings, Investments

## Problem

Layar Dompet SSR menampilkan tiap saldo terpisah tanpa menjawab:
berapa yang likuid, berapa yang parkir sebagai tabungan, berapa yang
investasi. Donut Laporan menjawab arus bulan ini, bukan posisi aset.

## Pola Ollo

Ollo 1.6.0 punya Money Composition: porsi Liquid, Savings, Investments
dari semua akun. Referensi alur saja, tanpa salin kode atau aset.

## Adaptasi SSR

Modul murni `lib/services/wallet_composition.dart`: `bucketOf(type)`
memetakan `savings` ke Savings, `investment` ke Investments, sisanya
(`cash`, `ewallet`, `bank`, tak dikenal) ke Liquid. `compose(balances)`
menjumlahkan saldo per bucket dari data `wallet_balance` yang sudah
dimuat, plus persen. Strip reuse `SectionCard` dan donut mini pola
Laporan di atas list Dompet. Opsi tipe baru cukup ditambah di dropdown
form dan strings (kolom DB bertipe text bebas). Art memakai fallback cash
dulu tanpa aset baru. Strip sembunyi bila kurang dari 2 bucket berisi,
agar workspace baru tidak menampilkan komposisi 100 persen yang kosong
makna.

## Data dan prefs

Tanpa migration (kolom `wallets.type` text tanpa check constraint).
Dua strings baru per bahasa untuk label Savings dan Investments plus
subtitle jujur. Tanpa prefs baru.

## Edge cases

Semua dompet lama bertipe cash, ewallet, atau bank: seluruhnya Liquid,
strip sembunyi. Saldo gagal dimuat: strip ikut sembunyi, list tetap
tampil dengan pesan Belum termuat yang ada. Nominal negatif atau nol:
ikut penjumlahan apa adanya, persen dihitung dari total nilai mutlak
bila total nol maka persen nol. Mask ON: angka ikut `amt()`.

## Daftar test

Pemetaan tiap tipe ke bucket benar termasuk tak dikenal ke Liquid.
Penjumlahan dan persen dari saldo buatan benar. Satu bucket berisi
menghasilkan flag sembunyi. Total nol menghasilkan persen nol tanpa
crash. Label ID dan EN tersedia.

## Dampak Supabase dan RLS

Tanpa migration. Tidak ada query atau tulis baru. Memakai view
`wallet_balance` yang sudah lewat RLS yang ada.
