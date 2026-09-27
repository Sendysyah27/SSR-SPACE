# P2: Widget Hari Ini plus QS tile (native provider)

## Problem

Cek saldo dan catat cepat masih mengharuskan buka aplikasi penuh. Toggle
`widget_today` di Pengaturan kini hanya stub yang menyimpan bool dan
menampilkan pesan P2.

## Pola Ollo

Ollo memakai widget glanceable satu angka (sisa hari ini) plus satu
tombol catat yang membuka form minimal. QS tile hanya toggle status
singkat, bukan layar penuh.

## Adaptasi SSR

Widget Android `HomeWidgetProvider` menampilkan surplus hari ini (masuk
kurang keluar, ikut mask bila aktif) plus tombol yang deep-link ke
`TxInputSheet`. QS tile memunculkan status surplus yang sama dalam satu
baris. Toggle `widget_today` yang sudah ada menjadi sakelar nyata untuk
keduanya. Data widget ditulis oleh app saat transaksi berubah dan saat
app start, bukan dibaca langsung dari Supabase oleh provider.

## Data dan prefs

Tanpa migration. Prefs `widget_today` yang sudah ada dipakai ulang.
Cache tampilan widget di file lokal app (bukan prefs UI) berisi satu
snapshot: tanggal, surplus minor, mask on/off. Provider hanya baca file
ini sehingga tidak butuh session Supabase di proses widget.

## Edge cases

Session kedaluwarsa: widget menampilkan snapshot terakhir dengan label
tanggal, bukan angka basi tanpa konteks. Mask aktif: nominal disamarkan
di widget juga. OEM yang mematikan background: snapshot bisa basi, label
tanggal membuatnya jujur. QS tile tanpa data: tampilkan ajakan buka app.

## Daftar test

Format snapshot dan parse balik. Mask menyamarkan angka widget. Snapshot
basi tetap berlabel tanggal benar. Toggle off menghapus snapshot lokal.

## Dampak Supabase dan RLS

Tanpa migration. Provider native tidak memegang token dan tidak query
langsung. Semua angka berasal dari snapshot yang ditulis app lewat jalur
RLS yang sudah ada.
