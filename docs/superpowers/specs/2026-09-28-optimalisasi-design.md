# Spec: Optimalisasi SSR SPACE (sheet cepat, nav Profil, notif murni, pengingat mingguan)

Tanggal: 2026-09-28 · Versi dasar: 2.4.12+46 · Target rilis: 2.5.0+47
Status: DRAFT, menunggu review user. We Space (komunitas/role kas bersama) SENGAJA di luar scope,
dicatat sebagai roadmap Fase berikutnya di §6.

Keputusan user yang mengunci (sesi brainstorm 2026-09-28):
P1 keduanya berat (buka lambat + ketik lag). P2 empat tab + avatar profil. P3 ketuk notif
buka detail read-only. P4 harian + mingguan.

Aturan repo yang berlaku: tanpa migration, tanpa dep baru (malah melepas satu dep),
bump version Skema A + entri changelog_id.md, APK arm64 ke /sdcard/Download/SSR-SPACE/,
catat lokal AGENTS.md + AUDIT.md §7, gabung push berikutnya.

---

## P1. Sheet catat transaksi terasa ringan (buka cepat + ketik smooth)

Vonis kode (bukan tebakan): `openTxInputSheet` menunggu DUA roundtrip Supabase
(`WalletService().list` + `balances`) SEBELUM `showModalBottomSheet` muncul, itu jeda buka.
Ketik: `_applyQuick` mem-parse + `setState` SEMUA sheet tiap karakter (rebuild 739-baris
Column per ketikan). Numpad + display nominal SUDAH benar (ValueNotifier sempit,
`_AmountDisplay` + `TxNumpad` stateless), jangan dirombak.

1. Cache dompet first: `WalletCache` di `wallet_service.dart` (memori, TTL 60 detik,
   fail-open). `openTxInputSheet` tampilkan sheet SEGERA dari cache (atau kosong +
   spinner kecil di dropdown bila cache kosong), refresh diam-diam lalu isi ulang
   bila ada perubahan. Balances tetap fail-open seperti sekarang.
2. Debounce ketik cepat 300 ms: parse + `setState` hanya setelah jeda, bukan tiap
   karakter. Tanpa nominal valid tetap abaikan seperti sekarang.
3. Jangan tambah dep/state-management baru. `setState` sheet-level dipertahankan
   (subtree sudah stateless kecil, biaya rebuild terbatas).
4. Batas jujur: tanpa profiler di device, bukti = rasa di HP user + CI hijau.
   Bila masih berat, follow-up ukur ulang (bukan scope ini).

File: `lib/widgets/tx_input_sheet.dart`, `lib/services/wallet_service.dart` (cache),
`test/` (cache TTL + debounce logika murni bila diekstrak).
Uji: `flutter analyze` 0 issue, test hijau, cek manual buka sheet < 1 detik dari cache.

## P2. Navigasi: 4 tab + Profil via avatar

Struktur baru: bottom nav 4 destinasi (Beranda, Transaksi, Budget, Laporan).
`OtherScreen` keluar dari `IndexedStack`, dibuka sebagai route Profil via avatar
kiri-atas Beranda (avatar + `onProfil` SUDAH ada, tinggal ubah tujuan dari
`_select(4)` menjadi push route). FAB + tengah tetap.

1. `main_shell.dart`: hapus tab ke-5 + `OtherScreen` dari stack, `_select` 0-3,
   tambah `openProfil()` (push `OtherScreen` sebagai `ProfilScreen`, judul AppBar
   ganti `nav_lainnya` menjadi kunci baru `nav_profil`; string lama dipertahankan
   bila dipakai search, hapus bila nol rujukan).
2. `beranda_screen.dart`: `onProfil` tetap, tanpa ubah visual avatar.
3. `other_screen.dart`: judul Profil, logout tetap `pushAndRemoveUntil` Splash
   (aman dari route bertumpuk). Seluruh tile hub + `settings_search` tetap jalan.
4. Antislop/layoutmobile: tap avatar min 44x44 (sudah CircleAvatar + InkWell,
   verifikasi), nol dead tap, bottom-nav 4 label lolos tanpa overflow 360dp.

File: `main_shell.dart`, `beranda_screen.dart` (kecil), `other_screen.dart`,
`strings.dart` (kunci `nav_profil` ID+EN), `settings_search.dart` bila perlu.
Uji: tiap tab reload seperti sekarang, Profil kembali tanpa kehilangan state tab.

## P3. Hapus koreksi instan, notif murni + detail read-only

Alasan hapus (bukan sekadar bug): overlay menuntut izin khusus, diblokir diam-diam
sebagian OEM (kasus MIUI tercatat), dan rantai pending/pinNotice/OverlayBus adalah
sumber bug berulang. Pengganti: notifikasi Android biasa yang SELALU tampil,
tanpa aksi tulis dari notif. Koreksi tetap ada lewat jalur normal (ketuk TxRow).

