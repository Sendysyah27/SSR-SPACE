# DESIGN.md: SSR SPACE

**Simple. Secure. Reliable. Your Finance Space.**

Aplikasi pencatatan pemasukan dan pengeluaran multi-workspace untuk Indonesia. Dipakai tiap hari, sering malam, satu tangan.

## Dials

Dial: ENERGY 2 / RHYTHM 2 / MOTION 1.
Design Read: aplikasi keuangan phone-first untuk pemakai Indonesia, bahasa visual buku kas premium yang tenang dan fokus: hierarki tegas, permukaan bertingkat, transisi Material minimal. Dial ENERGY 2 / RHYTHM 2 / MOTION 1.

## Palette

Otoritas: prompt dan HTML desain user (`New Design/ssr-space-design-implementation-prompt.md`
dan `ssr-space-design-system.html`), ditranskripsi di
`docs/superpowers/specs/2026-09-27-ledger-premium-design.md`.
Adaptasi tercatat di spec tersebut bagian 8: font via bundel existing
(tanpa `google_fonts`), ikon via SVG plus `flutter_svg`
(tanpa `phosphor_flutter`), dark mengikuti token prompt.

- Light: emerald `#0E4B44`, emeraldDeep `#0A332E`, gold `#C9A227`,
  goldSoft `#EDE2C1`, rust `#B23A2E`, cream `#F6F4EC`, ink `#171A19`,
  teks sekunder `#5B6360`, garis `#E4E0D4`.
- Dark: latar `#12100C`, permukaan `#1C1A16`, tinta `#F1EEE6`,
  teks sekunder `#A6A296`, garis `#2C2823`.
- Gold adalah satu-satunya aksen dan tidak pernah dekoratif: hanya tag
  SURPLUS, satu ring budget paling mendesak bulan ini, dan segmen donut
  tabungan.
- Sinyal makna: masuk emerald, keluar rust, tabungan gold, selalu
  ditemani label kata.
- Revisi Industrial 2026-10-14 (disetujui owner, ganti arah penuh):
  chrome netral premium (light `#F2F2F7`/`#FFFFFF`/`#1C1C1E`, dark
  `#000000`/`#1C1C1E`), satu aksen biru iOS (`#007AFF`/`#0A84FF`)
  untuk aksi primer + bubble chat user. Warna makna uang di atas
  TIDAK berubah. Token di `Ind` (app_theme.dart); radius kartu 16,
  hero 20; bayangan hanya hero.
- Semua pasangan teks lolos WCAG AA (terukur 4.73 sampai 16.39;
  terendah `#7A5E14` di goldSoft 4.73, dipakai hanya untuk teks di atas
  tint, bukan solid).

## Tipografi

- **Plus Jakarta Sans** (`SsrFonts.body`): body & judul, bobot 400-700, dibundel di `assets/fonts/` (jalan offline). Humanis dan memang dirancang untuk teks Indonesia; pengganti Roboto sejak 2.3.9+22.
- **Anton** (`SsrFonts.display`): khusus wordmark "SSR SPACE" dan momen brand (splash, intro). Alasan: padat, berat, langsung dikenali.
- Hierarki dari bobot dan spasi, bukan banyak ukuran. Uang selalu tabular (`FontFeature.tabularFigures`) agar digit sejajar.
- Variabel italic PJS tersedia di assets tapi belum dipakai.

## Ikon

- **Phosphor Fill** (`SsrFonts.icon`) untuk layar intro/persetujuan (brand moment). Alasan bobot fill: berat dan solid, cocok dengan Anton di layar pembuka.
- Layar aplikasi tetap Material icon. Backlog: migrasi bertahap ke Phosphor.

## Motif

Grup iOS: kartu inset radius 16 di atas latar grup, pemisah hairline
(evolusi motif ledger, bukan hapus). Satu-satunya dekorasi yang
berulang. Kaca (blur) hanya AppBar Beranda.

## Gerak

MOTION 1. Transisi bawaan Material + easing halus (150-250ms): ganti loading/konten anti-blink, progress bar ease, ketuk primary. Tanpa loop tanpa akhir, tanpa parallax.

## Navigasi

Bottom nav 5 tab (Beranda, Transaksi, Budget, Laporan, Lainnya). Alasan: pola ibu jari HP, tujuan utama satu ketukan.

## Ledger Premium

Light-first cream untuk seluruh aplikasi, plus varian dark mengikuti
token prompt. Mode ikut tema sistem via `AppTheme.light()` dan
`AppTheme.dark()` di `main.dart`. Tanpa baca `platformBrightness` di
widget. Angka uang tampil Fraunces tabular; garis ledger memakai `line`
di atas `cream` (light) atau `lineDark` di atas `bgDark` (dark).
