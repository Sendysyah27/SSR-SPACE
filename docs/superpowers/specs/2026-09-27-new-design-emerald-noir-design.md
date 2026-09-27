# Design: New Design Emerald Noir (SUPERSEDED oleh 2026-09-27-ledger-premium-design.md — prompt + HTML user adalah otoritas)

Keputusan user: rombak semua layar yang masih slop ke arah visual baru
**Emerald Noir** (dark-first premium), output kode Flutter di repo sekaligus
satu push, folder `/sdcard/DCIM/SSR-SPACE/New Design/` diisi SS per layar +
APK final. Kualitas di atas kecepatan. Skill aktif: brainstorming,
redesign-existing-projects, antislop (core, UI, copy) mode During.

## 1. Design Read dan dial

Reading this as: aplikasi keuangan phone-first untuk pemakai Indonesia,
dipakai tiap hari dan sering malam, bahasa visual Emerald Noir yang
premium dan tenang, dial ENERGY 2 / RHYTHM 2 / MOTION 1.

Alasan dial: ENERGY 2 karena uang butuh panggung tanpa berteriak.
RHYTHM 2 karena 5 tab plus sheet punya pola sendiri dengan sedikit
variasi yang disengaja. MOTION 1 karena premium yang tenang: hover dan
transisi pendek saja, tanpa loop tanpa akhir.

## 2. Palet (satu aksen, sinyal bermakna)

- Dasar noir: bg `#0C1210`, surface `#141C18`, surface terangkat `#1B2521`,
  hairline `#2A3530`. Alasan: hitam ber-tint zamrud, bukan hitam murni.
- Teks: primer `#F2EFE6`, sekunder `#A8A39A`. Alasan: putih kertas hangat,
  konsisten dengan memori brand lama.
- Aksen zamrud terang `#2DD4BF` untuk momen kunci dan Masuk. Alasan: satu
  aksen, dipakai hemat di titik keputusan.
- Sinyal makna: Keluar merah terang `#F87171`, selalu ditemani label kata.
  Tabungan emas `#C6A15B`, hanya momen tabungan dan brand. Alasan: tiga
  makna uang (masuk, keluar, tabungan) terbaca tanpa legenda panjang.
- Kontras tiap pasangan teks diverifikasi WCAG AA saat implementasi
  (bukti berupa tabel ukur, bukan klaim).

## 3. Tipografi dan ikon

- Plus Jakarta Sans untuk body dan judul (bobot 400 sampai 700, hierarki
  dari bobot). Fraunces untuk angka besar. Anton hanya wordmark dan momen
  brand. Uang selalu tabular. Alasan: meneruskan yang sudah terbukti di
  device, tanpa dep font baru (diet APK aman).
- Ikon migrasi penuh ke Phosphor Duotone (TTF sudah dibundel). Alasan:
  satu bahasa ikon di semua layar, menghapus campuran Material dan
  Phosphor yang terlihat sekarang.

## 4. Motif dan permukaan

- Motif ledger dipertahankan sebagai satu-satunya dekorasi berulang
  (hairline antar baris transaksi). Alasan: identitas produk, bukan tempel.
- Satu kartu hero gelap ber-aksen emas per Beranda sebagai titik fokus.
  Elemen lain duduk datar; shadow hanya penanda elevasi (sheet, FAB).
  Alasan: panggung tunggal untuk angka uang.

## 5. Per layar (copy Indonesia identik, logika tetap)

- Splash, lock, intro, auth: momen brand (Anton, hairline emas). Lock
  tanpa ruang kosong melompong: PIN 6 kotak rapat, tombol Buka penuh.
- Beranda: hero surplus berevolusi (garis emas, angka Fraunces, Masuk dan
  Keluar berdampingan). Calm streak dot dipertahankan. Tombol Catat tetap
  primer. Daftar terbaru memakai grup hari yang sudah ada.
- Transaksi: grup hari diberi header tegas, banner tanpa-dompet dihaluskan
  (tanpa menutupi data). FAB tidak menutup baris terakhir (padding akhir).
- Dompet: strip komposisi di atas daftar, baris dompet premium dengan
  WalletArt. Tambah tipe Tabungan dan Investasi ikut gaya baru.
- Budget: kartu gauge dipertahankan, kartu Tabungan emas dengan ilustrasi
  yang terhubung (bukan tempel generik). Form Batas baru seirama input
  global. Hapus via PIN tetap.
- Laporan: legenda anti-potong (wrap dua baris, bukan truncate), donut
  tiga iris, filter dompet segaya input lain, tombol ekspor berpasangan.
- Lainnya dan settings: subtitle jujur "tahap P2" yang berulang di tiap
  kartu disapu menjadi satu baris status di kepala seksi. Nol dead tap
  tetap. Workspace picker, invite, detail mengikuti bahasa yang sama.
- Sheet input, koreksi, overlay: numpad premium (kontras AA, feedback
  tekan), chip kategori seirama, Simpan dan Lewati jelas.

## 6. Batasan keras

- Visual-only: tanpa migration, tanpa dep pubspec baru, tanpa sentuh
  `_onEvent`, RLS, TX-code, atau alur data. Semua tombol dan navigasi
  tetap ke tujuan nyata yang sudah ada (nol dead tap, nol buntu).
- Copy Indonesia identik kecuali yang disepakati eksplisit. Angka lewat
  `amt()`, tanggal lewat helper yang ada. `build()` di bawah 50 baris.
- `flutter analyze` 0 issue (info pun fatal). Verifikasi: CI hijau +
  SS device per layar yang disentuh di folder New Design + APK final.

## 7. Bukan scope

- Fitur baru, ubah RLS atau policy, ubah gate auto-track, ubah nav atau
  tagline, aset luar selain yang sudah dibundel, klaim angka tanpa ukur.
- Toggle terang atau gelap: single dark theme (keputusan user, R-21
  terpenuhi karena gelap adalah identitas brand).

## 8. Rollout

Sekaligus satu push (keputusan user): fondasi theme dulu dalam branch
kerja yang sama, lalu layar per layar, review subagent sebelum push,
version bump Skema A, CI hijau, SS per layar, APK arm64 ke folder New
Design. Mitigasi risiko push besar: analisa ekstra hati-hati per file
plus review baca-diff sebelum push (pelajaran Paket R: review menangkap
`value:` yang deprecated sebelum CI merah).