1. HAPUS: dep `flutter_overlay_window` (pubspec), `overlayMain` + import
   `correct_overlay.dart` (main.dart), blok inject overlay + izin
   `SYSTEM_ALERT_WINDOW` (apk.yml, blok foreground service DIPERTAHANKAN),
   `correct_sheet.dart`, `correct_overlay.dart`, `overlay_bus.dart` (satu-satunya
   konsumen listener 'main' adalah sheet koreksi), `instant_correct.dart`
   (fungsi `summary()` mati bersamanya; body notif baru dibangun oleh
   `savedBody()` di `auto_saved_notify.dart`, diuji di
   `test/auto_saved_notify_test.dart`), `test/instant_correct_test.dart`,
   `clearNotice` (foreground_track.dart), timer 3 menit + pref `correct_popup` +
   `pending_correct_tx`, kartu koreksi + tombol tes overlay + logika izin overlay
   (notif_settings_screen.dart), tile/reset terkait (other_screen.dart),
   entri search `ic_popup`, kunci string `ic_*` yang nol rujukan, test terkait.
2. PERTAHANKAN: foreground service, gate `_onEvent`, auto-insert, auto-merge
   transfer (out+in auto, nominal sama, dompet beda, <=10 mnt, fail-open),
   recent list + Simpan manual (`forceSave` tanpa offer).
3. BARU `AutoSavedNotify.showSaved`: judul "Transaksi tercatat", isi satu baris
   per jenis: Masuk/Keluar `"{jenis} {nominal} • {app}"`, transfer
   `"Transfer {nominal} • {appKeluar} ke {appMasuk}"` (label dari sourcePackage
   kedua kaki merge, tanpa baca DB tambahan). Channel `ssr_auto_saved` tetap.
   Ketuk: `AutoSavedNotify._init` didaftari handler
   `onDidReceiveNotificationResponse` yang menulis prefs `last_detail_tx`;
   `MainShell` (init + resume, pola `_resumed` yang sudah ada) mengambilnya,
   fetch transaksi, tampilkan `TxDetailSheet` READ-ONLY (nominal, jenis, dompet,
   kategori, catatan, kode, tanggal; tombol Tutup + Lihat di Transaksi yang
   pindah tab). Fetch gagal = abaikan diam-diam + bersihkan prefs.
4. Copy ID+EN baru secukupnya (`nt_saved_*`, `tx_detail_*`), tanpa em dash,
   tanpa klaim palsu, kalimat pendek orang Indonesia.

File: hapus 4-5 file di atas; ubah `notif_track_service.dart`, `auto_saved_notify.dart`,
`main.dart`, `main_shell.dart` (ganti `_checkPending` jadi `_checkDetail`),
`foreground_track.dart`, `notif_settings_screen.dart`, `other_screen.dart`,
`strings.dart`, `apk.yml`, `pubspec.yaml`; baru `tx_detail_sheet.dart` + test.
Uji: teks asli ISAKU/GoPay lama (regresi merge), tap notif dari kondisi mati app.

## P4. Pengingat harian + mingguan

Arsitektur lama sudah benar (hitung murni di `reminder_schedule.dart`, tembak di
`ReminderService`, reschedule tiap start app sehingga tahan reboot tanpa receiver).
Tambah jalur mingguan sejajar, bukan pengganti.

1. `nextWeekly(weekday, hour, minute, now)` murni di `reminder_schedule.dart`
   (weekday 1-7 Senin-Minggu, jepit aman, tak pernah throw) + test lokal
   `dart --enable-asserts` + `test/`.
2. `ReminderService.scheduleWeekly` (id 7002, channel sama,
   `dayOfWeekAndTime`, fallback inexact) + `cancelWeekly`; `main()` jadwalkan
   ulang keduanya sesuai toggle.
3. `app_settings.dart`: `weeklyEnabled` (default false), `weeklyWeekday`
   (default 7 Minggu), `weeklyHour/Minute` (default 20:00) + setter persist.
4. `_ReminderCard`: toggle + pemilih hari + jam mingguan. Isi mingguan pakai
   fungsi pool `reminderKeyFor` yang sama (tanpa 27 kunci baru); kunci baru hanya
   label (`st_weekly_*` ID+EN).
5. Batas jujur: alarm exact butuh izin; bila ditolak, fallback inexact (bisa
   meleset, seperti harian sekarang).

File: `reminder_schedule.dart`, `reminder_service.dart`, `app_settings.dart`,
`settings_screen.dart`, `strings.dart`, `main.dart`, `test/reminder_test.dart`
(tambah case `nextWeekly`; bila file menguji schedule juga, pisahkan murni).
Uji: pure weekly 6+ case, toggle on/off menjadwalkan/membatalkan id tepat.

---

## §5. Rilis (Skema A)

Version 2.5.0+47 (perilaku baru): `pubspec.yaml` + `AppInfo.version` identik +
entri `changelog_id.md` "Yang baru di 2.5.0" paling atas + "Versi terpasang".
Satu commit `feat:` + push + `gh run watch` sampai hijau, unduh APK arm64 ke
`/sdcard/Download/SSR-SPACE/`, catat AGENTS.md + AUDIT.md §7 lokal.
Tanpa migration Supabase. Bila CI merah: fix, JANGAN amend commit gagal.

## §6. Roadmap We Space (BUKAN scope batch ini)

Ruang bersama (keluarga/tim/komunitas): role owner/admin/anggota, kas bersama
(input admin, notif ke anggota), laporan bersama. Butuh spec + plan sendiri
(RLS peran, RPC invite naik level, audit log anggota). Batch ini menyiapkan jalan:
nav Profil adalah rumah masa depan untuk menu Space, dan notif murni adalah pola
notifikasi yang dipakai ulang untuk event anggota.
