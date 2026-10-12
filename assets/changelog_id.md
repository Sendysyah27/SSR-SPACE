# Catatan Perubahan SSR SPACE

Versi terpasang: 2.43.0+120.

## Yang baru di 2.43.0+120

1. Profil tampil hero: avatar inisial + nama workspace + paket + status pelacakan dalam kartu emerald. Semua seksi Profil & Pengaturan kini berikon.

## Yang baru di 2.42.0+119

1. Voice input native jujur soal jaringan: gagal karena internet kini berpesan "butuh internet", bukan error umum. Recognizer juga dibersihkan tiap berhenti agar tap ulang tak macet. Wajib ada internet + layanan suara Google; coba ucap "makan siang 25 ribu".

## Yang baru di 2.41.0+118

1. Ikon dompet brand: DANA, OVO, GoPay, BCA, BRI, Mandiri, dan bank/e-wallet lain kini berbadge warna resminya mengikuti nama dompetmu.
2. Hasil scan struk super detail: nama gerai + alamat + telepon, no struk, tanggal + jam, kasir, tabel belanjaan per item (nama, jumlah, harga), subtotal, diskon, total, dan jenis bayar (QRIS/Tunai/E-Money/dll). Yang tak terbaca disembunyikan, bukan dikarang.
3. Voice input dibangun ulang native (tanpa plugin lama): kenali layanan suara HP dulu, izin mic eksplisit, hasil langsung mengisi ketik-cepat. Gagal kini berpesan jujur + saran perbaikan.
4. Konsistensi visual: semua layar kosong kini berilustrasi (tak ada lagi kotak abu), hasil struk bisa disalin teksnya.
5. Preview struk kini replika thermal: urutan baris sama dengan struk fisik, font monospace, tanpa kartu-kartu.

## Yang baru di 2.40.0+117

1. Polish rilis: teks riwayat tantangan diperjelas, kode tak terpakai dibersihkan, dan seluruh teks aplikasi kini dikunci test dua bahasa (tak ada yang kelewat tanpa Inggris).
2. Layar Tentang otomatis menampilkan versi terbaru. Ikon & splash custom ditunda ke batch tersendiri (butuh aset + cek device).

## Yang baru di 2.39.0+116

1. Tantangan 30 Hari: tentukan target belanja harian, kumpulkan 30 hari hemat dengan progress bar + streak + perayaan milestone 7/14/21/30. Pengingat harian jam 8 malam. Selesai = badge baru + 50 XP. Ada saran kategori yang bisa dihemat dari riwayatmu + riwayat tantangan. Menu Profil → Tantangan 30 Hari.

## Yang baru di 2.38.0+115

1. Pencarian & filter Transaksi: kolom cari (kategori, catatan, kode) + lembar saring (jenis, kategori, rentang tanggal, rentang nominal). Filter favorit bisa disimpan (maks 10) dan dipakai ulang sekali ketuk. Saringan dihitung dari data yang sudah termuat — keterangannya jujur ("disaring dari N") bila bulan ramai belum termuat semua.

## Yang baru di 2.37.0+114

1. Pengingat jatuh tempo: utang/piutang ber-tenggat dan tagihan aktif diberi tahu H-3 dan H-1 (jam 9 pagi). Daftar segera-jatuh-tempo tampil di layar Utang & Tagihan. Isi tenggat saat catat utang agar diingatkan.

## Yang baru di 2.36.0+113

1. Kilasan mingguan makin pintar: hari paling boros + tandai transaksi janggal (nominal ≥3x rata-rata kategorinya) + tips periksa.

## Yang baru di 2.35.0+112

1. Mic kini menampilkan kode diagnostik bila gagal mulai (cth err:error_no_match), jadi penyebabnya ketahuan.
2. Judul kartu tak lagi kepotong untuk nama panjang.
3. Pembersihan kode mati voice + audit crash layar-layar baru.

## Yang baru di 2.34.0+111

1. Layar Anggota: lihat belanja tiap anggota workspace bulan ini, undang anggota baru, dan keluarkan anggota (owner/admin). Menu Profil → Workspace → Anggota.

## Yang baru di 2.33.0+110

1. Kekayaan bersih: kartu di Beranda (total aset minus utang) + layar rincian per kategori (likuid, tabungan, investasi, piutang, utang) + grafik tren 6 bulan. Piutang dihitung sebagai aset.

## Yang baru di 2.32.0+109

1. Jatah harian di Beranda: sisa budget dibagi sisa hari (mis. Rp3jt / 15 hari = Rp200rb/hari), lampu hijau/kuning/merah ikut pace belanja. Ikut tersusun di mode Susun dashboard.

## Yang baru di 2.31.0+108

