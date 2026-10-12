# Batch 31 Major: Redesign Hibrida + Logo Brand + Struk Detail + Voice Native

Tanggal: 2026-10-12. Target: `2.41.0+118`. Tanpa migration SQL baru.

## 1. Niat

User minta 4 hal: (A) redesign keseluruhan modern & konsisten,
(B) ikon dompet ala official, (C) tampilan struk super detail,
(D) voice rebuild total karena `speech_to_text` gagal di device.
Keputusan user: A=hibrida (token + 3 layar), B=logo brand,
D=native channel. Urutan eksekusi B → C → D → A.

## 2. Seksi B — Logo brand dompet

- File baru `lib/services/wallet_brand.dart` (murni Dart): keyword nama
  → `{short, color}` untuk ±15 brand (BCA, BRI, BNI, BTN, Mandiri,
  DANA, OVO, GoPay, ShopeePay, SeaBank, Jenius, Jago, Blu, CIMB,
  ISAKU). Tak cocok → null (fallback ikon tipe existing).
- Widget badge: monogram 1-2 huruf di atas warna brand, dipakai
  `WalletRow` + header detail dompet. Tanpa aset/logo trademark baru.
- Test `test/wallet_brand_test.dart` (keyword, case-insensitive,
  fallback null). Tanpa dep/migration.

## 3. Seksi C — Struk super detail

- `ReceiptData` += `address, cashier, phone, receiptNo, time, payType`
  + `ReceiptItem{name, qty, price}` (ganti `items: List<String>`?
  TIDAK: tambah `lineItems`, `items` dipertahankan kompatibel).
- Parser TDD (`receipt_parse.dart` + `test/receipt_parse_test.dart`):
  alamat (jalan/Jl/kec), kasir (keyword kasir/server), telp (pola
  telepon, bukan harga), no struk (no/bon/trx), jam (HH:MM), jenis
  bayar (`_payKey` existing → label Tunai/QRIS/E-money/Transfer).
- `receipt_result_sheet.dart` seksi: header gerai → meta (no/tgl/
  jam/kasir) → tabel item → total (subtotal/diskon/pajak/total) →
  payment → kontak. Field kosong = sembunyi (jujur, tanpa karangan).
- Tanpa dep/migration. Prefill form tetap nominal+tanggal+kategori.

## 4. Seksi D — Voice native

- Vonis riset: plugin lama butuh `<queries>RecognitionService</queries>`
  di SDK 30+ (manifest kita tak punya) + isu locale/assistant MIUI.
- File baru `lib/services/voice_native.dart` (wrapper tipis channel
  `ssr_space/voice`: `isAvailable`, `start(locale)`, `stop`,
  stream hasil parsial/final → pipeline `quick_input` existing).
- Inject CI `apk.yml`: implementasi `SpeechRecognizer` langsung
  (Kotlin+Java, pola channel widget), `<queries>` block, assert keras.
  `RECORD_AUDIO` sudah ada; permission runtime dicek sebelum start.
- Peta error jujur (unavailable/denied/no-match/timeout) + saran
  asisten default. Dep `speech_to_text` DILEPAS, `voice_input.dart`
  lama dihapus, pemanggil pindah ke wrapper baru.
- Test: mock MethodChannel di `flutter_test` (tanpa device).
- Tanpa migration. Verifikasi akhir = device user.

## 5. Seksi A — Redesign hibrida

- Token: audit `AppColors` (dead/duplikat), kunci skala spacing/tipe.
- Restruktur 3 layar: Beranda (hero + kartu), Transaksi (cari/saring/
  daftar), TxInputSheet (wizard). Layar lain ikut token saja.
- Visual-only: tanpa ubah logika/data/migration/dep. Copy UD identik.

## 6. Aturan eksekusi

- 1 commit + CI hijau per seksi (B, C, D, A). Merah → fix dulu.
- Bump sekali `2.41.0+118` di commit B (pubspec+AppInfo+changelog
  bertahap per seksi). APK final arm64 ke `/sdcard/Download/SSR-SPACE/`.
- AGENTS/AUDIT dicatat, commit docs ikut seksi terakhir.

## 7. Risiko

- D: recognizer device-specific (MIUI/default assistant). Mitigasi:
  pesan error jujur + saran setting; verifikasi device.
- A: regresi visual. Mitigasi: token dulu, diff layar per layar,
  tanpa ubah behavior.
- C: OCR rusak → field null → sembunyi (aturan lama dipertahankan).
