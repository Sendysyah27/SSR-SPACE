# Design: Ledger Premium (otoritas: prompt + HTML user) - 2026-09-27

Sumber otoritatif: `/sdcard/Download/SSR-SPACE/New Design/ssr-space-design-implementation-prompt.md`
dan `ssr-space-design-system.html` (ditulis user). Spec ini transkripsi setia
plus adaptasi yang dicatat eksplisit di §8. Spec Emerald Noir sebelumnya
(`2026-09-27-new-design-emerald-noir-design.md`) dinyatakan SUPERSEDED oleh
spec ini; kode noir yang sudah push digantikan implementasi spec ini.

## 1. Token warna (exact dari prompt)

Light: emerald `#0E4B44`, emeraldDeep `#0A332E`, gold `#C9A227`,
goldSoft `#EDE2C1`, rust `#B23A2E`, cream `#F6F4EC`, ink `#171A19`,
inkSoft `#5B6360`, line `#E4E0D4`. Dark: bgDark `#12100C`,
surfaceDark `#1C1A16`, inkDark `#F1EEE6`, inkSoftDark `#A6A296`,
lineDark `#2C2823`. Aturan gold: SATU-SATUNYA aksen; hanya tag SURPLUS,
satu ring budget paling mendesak bulan ini, dan segmen donut tabungan.
Tidak pernah dekoratif.

## 2. Tipografi, radius, elevasi

Semua nominal Rupiah Fraunces; selainnya Plus Jakarta Sans tanpa kecuali.
Hero 32/600, nilai kartu 22/600, judul 15/600, body 13.5 sekunder. Radius:
kartu 24, baris 12, pill 999, ikon chip 11. Tidak satu radius dipakai di
mana-mana. Shadow kartu: hitam 8% blur 30 offset 0/10 (light), hitam 40%
(dark). Spacing kelipatan 8.

## 3. Ikon (12 SVG custom, bukan font)

`assets/illustrations/cat_{food,transport,shop,bill,health,edu,fun,wifi,save,other,wallet,transfer}.svg`
disalin persis dari HTML. Render via `flutter_svg` (dep existing) 19px di
wadah 38x38 goldSoft radius 11, glif `#7A5E14`. Baris Keluar: wadah tint
rust + glif rust. Mapping `iconForCategory` dipertahankan cabangnya plus
dua cabang baru: pulsa/internet/wifi ke wifi (sebelum tagihan), tabungan
atau saving ke save. Income dan topup ke wallet, transfer ke transfer
(catatan adaptasi: set prompt tak punya ikon income; wallet paling jujur
untuk uang masuk). Pengganti placeholder segitiga-lingkaran di TxRow dan
picker kategori.

## 4. Komponen (nama widget existing)

SectionCard: bg putih (light) atau surfaceDark, border 1px line, radius
24, padding 20/18, shadow kartu. Judul 14 sekunder, nilai Fraunces 22/600.
StatusChip: pill, padding 12/5; surplus goldSoft `#7A5E14` 600 12.5px CAPS
(satu-satunya caps yang disengaja); auto `#E4EFEA` emerald; warning
`#F6E4E1` rust. TxRow: baris ikon 38 + kolom judul 14.5/600 dan subtitle
12 sekunder format `{date} · {time} · {tx_id}` + nominal Fraunces 15/600
(masuk emerald prefix `+`, keluar rust prefix minus U+2212); divider 1px
line top-border, tanpa divider di baris pertama. PrimaryButton: emerald
atau cream 15/600, radius 12, padding 20/15, flat tanpa gradient atau
shadow, full width default, disabled 40% opacity. PinField: 6 kotak 38x46,
border 1.5px line radius 10, fokus emerald 2px, isi dot Fraunces 18, gap 8.

## 5. Layar

Beranda: hero emeraldDeep (ganti hitam murni), tag SURPLUS gold pill kiri
atas, nominal Fraunces 32 cream, Masuk dan Keluar label 12 cream 70% +
nilai Fraunces 14 penuh. Blob abu seperempat lingkaran DIBUANG, ganti
flat atau hairline emas 1px. Budget: ring emerald untuk on-track, gold
hanya satu kategori paling mendesak; copy pace tidak berubah. Laporan:
donut emerald, rust, gold; baris rekap kategori reuse layout TxRow (ikon
+ label + nominal), bukan teks polos.

## 6. Theme wiring

Satu `AppTheme.light()` dan `AppTheme.dark()` (colorScheme, textTheme,
card dan chip default §4). Setiap layar mewarisi token, tanpa hex di file
widget di luar token. Tanpa baca `MediaQuery.platformBrightness` di
widget mana pun (mode ikut theme app).

## 7. Penerimaan (prompt §7 jadi verifikasi)

Tanpa hitam murni di hero atau surface gelap. Tanpa sisa teal lama.
Semua Rp Fraunces, sisanya PJS. Radius 24/12/999 sesuai hierarki. Semua
ikon kategori SVG baru. Gold hanya di 3 titik. Light dan dark ThemeData
keduanya terdefinisi. Verifikasi: CI hijau + SS device per layar + APK.

## 8. Adaptasi tercatat (alasan satu baris)

Font via bundel existing (tanpa `google_fonts`): runtime download
melanggar offline dan diet; Fraunces + PJS sudah dibundel. Ikon via SVG
+ `flutter_svg` (tanpa `phosphor_flutter` 2.1.0): paket itu terbukti
merah di stable (AUDIT) sedangkan SVG lolos CI. Dark mengikuti token
prompt; single-dark noir digantikan. Radius repo lama diganti hierarki
prompt. TxRow ikut format prompt (subtitle/code + prefix U+2212).

## 9. Bukan scope

Logika, model, provider, RLS, migration, gate auto-track, nav, tagline,
copy selain format subtitle TxRow. Toggle tema manual (mode ikut theme
app seperti sekarang).