1. Widget home anti-crash: gambar ulang aman walau belum ada data.
2. Template Excel SSR SPACE: judul + periode + header + TOTAL + border + zebra.
3. Notifikasi ekspor kini bisa diketuk untuk buka file-nya langsung.
4. Scan struk: animasi laser saat memproses + hasil tampil ala struk (produk, total, tanggal) dengan penanda bila belum yakin. Item hanya dari atas garis total (footer tak ikut).
5. Voice input: izin diminta eksplisit sebelum init + pesan gagal spesifik (izin/layanan/error) + coba default-dulu + fallback intent bila start gagal.

## Yang baru di 2.30.0+107

1. Perbaikan mic lanjutan: coba locale default dulu sebelum id-ID, cegah start saat offline dengan pesan jujur.

## Yang baru di 2.30.0+106

1. Perbaikan voice input: mic yang mati diam-diam kini menampilkan sebabnya (tak terdengar/izin/gagal mulai), bukan stuck "mendengarkan".

## Yang baru di 2.30.0+105

1. Voice input: ketuk mic di kolom ketik-cepat, ngomong misal "makan siang 25 ribu" — nominal + kategori terisi otomatis. Periksa dulu, simpan tetap manual. Butuh izin mic + internet.

## Yang baru di 2.29.0+104

1. Perapihan ekspor Excel: lebar kolom menyesuaikan isi, tanggal full, nominal pakai pemisah ribuan, judul tebal berlatar + baris judul lebih lega.

## Yang baru di 2.29.0+103

1. Prakiraan kas di Laporan: grafik 30 hari dari saldo dompet + rata-rata belanja + tagihan terjadwal, angka akhir bulan, dan peringatan bila diprediksi minus.

## Yang baru di 2.28.0+102

1. Dashboard baru di Beranda: kartu status budget (hijau/emas/merah per kategori), jalan pintas semua fitur, dan ringkasan utang — semuanya bisa disusun ulang dan disembunyikan lewat tombol Susun. Navigasi bawah tetap sama.

## Yang baru di 2.27.0+101

1. Widget layar utama: tampilkan sisa budget bulan ini + pengeluaran hari ini, ketuk untuk buka app, diperbarui tiap transaksi tersimpan (maksimal 30 menit bila app tak dibuka). Cara pakai: tahan layar utama → Widget → SSR SPACE.

## Yang baru di 2.26.0+100

1. Ekspor Excel: laporan bulanan kini bisa diunduh sebagai .xlsx — 1 sheet Transaksi dengan tombol filter tiap kolom, baris judul beku, dan nominal berupa angka (bisa SUM). Tombol XLSX di Laporan, gratis seperti CSV.

## Yang baru di 2.25.0+99

1. Utang & Piutang: catat utangmu ke orang atau piutang orang ke kamu (nama, nominal, tanggal, catatan), pantau total sisa keduanya, bayar sebagian atau penuh dengan riwayat per catatan. Menu Profil → Utang & Piutang.

## Yang baru di 2.24.0+98

1. Patungan: pilih transaksi, pilih anggota workspace, bagi rata atau custom — terlihat siapa berutang ke siapa, tiap utang bisa ditandai lunas. Menu Profil → Patungan.

## Yang baru di 2.23.0+97

1. Pelacak langganan: pola bayar berulang (nama + nominal tiap ±30 hari) terdeteksi otomatis dari riwayat, lengkap dengan total per bulan. Yang tak dikenal ditandai Baru — jadikan tagihan rutin atau abaikan sekali ketuk. Menu Profil → Langganan terdeteksi.

## Yang baru di 2.22.0+96

1. Budget kini menepuk bahu: notifikasi muncul saat belanja menyentuh 80% dan 100% batas (sekali per kategori, tak spam).

## Yang baru di 2.21.0+95

1. Cadangan JSON: satu file utuh (dompet + transaksi + budget) yang bisa dipulihkan kapan saja. Menu Profil → Cadangan JSON.

## Yang baru di 2.20.0+94

1. Tetap bisa dibuka tanpa internet: data terakhir tersimpan otomatis ditampilkan, dengan penanda offline. Mencatat baru tetap butuh internet.

## Yang baru di 2.19.0+93

1. Bersih-bersih internal (tak ada perubahan fitur): migrasi database dijadikan satu file agar pemasangan baru lebih mudah; kode tak terpakai dibuang sehingga aplikasi lebih ringan.

## Yang baru di 2.19.0+92

1. Perubahan workspace kini muncul sendiri tanpa tarik-muat-ulang (mis. teman mencatat, saldomu ikut segar).
2. Perlu tindakan: jalankan `migration_19_realtime.sql` di Supabase SQL Editor (setelah migration_18).

