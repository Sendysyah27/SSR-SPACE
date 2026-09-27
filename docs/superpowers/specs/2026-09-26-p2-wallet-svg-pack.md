# P2: Paket SVG dompet (redrawn)

## Problem

Ikon dompet per tipe (cash, ewallet, bank) kini memakai glif generik.
Ikon yang digambar ulang memberi identitas tiap tipe tanpa menambah font
atau dependensi.

## Pola Ollo

Ollo memakai set ikon garis 24px satu gaya untuk semua tipe akun, stroke
konsisten, tanpa warna di dalam file (warna dari `color` pemanggil).

## Adaptasi SSR

Gambar ulang mandiri (bukan file Ollo, bukan unDraw): tiga SVG
`wallet_cash.svg`, `wallet_ewallet.svg`, `wallet_bank.svg` di
`assets/illustrations/`, gaya garis 1.5px mengikuti palet kertas dan
zamrud. Dipakai di `WalletRow` dan header `WalletDetailScreen` lewat
`flutter_svg` yang sudah ada. Warna via `colorFilter`, bukan hardcode di
file.

## Data dan prefs

Tanpa migration. Tidak ada prefs baru. Peta tipe ke file hidup di satu
helper kecil agar layar tidak mengulang string path.

## Edge cases

Tipe tak dikenal: fallback ke ikon cash generik. File hilang: `errorBuilder`
menampilkan lingkaran inisial seperti avatar sekarang. Dark mode (bila
datang): SVG tanpa warna hardcode tetap terbaca. Ukuran dibatasi di
pemanggil agar tidak mendorong layout.

## Daftar test

Peta mencakup tiga tipe plus fallback asing. Helper path tidak
mengembalikan string kosong. Golden tidak wajib, cukup assert file
terdaftar di pubspec assets.

## Dampak Supabase dan RLS

Tanpa migration. Aset lokal saja, tidak ada perubahan data atau policy.
