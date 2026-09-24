# DESIGN.md — SSR SPACE

Aplikasi pencatatan pemasukan dan pengeluaran multi-workspace untuk Indonesia. Dipakai tiap hari, sering malam, satu tangan.

## Dials

Dial: ENERGY 2 / RHYTHM 2 / MOTION 2.
Design Read: aplikasi keuangan phone-first untuk pemakai Indonesia, bahasa visual buku kas yang tenang tapi hidup: hierarki tegas, variasi section wajar, transisi Material halus. Dial ENERGY 2 / RHYTHM 2 / MOTION 2.

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

MOTION 2. Transisi bawaan Material + easing halus (150-250ms): ganti loading/konten anti-blink, progress bar ease, ketuk primary. Tanpa loop tanpa akhir, tanpa parallax.

## Navigasi

Bottom nav 5 tab (Beranda, Transaksi, Budget, Laporan, Lainnya). Alasan: pola ibu jari HP, tujuan utama satu ketukan.

## Kartu gelap

Satu kartu surplus gelap per Beranda sebagai titik fokus. Alasan: angka uang butuh panggung, bukan default mode gelap.
