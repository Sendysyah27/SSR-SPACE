# Design: Pilihan tema Otomatis + Noir - 2026-09-27

Keputusan user: Ledger default, Noir bisa dipilih di settings. Opsi:
`otomatis` (Ledger light/dark ikut sistem, default) dan `noir` (gelap
selalu). Spec ini otoritas pengerjaannya.

## 1. State dan prefs

Kunci baru `app_theme_choice` + notifier `themeChoice`
(`ValueNotifier<String>`: `otomatis` atau `noir`, default `otomatis`)
di `lib/services/app_settings.dart` (ikut pola setter existing: load di
`loadAppSettings` dengan fallback `otomatis`, setter simpan prefs).
Tanpa migration (prefs lokal saja).

## 2. Wiring main

`main.dart` dibungkus pendengar notifier: bila `noir`, `theme` dan
`darkTheme` keduanya `SsrTheme.noir()` (paksa gelap, `themeMode` tetap
system — tanpa baca brightness di widget). Bila `otomatis`, seperti
sekarang (`AppTheme.light()` + `dark()` + system).

## 3. Kembalikan noir + sadar-tema

Restore 9 token noir + `SsrTheme.noir()` dari git history (dihapus saat
sapu ledger; ambil versi terakhirnya, bukan tulis ulang). Lalu konversi
127 pemakaian `AppColors.` mati di 14 file menjadi sadar-tema lewat
`colorScheme` (aturan: emerald teks → `primary`; cream/card → `surface`;
ink/teks → `onSurface`; line → `outline`; hero emeraldDeep TETAP di
kedua mode sebagai momen brand; gold tetap karena lolos di keduanya).
Tiap situs dinilai satu per satu, bukan ganti buta.

## 4. UI settings

Picker di settings (segmen Otomatis dan Noir) + kunci strings `th_auto`
dan `th_noir` (ID/EN). Ganti langsung teraplikasi via notifier (pola
seperti maskAmounts). Copy Indonesia, tanpa em dash.

## 4b. Pilihan saat setup user baru

Satu langkah pilih tema di alur setup awal (setelah persetujuan,
sebelum auth): dua opsi yang sama (Otomatis default terpilih),
tulis ke kunci prefs yang sama (§1). User lama tidak melihat langkah
ini (flag setup sudah ada). Boleh lewati tanpa memilih (tetap Otomatis).

## 5. Test dan penerimaan

Test prefs (default otomatis, persist noir, korup kembali otomatis).
Penerimaan: CI hijau + SS device tiap layar utama dalam 2 mode (terang
sistem dan noir) + APK. Kontras noir pakai ulang tabel terukur lama;
pasangan baru diukur bila muncul.

## 6. Bukan scope

Pilihan Terang/Gelap manual terpisah, animasi transisi tema, widget
native, ubah logika/data/RLS/migration.
