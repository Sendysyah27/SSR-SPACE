# P2: Varian copy pengingat harian (reminder copy)

## Problem

Satu kalimat pengingat yang sama tiap hari cepat menjadi kebisingan dan
diabaikan. Pengingat yang terasa menekan (kejar target, jangan bolos)
bertentangan dengan posisi produk sebagai ruang keuangan yang tenang.

## Pola Ollo

Ollo merotasi 5 sampai 7 varian copy netral per konteks (pagi, malam,
akhir bulan) tanpa skor, tanpa streak, tanpa badge. Nada tenang dan
tanpa rasa bersalah bila user melewatkan satu hari.

## Adaptasi SSR

Rotasi deterministik per hari dari daftar copy di `strings.dart` (ID dan
EN, ikut bahasa app): varian pagi (ajak catat kemarin), varian malam
(refleksi singkat), varian akhir bulan (persiapan tutup bulan). Pilihan
varian dari hash tanggal, bukan acak, agar QA bisa memprediksi. Copy
tetap tanpa angka nominal user agar aman tampil di lockscreen.

## Data dan prefs

Tanpa migration. Tidak ada prefs baru kecuali bila user meminta matikan
rotasi (satu bool `reminder_rotate`, default true). Pemilihan varian
fungsi murni dari tanggal.

## Edge cases

Bahasa ganti tengah jalan: varian langsung ikut bahasa aktif. Reminder
tetap satu notifikasi per hari, rotasi tidak menambah jumlah. Teks
fallback ke varian pertama bila kunci hilang. Panjang teks dibatasi agar
tidak terpotong di notifikasi ringkas.

## Daftar test

Hash tanggal memetakan stabil ke indeks varian. Semua varian punya kunci
ID dan EN. Fallback varian pertama saat kunci asing. Rotasi tidak
mengubah jam jadwal yang sudah ada (`reminder_schedule` test tetap hijau).

## Dampak Supabase dan RLS

Tanpa migration. Copy lokal di `strings.dart`, tidak ada baca tulis data
di server.
