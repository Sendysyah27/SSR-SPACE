# Design: Profile Settings lengkap + Slim APK - 2026-09-26

Keputusan user: fondasi Profile dan Settings berkatalog ala Ollo (referensi alur saja, tanpa salin kode/aset), plus diet APK dari 65 MB fat ke splits per-ABI.
Pendekatan B: iris vertikal bertahap, tiap iris CI hijau. Antislop mode DURING.
Klarifikasi terkunci: reminder pakai dep asli, impor full tambah catatan, artefak universal plus splits.

## 1. Batas Ollo (referensi, bukan salinan)

Adopt: katalog settings searchable, 4-beat onboarding rhythm (SSR sudah punya, tinggal rapikan visual), bento home reorderable (persist order), pola sync status icon, filter bar laporan, Top-N plus Others, correction-capture (SSR sudah punya overlay 30 detik plus pending sheet, poles saja).
Jangan adopt sekarang: AI assistant, voice/scan/chat quick-record, OCR/ML Kit (tambah sekitar 10 MB native, batal diet), widget provider native penuh (P2), wishlist/reimburse/split-bill/AI chat/receipt OCR (backlog saja).
SSR tetap unggul: auto-track notifikasi bank/dompet (Ollo tak punya, jangan pernah hapus), multi-user org plus RLS (Ollo masih roadmap, pertahankan).

## 2. Hub Profile (OtherScreen tetap entry point)

Regroup tanpa ubah nav 5 tab dan tagline:
HEADER (user email, org aktif, chip plan, status akun/sync), DATA (Wallets, Categories, Budgets, link riwayat Transaksi), PELACAKAN (notif_settings existing, toggle koreksi overlay existing), DATA DAN CADANGAN (Backup 3-CSV existing, Export CSV/PDF existing, Impor CSV baru minimal, Hapus cache lokal baru), WORKSPACE (Invite, Switch, Detail read-only bila RPC tak ada, fail-open dengan pesan), TAMPILAN (baru, prefs), BAHASA DAN UANG (extend SettingsScreen), PENGINGAT DAN WIDGET (baru minimal), KEAMANAN (extend), TENTANG DAN MASUKAN (statik).
Aturan: nol dead tap. Tiap baris buka layar/dialog nyata atau pesan P2 jelas. Empty/loading/error di tiap layar daftar. Reuse SectionCard, NavTile, StatusChip, LabeledSectionCard. Cek lib/widgets sebelum bikin baru. build() di bawah 50 baris via ekstraksi private.

## 3. Prefs dan strings

Kunci baru di lib/services/app_settings.dart, defaults fail-safe, load saat start seperti maskAmounts, baca via notifier:
ui_anims (true), ui_list_style (comfortable), ui_date_style (system), ui_hero_style (emerald-calm dalam DESIGN.md), home_menu_order (list id), input_default_currency (IDR), reports_topn (true), reminder_enabled (false), reminder_hour/minute (07/00), widget_today (false stub).
Strings ID plus EN di lib/utils/strings.dart via tr(). Angka PDF tetap IDR. Money tampil via amt(), harga plan tetap rp(). Copy user hanya Indonesia (EN hanya opsi locale yang sudah ada).

## 4. Impor CSV (threat model dulu)

Boundary: file CSV dari user adalah input hostile. Abuse: formula (=CMD, +CMD, -CMD, @), delimiter campur (; , tab), quote rusak, header case acak, nominal ID (1.234,50) vs EN (1,234.50) vs Rp prefix, tanggal dd/MM/yyyy vs ISO vs yyyyMMdd, tipe tak dikenal, wallet tak cocok, kategori asing, duplikat, baris kosong.
Flow terkunci: pilih file, mapping kolom (tanggal, nominal, tipe, dompet asal, dompet tujuan opsional, kategori, catatan), mapping kategori ke kategori global (fallback Lainnya), preview 5 baris plus daftar error, baru tulis via TransactionService.add per baris (jalur resmi, gagal satu baris tak burn TX-code, lanjut baris valid, ringkasan sukses/gagal di akhir).
Logika murni lib/services/csv_import_logic.dart (tanpa Supabase di dalam): deteksi delimiter, parse quote, normalisasi header, parse amount, parse date, parse type, neutralize formula (prefix apostrof saat export/preview, tolak eksekusi), validasi wallet/category, kumpulkan error per baris. Target min 12 assert lokal dart dulu lalu test/csv_import_test.dart untuk CI. Tanpa tabel/RLS baru. Gate _onEvent tak disentuh.

## 5. Reminder harian

lib/services/reminder_service.dart wrapper tipis: jadwal exact harian timezone-aware, persist reboot via plugin, OFF default, jam pilih user. Izin notif biasa, bukan listener baru. Copy tenang (tanpa streak judi, tanpa badge ramai). Varian copy harian masuk Phase-2 spec. Size impact dicatat di PR (delta sebelum/sesudah dep). Bila diet jebol di CI, fallback disepakati: settings tetap ada, scheduling jadi P2, tanpa debat ulang.

## 6. Search, statik, hapus cache

settings_search_delegate cari judul ID plus EN semua baris seksi 2. update_log_screen.dart statik baca assets/changelog_id.md bundel. About dialog statis pakai AppInfo.version. Help dan Privacy dialog statis. Feedback via share sheet, Share via teks share_plus. Hapus cache lokal: hapus prefs/overlay/pending_correct_tx saja, tak pernah hapus data Supabase, konfirmasi dulu, pesan sukses jelas.

