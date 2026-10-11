# Dashboard Baru Beranda (Batch 16) — Design

Tanggal: 2026-10-11. Jalur: architectural (spec → plan → implement).
Putusan: 4 tab tetap + seksi dashboard di dalam Beranda (pendekatan A).

## 1. Tujuan

Semua fitur (patungan, utang-piutang, langganan, target nabung, NFC,
pelacakan, dompet, tagihan) mudah dijangkau dari Beranda tanpa mengubah
navigasi bawah. Referensi: Wallet/Spendee (kartu bisa diatur), YNAB
(lampu hijau/kuning/merah per budget), Spendee (progress bar infografis).

Non-tujuan v1: layar dashboard terpisah, grid drag + dep baru, ringkasan
langganan (butuh query 4 bulan — ditolak YAGNI), ubah tab/FAB/Profil.

## 2. Arsitektur

- Hero surplus tetap paling atas (jangkar, tak ikut susun).
- Di bawah hero: header seksi "Dashboard" + tombol Susun.
- Kartu dashboard dirender sesuai `dashboard_order` (prefs, pola
  `reports_section_order`): `budget`, `fitur`, `utang`. Tak dikenal =
  dibuang (fail-open); kosong = default.
- Mode Susun: tiap kartu tampil panah ↑↓ + ikon mata (sembunyi). Kartu
  tersembunyi dirender redup di mode Susun dengan tombol tampilkan.
- Tanpa migration, tanpa dep baru, tanpa query server baru.

## 3. Kartu

### 3.1 Budget traffic-light (`budget`)

- Data: `limits` + `spent` yang sudah dipegang `_load` Beranda.
- Top-3 kategori by belanja. Lampu per kategori: hijau bila
  spent < warnPct% limit; emas bila ≥ warnPct; bata bila ≥ 100%.
  Ambang ikut `warnPct` tiap budget (konsisten kartu pace).
- Baris: dot + nama + `terpakai/limit` + persen tabular. Ketuk kartu →
  tab Budget. Tanpa budget → baris CTA "Buat budget" → tab Budget.

### 3.2 Fitur (`fitur`)

- Grid 4×2 ikon + label: Dompet, Tagihan, Langganan, Patungan, Utang,
  Target, NFC, Lacak. Tiap tile deep-link ke layar existing
  (Wallets, RecurringBills, Subscriptions, BillSplits, Debts, Goals,
  NfcCards, NotifSettings). Nol logika baru.
- Ikon: `AppIcons` existing (wallet, bills, calendar, transfer,
  billing, topup, scan, tracking).

### 3.3 Utang ringkas (`utang`)

- Data: `loadDebts()` prefs-lokal (tanpa server) + `debtTotals`.
- Isi: total sisa utang vs piutang + progres lunas. Ketuk → DebtsScreen.
- Tanpa catatan → baris CTA "Catat utang" → DebtsScreen.

## 4. File

- Baru: `lib/services/dashboard_cards.dart` (registri id, codec order,
  geser, sembunyi — murni), kartu UI di
  `lib/screens/beranda/dashboard_cards.dart` (atau seksi dalam
  `beranda_screen.dart` bila <50 baris per widget).
- Ubah: `beranda_screen.dart` (`_content` render via order + mode Susun
  + state prefs), `strings.dart` (kunci `dash_*` — dashboard, susun,
  tampil, sembunyi, buat-budget, dst. ID+EN; `db_*` sudah milik utang),
  `app_info.dart` (2.28.0+102), `changelog_id.md`.
- Test: `test/dashboard_cards_test.dart` (codec, geser batas, buang id
  asing, klasifikasi lampu).

## 5. Dark mode

Nol warna hardcoded di kode baru: hanya `colorScheme` + token
`AppColors` existing (emerald/gold/rust sudah sadar-tema + terukur AA).
Verifikasi visual light+dark di device oleh user (CI tak bisa screenshot).

## 6. Error & edge

- Prefs rusak → order default. Kartu gagal hitung → sembunyi (fail-open),
  hero + recent tak terpengaruh.
- `mounted` guard tiap setState pasca-await (pola repo).
- `flutter analyze` 0 issue (info = fatal), test hijau, APK arm64.

## 7. Kriteria selesai

CI hijau (analyze→test→build), APK `SSR-SPACE-2.28.0-102-arm64.apk` di
`/sdcard/Download/SSR-SPACE/`, changelog + AGENTS/AUDIT lokal.
Verifikasi device: susun kartu tersimpan antar-restart, lampu benar di
light+dark, semua tile terbuka ke layar yang benar.
