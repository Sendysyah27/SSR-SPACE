# Catatan Perubahan SSR SPACE

Versi terpasang: 2.6.0+48.

## Yang baru di 2.6.0

1. Mode Space per workspace: Bebas (semua anggota catat) atau Bendahara (hanya owner/admin yang catat, anggota lain melihat). Ganti mode di detail workspace dengan PIN.
2. Layar Aktivitas Space: siapa catat/undang/ubah mode, dengan penanda baru yang hilang setelah dibuka.
3. Tiap baris transaksi kini berlabel pencatat (Kamu/Anggota) tanpa membuka nama atau email siapa pun.
4. Anggota di Space bendahara yang mencoba catat mendapat penolakan jelas, bukan error teknis.

## Yang baru di 2.5.0

1. Form catat terbuka lebih cepat (dompet dari cache) dan ketik cepat tak lagi lag.
2. Navigasi bawah tinggal 4 tab; Profil dibuka lewat avatar kiri atas Beranda.
3. Tiap transaksi tersimpan memunculkan notifikasi sistem biasa (tanpa popup koreksi); ketuk untuk lihat detail, koreksi tetap lewat ketuk baris Transaksi.
4. Pengingat mingguan baru (default Minggu 20:00) di samping pengingat harian.

## Yang baru di 2.4.12

1. E-Money NFC terverifikasi: peringatan jujur bila HP tak mendukung atau NFC mati, tombol Coba lagi.
2. Kartu bisa dijadikan dompet: saldo awal tercatat sebagai transaksi, tap berikutnya menawar catat selisih atau lewati.
3. Kelola dompet lengkap: ubah nama dan jenis, hapus (kunci PIN, hanya bila kosong), saldo awal untuk dompet baru.

## Yang baru di 2.4.11

1. E-Money NFC di Profil → Data: tempel kartu Mandiri/e-money untuk baca saldo, nomor, dan riwayat kartu; kartu bisa diberi label dan ditautkan ke dompet; cek terakhir tersimpan lokal. Baca saja — tanpa top-up dan tanpa transaksi otomatis.

## Yang baru di 2.4.10

1. Semua input PIN kini memakai pad angka di layar (tanpa keyboard sistem): layar kunci, buat PIN saat pertama kali, konfirmasi hapus, dan ganti PIN. Di layar kunci, enam digit langsung membuka; salah PIN, kotak dikosongkan otomatis.
2. Perbaikan: bingkai hijau yang menempel di belakang kotak PIN (dari versi 2.4.9+37) dihilangkan, dan kotak PIN kini tegas sehingga mudah dilihat.

## Yang baru di 2.4.9

1. Migrasi token tema: hapus `SsrColors` dan `SsrTheme`, seluruh UI pakai `AppColors`/`AppTheme` secara seragam (30+ file). `SsrTheme.money`/`moneyLarge` → `AppTheme.money`/`moneyLarge`. Tema Otomatis/Noir pakai `AppTheme.light()`/`AppTheme.dark()` tanpa wrapper legacy.

## Yang baru di 2.4.8

1. Tombol + tinggal dua (AppBar dan tengah bawah); riwayat Transaksi muat ulang sendiri tiap dibuka dan tiap kembali ke app.
2. Tombol Susun di Laporan kini jelas: ketuk panah naik/turun untuk menyusun seksi, lalu Selesai.

## Yang baru di 2.4.7

1. Ketik cepat di form catat: tulis "makan siang 35rb" lalu nominal, jenis, kategori, dompet, dan catatan terisi otomatis (tetap Simpan untuk konfirmasi).

## Yang baru di 2.4.6

1. Tiap transaksi tersimpan (otomatis maupun manual) memunculkan pemberitahuan berisi detailnya; bila overlay diblokir HP, tampil notifikasi sistem sebagai cadangan.
2. Perbaikan: notifikasi sistem selalu tampil tiap tersimpan karena blokir overlay di sebagian HP tak terdeteksi (koreksi instan tak lagi hilang diam-diam).
3. Perbaikan: QRIS statis ISAKU ("Pembayaran ... diterima") kini tercatat sebagai Masuk, bukan dilewati.
4. QRIS merchant GoPay yang dananya belum cair kini ditahan (Menunggu cair) dan tak ikut transfer; notif susulan "Pencairan dana berhasil" yang tercatat sebagai Masuk.

## Yang baru di 2.4.5

1. Layar Bantuan: tutorial pemakaian per fitur plus tanya jawab umum.
2. Avatar profil di kiri atas Beranda: ketuk untuk buka Profil.
3. Pratinjau ikon kategori kini sama persis dengan ikon di Transaksi.
4. Ganti PIN cukup verifikasi PIN lama; lupa PIN tetap bisa lewat email.
5. Impor CSV kenal format hasil ekspor dan cadangan (tak jadi 10x lipat).
6. Pengaturan langsung berubah saat diketuk; pintu Profil mendarat pas.
7. Tema Otomatis dan Noir bisa diganti bolak-balik.

## Sebelumnya (2.4.3 – 2.4.4)

1. Pilihan tema Otomatis (ikut sistem) atau Noir (gelap pekat).
2. Target tabungan: kartu emas, irisan donut, dan laju per hari.
3. Tagihan berulang: saran Catat/Lewati plus riwayat Terbayar.
4. Kelompok per hari di Transaksi, Laporan, dan Riwayat Dompet.
5. Koreksi instan: overlay 30 detik untuk benarkan transaksi otomatis.
6. Samarkan nominal dari ikon mata di Beranda.
7. Cadangan CSV dompet, transaksi, dan budget lewat bagikan file.

## Inti yang tetap

1. Catat pemasukan, pengeluaran, dan transfer multi-dompet.
2. Workspace bersama dengan undangan berkode dan peran anggota.
3. Pelacakan otomatis notifikasi bank dan dompet digital.
4. Budget per kategori, laporan CSV dan PDF, kode transaksi TX-000001.
5. PIN keamanan, kunci otomatis, bahasa Indonesia dan Inggris.

Catatan: daftar ini ringkasan umum. Detail per versi mengikuti pembaruan aplikasi.