## 7. Slim-APK (urut, diukur)

1. Ukur dulu: catat size apk release, unzip -l top-30, bobot lib/ per ABI, assets/, fonts/. Baseline lapor: 65 MB fat.
2. Splits: pertahankan universal sideload, tambah split-per-abi (arm64-v8a daily driver, armeabi-v7a, x86_64), nama jelas, plus size-report step di apk.yml (ls -lh plus top entries) agar tiap run tampil dietnya. Opsional appbundle untuk Play nanti, tak wajib fase ini.
3. Shrink aman: minify/shrinkResources via patch CI (pola sama seperti patch BigText, android/ tetap tak di-commit), keep-rules untuk notification_listener_service, flutter_overlay_window, flutter_foreground_task, supabase, local_auth, flutter_local_notifications. Verifikasi smoke rilis sebelum klaim selesai.
4. Diet dep/aset: audit pubspec (sqflite/path dipertahankan hanya bila dipakai nyata, tulis alasan di PR), subset/defer font Fraunces/Phosphor yang tak dipakai layar, kompres illustrations/lottie, tanpa ML Kit/OCR di fase ini.
5. Catatan jujur: Ollo kecil saat download karena Play Bundle splits, total install tetap sekitar 65 MB. SSR ikut pola itu: download per-device mengecil, tanpa janji angka ajaib. Target PR: tabel baseline 65 MB lawan arm64 baru plus universal baru.
6. Guardrail: tanpa ubah gate auto-track, session/PIN, RLS, TX-code. Smoke: install arm64, login, ganti workspace, event auto-track, koreksi overlay, backup share, reminder bunyi plus persist reboot.

## 8. File plan (tepat, tanpa buat sebelum approval kode)

Ubah: lib/screens/lainnya/other_screen.dart (regroup seksi), lib/screens/lainnya/settings_screen.dart (kartu baru: default currency, Top-N toggle, anims, list style, date style, reminder time, widget stub, reset correction memory), lib/utils/strings.dart (kunci baru), lib/services/app_settings.dart (kunci plus notifier), lib/services/backup_export.dart (hanya bila preview butuh helper, prioritas file murni baru), .github/workflows/apk.yml (splits plus size-report plus keep-rules), pubspec.yaml (hanya flutter_local_notifications plus timezone setelah cek size), DESIGN.md (hanya bila varian hero butuh kalimat baru dalam palet).
Baru maks: lib/screens/lainnya/import_preview_screen.dart, lib/screens/lainnya/update_log_screen.dart, lib/services/csv_import_logic.dart plus test/csv_import_test.dart, lib/services/reminder_service.dart, assets/changelog_id.md.
Larang: tabel/RLS baru fase ini, logika listener baru, font/paket baru selain dua itu, aset Ollo apa pun, insert transactions langsung (wajib via service).

## 9. Testing dan acceptance

Murni dulu lokal dart (mapping CSV, defaults prefs, Top-N grouping, reminder math), pola repo transfer_detect/input_logic. CI: analyze 0 issue, test hijau, per-ABI build, tabel size diff. Manual device tiap layar sentuh: copy Indonesia, mask toggle, font 0.85/1.3, state kosong/muat/gagal, klik semua kontrol.
Acceptance wajib: semua baris hidup, search temukan tiap baris ID plus EN, impor preview 5 baris plus error sebelum tulis, reminder exact plus reboot persist dan OFF default, analyze/test hijau dengan min 10 assert baru, DESIGN.md patuh, build() kecil, money via amt(), mask-aware.

## 10. Phase-2 (spec only, tak dikode di tugas ini)

Satu pager tiap item (problem, pola Ollo, adaptasi SSR, data/prefs, edge, daftar test, dampak Supabase/RLS atau tanpa migration): recurring bills auto-generate, varian copy reminder, today-expense widget plus QS tile (catat kerja native provider P2), paket SVG dompet redrawn, subkategori plus color/icon picker, reports Top-8 plus Others plus reorderable sections, calm streak (tanpa nuansa judi).

## 11. Bukan scope

Fitur uang baru (wishlist, reimburse, split-bill, AI chat, OCR struk), ubah RLS/policy, ubah gate _onEvent, ubah nav/tab/tagline, salin aset Ollo, klaim angka tanpa sumber.

Rollout: iris 1 sampai 4 berurutan, tiap iris push plus CI hijau. Docs AGENTS.md plus AUDIT.md update lokal saja, ikut commit kode berikutnya, tanpa commit docs-only. APK final ke /sdcard/Download/SSR-SPACE/ dengan nama jelas.

## 12. Visual (Design Read plus alasan R-31)

Read: layar utilitas keuangan untuk pemakai Indonesia, bahasa visual Fintech Ledger kertas/zamrud, dial ENERGY 1 / RHYTHM 2 / MOTION 1.
Alasan per keputusan: hero emerald-calm agar uang jadi fokus tunggal; hairline ledger agar identitas produk terasa; StatusChip lama agar tanpa badge baru; list comfortable default agar baris transaksi lega di 360dp; animasi off-able agar hemat di HP lama; search agar katalog panjang tetap temu dalam 2 ketuk; tanpa angka/klaim baru selain data real (R-17).