## Yang baru di 2.18.0+91

1. Perbaikan sidik jari tak merespon: aktivitas Android diganti agar dialog biometrik bisa tampil. Bila masih gagal, layar kunci kini menampilkan alasannya (tidak diam lagi).

## Yang baru di 2.18.0+90

1. Perbaikan login Google native (kirim Web client ID agar tak mental ke browser). Butuh Web client ID di secret CI — tanya admin bila masih lewat browser.

## Yang baru di 2.18.0+89

1. Angka Beranda & Laporan kini eksak di bulan yang ramai (dulu kepotong 200 transaksi). Riwayat dimuat bertahap saat digulir, ekspor tetap lengkap.
2. Aplikasi menyapa server tiap hari agar layanan tetap hidup.
3. Perlu tindakan: jalankan `migration_18_scale.sql` di Supabase SQL Editor (setelah migration_17).

## Yang baru di 2.17.0+88

1. Masuk dengan Google: ketuk tombolnya di layar Masuk (butuh aktivasi Google di server — tanya admin bila gagal).
2. Buka kunci sidik jari: nyalakan di Pengaturan → PIN tetap bisa dipakai. PIN tak lagi wajib diketik tiap buka.

## Yang baru di 2.16.0+87

1. Kuota Gratis kini ditegakkan server (workspace 2, anggota 3, auto-track 150/bulan) — tak bisa diakali. Paket Pro ditandai "Segera hadir" sampai pembayaran siap.
2. Perlu tindakan: jalankan `migration_17_quotas.sql` di Supabase SQL Editor (setelah migration_16).

## Yang baru di 2.15.0+86

1. Panduan pelacakan 3 langkah: izin notifikasi, nyalakan tombol, petakan tiap bank ke dompet. Buka dari Pelacakan otomatis.
2. Riwayat Transaksi kini dimuat bertahap saat digulir — bulan yang ramai tetap tampil semua.

## Yang baru di 2.14.0+85

1. Lupa password: ketuk "Lupa password?" di layar Masuk, cek email, ketuk linknya, buat password baru di dalam app.
2. Daftar undangan workspace tak lagi crash bila datanya rusak (dianggap kedaluwarsa).

## Yang baru di 2.13.7+84

1. Perbaikan crash 2.13.1: widget Beranda kini tulis snapshot saja (tanpa channel native), pengingat tetap heads-up tapi izin hanya diminta saat toggle dinyalakan (startup silent tanpa dialog).

1. Kembali ke versi stabil 2.13.0: perbaikan darurat 2.13.1 sampai 2.13.5 masih crash di HP, jadi seluruh perubahan itu dibatalkan dulu. PIN dan kunci otomatis jalan normal lagi.

## Yang baru di 2.13.0+76

1. Empat pengaturan baru: format angka Indonesia/Asing, dompet default buat form catat, awal minggu Senin/Minggu, dan kunci otomatis 1 sampai 30 menit.
2. Kunci otomatis kini beneran jalan: app yang lama di background minta PIN lagi saat dibuka.

## Yang baru di 2.12.1+75

1. Tombol pengaturan kini ada di Beranda (ikon gear di atas), tak perlu masuk profil dulu.
2. Cari pengaturan kini mendarat di kartu yang tepat, bukan di atas.
3. Perbaikan kecil: ekspor PDF jujur saat offline, bulan rusak tak lagi bikin error, dan layar lebih aman saat pindah cepat.

## Yang baru di 2.12.0+74

1. Pencapaian: kumpulkan 8 badge (streak, nabung, bulan bersih, dan lainnya). Yang baru kebuka ditandai, yang terkunci tampil beserta syaratnya.
2. Tantangan mingguan: Puasa Belanja, Jajan Kalem, Rajin Absen. Ikut seikhlasnya, progres jalan otomatis, selesai dapat 50 XP.
3. Level: tiap catatan, streak, tantangan, dan goal menambah XP. Beranda menampilkan Lv dan julukanmu, dari Baru Mulai sampai Legenda Ledger.

## Yang baru di 2.11.0+73

1. Target nabung: bikin goal (nama, nominal, deadline opsional) yang ikut kategori Tabungan atau setor manual. Ada progress bar, persen, sisa hari, dan proyeksi kecapai kapan.
2. Simulasi jujur: bila meleset dari deadline, aplikasi nyebut kurangnya berapa per bulan. Bila belum ada riwayat, aplikasi bilang belum bisa diproyeksi.
3. Dana darurat: target otomatis 3 sampai 6 kali belanja bulananmu, status Belum aman, Progres, atau Aman. Muncul di Beranda bareng goal terdekatmu.

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
