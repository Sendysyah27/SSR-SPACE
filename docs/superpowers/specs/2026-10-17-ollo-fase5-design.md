# Fase 5 Design: Update Log, i18n Penuh, Multi-Currency

Tanggal: 2026-10-17
Status: In Progress

## Ringkasan
Fase 5: rm-update-log (done), rm-i18n (done), rm-multicurrency (done).

## 1. Update Log
- Layar sudah ada: lib/screens/lainnya/update_log_screen.dart
- Tandai done di assets/roadmap_id.json

## 2. i18n
- strings.dart: 1205 keys, semua ID+EN lengkap (terverifikasi)
- Audit hardcoded strings di layar utama

## 3. Multi-Currency
- Baru: lib/utils/currency.dart (AppCurrency, supportedCurrencies, formatMoney)
- Wallet.currency field (default IDR)
- wallet_service.create() terima currency param
- Currency picker di form dompet
- Migration: wallets.currency TEXT DEFAULT IDR (manual user)
- TIDAK: konversi kurs otomatis, laporan gabungan
- Test: test/currency_test.dart

## Tokens
bg #EAF0F8, putih, biru #5B9BF5, navy #12285A. DILARANG ungu/indigo.