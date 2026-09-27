# DESIGN.md: SSR SPACE

**Simple. Secure. Reliable. Your Finance Space.**

Aplikasi pencatatan pemasukan dan pengeluaran multi-workspace untuk Indonesia. Dipakai tiap hari, sering malam, satu tangan.

## Dials

Dial: ENERGY 2 / RHYTHM 2 / MOTION 1.
Design Read: aplikasi keuangan phone-first untuk pemakai Indonesia, bahasa visual buku kas gelap yang tenang dan fokus: hierarki tegas, permukaan bertingkat, transisi Material minimal. Dial ENERGY 2 / RHYTHM 2 / MOTION 1.

## Palette

- Latar `#0C1210`, permukaan `#141C18`, permukaan terangkat `#1B2521`, garis `#2A3530`.
- Tinta `#F2EFE6`, teks sekunder `#A8A39A`.
- Aksen tunggal mint `#2DD4BF`. Mint artinya uang bertambah, menyala tenang di atas gelap untuk cek harian.
- Sinyal makna: pemasukan mint, pengeluaran rose `#F87171`, momen emas `#C6A15B`, selalu ditemani label kata.
- Semua pasangan teks pakai lolos WCAG AA (terukur 6.84 sampai 16.46; putih di mint 1.86 tidak dipakai, tombol primer memakai teks gelap `#0C1210` di mint 10.17).

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

MOTION 1. Transisi bawaan Material + easing halus (150-250ms): ganti loading/konten anti-blink, progress bar ease, ketuk primary. Tanpa loop tanpa akhir, tanpa parallax.

## Navigasi

Bottom nav 5 tab (Beranda, Transaksi, Budget, Laporan, Lainnya). Alasan: pola ibu jari HP, tujuan utama satu ketukan.

## Emerald Noir

Satu tema gelap untuk seluruh aplikasi, tanpa toggle. R-21: gelap adalah identitas. Angka uang tampil di permukaan terangkat (`noirRaised`) dengan digit tabular; garis ledger memakai `noirLine` di atas `noirBg`.
