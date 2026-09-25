# DESIGN.md — SSR SPACE

**Simple. Secure. Reliable. Your Finance Space.**

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

- **Plus Jakarta Sans** (`SsrFonts.body`): body & judul, bobot 400-700, dibundel di `assets/fonts/` (jalan offline). Humanis dan memang dirancang untuk teks Indonesia; pengganti Roboto sejak 2.3.9+22.
- **Anton** (`SsrFonts.display`): khusus wordmark "SSR SPACE" dan momen brand (splash, intro). Alasan: padat, berat, langsung dikenali.
- Hierarki dari bobot dan spasi, bukan banyak ukuran. Uang selalu tabular (`FontFeature.tabularFigures`) agar digit sejajar.
- Variabel italic PJS tersedia di assets tapi belum dipakai.

## Ikon

- **Phosphor Fill** (`SsrFonts.icon`) untuk layar intro/persetujuan (brand moment). Alasan bobot fill: berat dan solid, cocok dengan Anton di layar pembuka.
- Layar aplikasi tetap Material icon. Backlog: migrasi bertahap ke Phosphor.

## Motif

Garis ledger: daftar transaksi berupa baris ber-lineup hairline seperti buku kas. Satu-satunya dekorasi yang berulang.

## Gerak

MOTION 2. Transisi bawaan Material + easing halus (150-250ms): ganti loading/konten anti-blink, progress bar ease, ketuk primary. Tanpa loop tanpa akhir, tanpa parallax.

## Navigasi

Bottom nav 5 tab (Beranda, Transaksi, Budget, Laporan, Lainnya). Alasan: pola ibu jari HP, tujuan utama satu ketukan.

## Kartu gelap

Satu kartu surplus gelap per Beranda sebagai titik fokus. Alasan: angka uang butuh panggung, bukan default mode gelap.
