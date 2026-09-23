# SSR SPACE — Design Spec (2026-09-23)

**Nama:** SSR SPACE
**Tipe:** Aplikasi Android pencatatan pengeluaran & pemasukan
**Pendekatan disetujui:** A Flutter + sqflite offline + GitHub Actions APK
**Storage:** Offline penuh (SQLite lokal, tanpa login server)
**Eksekusi:** via gh CLI

## 1. Arsitektur
Flutter (stable) + sqflite + shared_preferences + flutter_secure_storage.
State: Riverpod atau Provider (pilih Riverpod). Grafik: fl_chart.
Export: csv + pdf + share.
Struktur lib/: main.dart, core/session, core/db, models, screens, widgets.

## 2. Sesi Awal Enterprise-Grade (wajib user)
Alur buka aplikasi pertama kali vs berikutnya, profesional:

1. **Splash / Bootstrap (AppInitializer):**
   - Init DB + migrasi, cek isFirstRun, cek PIN terdaftar, buat sessionId (uuid), catat openedAt.
   - Timeout 10 dtk, error screen + retry bila DB gagal.
2. **First-run Onboarding (sekali saja):**
   - Step 1 profil: nama + mata uang default (IDR).
   - Step 2 dompet awal: Cash + contoh Bank/Dana (bisa edit/hapus).
   - Step 3 kategori default seeding: 12 pengeluaran + 5 pemasukan.
   - Step 4 keamanan: buat PIN 6 digit (confirm 2x) + opsi biometrik, simpan hash SHA-256+salt di secure_storage.
   - Tandai onboardingDone=true, buat audit log `onboarding_completed`.
3. **Lock / Session Gate (setiap buka):**
   - Jika PIN ada → PIN/biometrik unlock. Max 5 salah → lockout 60 dtk progresif.
   - Session: sessionId, unlockAt, lastActiveAt. Auto-lock 5 mnt background → foreground wajib re-auth.
   - Logout/kunci manual dari drawer.
4. **Audit & keamanan:**
   - Tabel audit_logs: sessionId, event, createdAt.
   - PIN tidak plaintext, hanya hash+salt. DB lokal, backup file terenkripsi opsional tahap 2.

## 3. Layar / Fitur Lengkap + Multi-dompet
- Dashboard: total saldo semua dompet, pemasukan/pengeluaran bulan ini, grafik garis + pie kategori, 5 transaksi terakhir.
- Transaksi: tambah/edit/hapus, tipe in/out/transfer, dompet asal/tujuan, kategori, tanggal, catatan, nominal validasi >0.
- Dompet: CRUD (Cash, Dana, Bank...), saldo auto-hitung, transfer antar dompet = 2 leg atomik dalam transaksi DB.
- Kategori: CRUD + ikon, default seeding.
- Budget: per kategori per bulan, progress bar, warning 80%/100%.
- Laporan: filter tanggal/dompet/kategori, rekap, export CSV/PDF + share.

## 4. Data Model (SQLite v1)
- wallets(id, name, type, balance_cached, created_at)
- categories(id, name, type in/out, icon, is_default)
- transactions(id, type in/out/transfer, amount, wallet_id, to_wallet_id nullable, category_id nullable, date, note, session_id, created_at)
- budgets(id, category_id, month YYYY-MM, limit_amount)
- meta(key,value): onboardingDone, currency, PIN hash disarankan di secure_storage bukan meta
- audit_logs(id, session_id, event, created_at)
- Migrasi: version 1 create all + seed; versi berikutnya ALTER.

## 5. Build via gh CLI
- Repo GitHub: SSR-SPACE (private/public pilihan user).
- Workflow .github/workflows/apk.yml: on push main, setup-java 17 + flutter stable, flutter pub get, flutter test, flutter build apk --release, upload-artifact app-release.apk.
- Di Termux: gh repo create, git push, gh run watch, gh run download.
- Final copy APK + source zip ke /sdcard/Download/SSR-SPACE/.

## 6. Testing
flutter test: session_service (first-run, PIN hash, lockout), db transfer atomik, saldo kalkulasi, budget warning.
Manual: fresh install → onboarding → lock → tambah transaksi → transfer → export.
