# Catatan Perubahan SSR SPACE

Versi terpasang: 2.10.0+72.

## Yang baru di 2.10.0+72

1. Ngebut nih: Beranda kini nyebut kategori yang lajunya kencang plus perkiraan tanggal budget habis, dengan bahasa yang santai.
2. Kilasan minggu lalu: tiap minggu ada kartu rangkuman belanja vs rata-rata, kategori paling naik, dan satu saran hemat konkret. Bisa ditutup kalau sedang tak mau diganggu.
3. Laporan punya seksi baru Bulan ini vs bulan lalu: naik-turun per kategori dalam persen, 3 perubahan terbesar ditandai.

## Yang baru di 2.9.0+71

1. Streak catat harian di Beranda: jumlah hari beruntun, toleransi 1 hari bolong, perayaan tiap 7, 30, dan 100 hari.
2. Skor keuangan 0-100 di Beranda: satu angka kondisi dompet (patuh budget, nabung, tren belanja, streak) plus rincian per komponen dan naik-turun vs kemarin.
3. Pace budget: tiap kategori kini berkabar Aman, Waspada (dengan perkiraan tanggal habis), atau Bahaya. Ringkasannya ada di Beranda, ketuk untuk buka Budget.

## Yang baru di 2.8.0+70

1. Catatan hasil scan tak lagi menampung nomor HP atau potongan kode — hanya nama produk. Bila tak ada produk yang jelas, catatan dikosongkan (nama merchant tetap ada).

## Yang baru di 2.8.0+69

1. Catatan hasil scan struk kini hanya berisi nama produk. Potongan kode (server, wifi, nomor order), alamat, dan NPWP tak ikut masuk.

## Yang baru di 2.8.0+68

1. Scan struk: bila label Total/Tunai/Kembali kehilangan angkanya, aplikasi merangkai ulang dari angka yang nyasar (tunai dikurangi kembali, atau jumlah harga barang). Bila ada dua jawaban, aplikasi menolak menebak.

## Yang baru di 2.8.0+67

1. Perbaikan teknis lanjutan scan struk (tanpa perubahan perilaku).

## Yang baru di 2.8.0+66

1. Scan struk: Grand Total kini menang atas subtotal (nominal akhir yang dibayar); bila tulisannya rusak, aplikasi memakai nominal pembayaran e-money. Angka kecil (jumlah barang) dan tanggal masa depan tak akan kepilih lagi.

## Yang baru di 2.8.0+65

1. Form catat lebih jelas: ada label Nominal, judul Langkah 1/2 dengan tombol Kembali, saran kategori yang menyala saat dipilih, keterangan hasil ketik-cepat, dan pesan salah yang menempel di field-nya (nominal, dompet, dompet tujuan).
2. Scan struk kini juga menyarankan kategori (mis. struk kopi jadi Makanan, Indomaret jadi Belanja) dan menampilkan asal prefill di atas nominal. Hanya bila kategorinya ada di daftarmu.

## Yang baru di 2.8.0+64

1. Scan struk makin tahan teks acak: bila baris TOTAL kehilangan angkanya, aplikasi memakai jumlah `PURCHASE` (struk QRIS) atau angka yang muncul berulang; bila kandidat seri (mis. tunai vs kembali), aplikasi menolak menebak — isi manual seperti biasa.

## Yang baru di 2.8.0+63

1. Diagnosis scan struk: setiap selesai memotret, aplikasi menampilkan teks mentah hasil baca kamera dalam dialog — screenshot dan kirimkan bila total masih tak terbaca, agar perbaikan berikutnya tepat sasaran.

## Yang baru di 2.8.0+62

1. Perbaikan baca total struk: kata TOTAL yang cacat terbaca kamera (mis. “T0TAL”, “TOTA L”), angka di baris terpisah, dan baris gabungan total+tunai kini tetap terbaca. Nominal pengecoh (kode pos, tunai, kembali, DPP/PPN, harga jual) tidak akan kepilih.

## Yang baru di 2.8.0+61

1. Perbaikan scan struk: model teks ML Kit kini dilindungi dari pemangkas build rilis (aturan keep di CI) dan jalur baca gambar kembali ke cara resmi, jadi foto struk kamera/galeri terbaca lagi. Bila masih gagal di HP tertentu, pesan error aslinya tetap ditampilkan agar mudah dilaporkan.

## Yang baru di 2.8.0+60

1. Peringatan budget real-time: tiap belanja tercatat, aplikasi mengecek ambang (default 80%, bisa diubah per budget 1–100) dan menandai Melewati batas bila limit jebol. Banner di layar Budget + badge di hub Profil, ketuk untuk tandai sudah dibaca.
2. Wajib jalankan `supabase/migration_16_budget_alerts.sql` di Dashboard → SQL Editor (setelah migration_15), kalau tidak banner tak pernah muncul.

## Yang baru di 2.8.0+59

1. Teknis: APK unduhan pindah ke rilis rolling `ci-apk` (bebas kuota artifact GitHub). Tanpa perubahan aplikasi.

## Yang baru di 2.8.0+58

1. Ikon kategori kini satu keluarga (Coolicons): badge transaksi dan pratinjau kategori tampil seragam. Olahraga, hewan, dan darurat tetap memakai ikon ledger karena tak ada padanannya.
2. Diet aset: 15 SVG ledger + font Phosphor Duotone yang tak terpakai dihapus (fallback-nya mati: seluruh 55 ikon sudah resolve ke Coolicons).

## Yang baru di 2.8.0+57

1. Riwayat transaksi, laporan, dan dompet kini dimuat lazy per baris — bulan padat tidak lagi membangun semua baris sekaligus. Tampilan sama persis.

## Yang baru di 2.8.0+56

1. Aksesibilitas TalkBack: semua tombol ikon (hapus, tutup, kembali) kini bernama; tombol hapus di numpad nominal dan PIN terbaca "Hapus".
2. Rapian token: warna teks emas TxRow kini dari `AppColors.chipSurplusText`, tanpa hardcode.

## Yang baru di 2.8.0

1. Catat transaksi kini 2 langkah: pilih jenis dan kategori dulu, tekan Lanjut, baru isi nominal.
2. Scan struk belanja (kamera atau galeri): total, tanggal, dan rincian otomatis mengisi form, kamu tetap tekan Simpan. Tanpa internet, foto dihapus setelah dibaca.
3. Struk yang sebagian tak terbaca diberi peringatan jujur, bukan angka karangan.
4. Perbaikan diagnosis: bila scan gagal, aplikasi menampilkan pesan error aslinya agar mudah dilaporkan.
5. Perbaikan scan galeri: foto di-decode di aplikasi sebelum dibaca (jalan pintas error sistem di HP tertentu).
6. Perbaikan lanjutan: byte gambar dijamin rapat agar selalu terbaca.
7. Perbaikan jalur baca gambar (format NV21) untuk HP yang menolak cara lama.

## Yang baru di 2.7.0

1. Ekspor Laporan mengikuti filter layar: pilih dompet dan jenis (semua/masuk/keluar/transfer), hasil PDF dan CSV sama dengan yang tampil.
2. Tabel PDF lebih premium: kolom dompet, baris filter, rekap kategori berbar progres.
3. File otomatis tersimpan di Dokumen/ssr-space (minta izin dulu); notifikasi selesai ada tombol Bagikan. Izin ditolak: file dibagikan langsung, bukan gagal.
4. Seluruh ikon aplikasi kini Coolicons (kredit di Tentang); 6 kategori baru: investasi, donasi, keluarga, olahraga, hewan, darurat.

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
