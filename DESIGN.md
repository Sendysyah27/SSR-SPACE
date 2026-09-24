# DESIGN.md — SSR SPACE

Aplikasi pencatatan pemasukan dan pengeluaran multi-workspace untuk Indonesia. Dipakai tiap hari, sering malam, satu tangan.

## Dials

Dial: ENERGY 1 / RHYTHM 2 / MOTION 1.
Design Read: aplikasi keuangan phone-first untuk pemakai Indonesia, bahasa visual buku kas yang tenang, dial ENERGY 1 / RHYTHM 2 / MOTION 1.

## Palette

- Kertas `#FAFAF7`, tinta `#1C1B1A`, teks sekunder `#5F5E5B`.
- Aksen tunggal zamrud `#0F766E`. Hijau artinya uang bertambah, menenangkan untuk cek harian.
- Sinyal makna: pemasukan zamrud, pengeluaran bata `#B3261E`, selalu ditemani label kata.
- Semua pasangan teks lolos WCAG AA (terukur 5.23 sampai 16.45).

## Tipografi

- Bawaan Material (Roboto) tanpa dependensi font, supaya tetap jalan offline.
- Hierarki dari bobot dan spasi, bukan banyak ukuran. Uang selalu tabular agar digit sejajar.

## Motif

Garis ledger: daftar transaksi berupa baris ber-lineup hairline seperti buku kas. Satu-satunya dekorasi yang berulang.

## Gerak

MOTION 1. Tanpa animasi kustom, hanya bawaan Material. Tidak ada loop tanpa akhir.

## Navigasi

Bottom nav 5 tab (Beranda, Transaksi, Budget, Laporan, Lainnya). Alasan: pola ibu jari HP, tujuan utama satu ketukan.

## Kartu gelap

Satu kartu surplus gelap per Beranda sebagai titik fokus. Alasan: angka uang butuh panggung, bukan default mode gelap.
