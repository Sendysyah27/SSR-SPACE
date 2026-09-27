# P2: Laporan Top-8 plus Others dan section reorderable

## Problem

Rekap kategori laporan menampilkan semua kategori sehingga ekor panjang
menenggelamkan pola utama. Urutan section laporan baku dan tidak bisa
diatur sesuai kebiasaan user.

## Pola Ollo

Ollo menampilkan 8 teratas plus satu baris Others yang bisa diketuk
untuk mengembang, dan urutan section bisa diseret lewat handle di mode
edit sederhana.

## Adaptasi SSR

Bangun di atas toggle `reports_topn` yang sudah ada: saat ON, rekap
menampilkan Top-8 plus Others (ketuk untuk expand 8 berikut). Tambah
prefs `reports_section_order` (list id section) plus mode susun di layar
Laporan via `ReorderableListView` yang hanya mengubah urutan, bukan isi.
Donut dan angka ringkasan tidak berubah.

## Data dan prefs

Tanpa migration. Logika Top-8 plus Others fungsi murni di file kecil
baru mengikuti pola `transfer_detect`. Urutan section di prefs sebagai
list string dengan fallback ke urutan baku bila rusak.

## Edge cases

Kategori kurang dari 8: tanpa baris Others. Seri nominal di batas 8:
urutan stabil abjad agar tidak berkedip antar render. Prefs urutan
rusak atau berisi id asing: fallback baku plus tulis ulang bersih.
Expand Others tidak mengubah total.

## Daftar test

Top-8 plus Others dengan 12 kategori. Tanpa Others saat 8 atau kurang.
Tie-break abjad stabil. Prefs rusak fallback baku. Jumlah Others sama
dengan sisa kategori.

## Dampak Supabase dan RLS

Tanpa migration. Agregasi dari data yang dibaca lewat RLS laporan yang
sudah ada, tidak ada akses baru.
