# Scan Struk + Wizard Catat 2 Langkah — Design

Tanggal: 2026-09-29. Status: disetujui user ("gass").
Keputusan: ML Kit on-device, preview-prefill (tanpa auto-save), workflow
kategori-dulu, reuse SVG ledger (nol aset baru), antislop DURING.

## 1. Latar

Contoh struk user (Indomaret, 11 & 15 Agu 2026, dari SS Photos):
`TOTAL BELANJA : 172,300` / `507,600` jelas; pengecoh `HARGA JUAL`,
`DPP/PPN`, `NON TUNAI`, `PURCHASE:172,300`; tanggal badan terpotong kiri
(`1.08.26`, `5.08.26`); overlay timestamp kamera wajib diabaikan; struk 2
terhalang scanner + struk ganda (item parsial).

## 2. Arsitektur

```
Langkah 1 sheet > [Scan] > image_picker (kamera/galeri, maxWidth 1600)
  > ML Kit Latin on-device > teks mentah
  > receipt_parse.dart (murni, nol import) > ReceiptData
  > prefill Langkah 2 (nominal, tanggal, merchant+item di catatan)
  > user tekan Simpan (validasi + gate lama tak berubah)
```

Tanpa backend, tanpa API key, tanpa upload, foto dihapus setelah parse.
Keyakinan rendah → chip peringatan inline, field tetap editable (fail-open).

## 3. Parser (`lib/services/receipt_parse.dart`, murni)

- `ReceiptData { amount: double?, date: DateTime?, merchant: String?,
  items: List<String>, voucher: double?, confident: bool }`.
- Total: baris mengandung `TOTAL|TOT |JUMLAH|BAYAR|GRAND` + nominal;
  tolak baris `KEMBALI|TUNAI|DPP|PPN|HARGA JUAL|PURCHASE`. Ambil nominal
  terbesar bila >1 kandidat. Format `172,300` koma-ribuan + `Rp` didukung
  (pakai normalisasi ala `quick_input_parse`, tanpa import: duplikasi
  ~20 baris fungsi dinilai lebih murah dari coupling).
- Tanggal: regex `\d{1,2}[./-]\d{1,2}[./-]\d{2,4}`, ambil match terakhir;
  2-digit tahun → 20xx. Null → form default hari ini.
- Merchant: baris pertama cocok `^[A-Z0-9 .,&-]{4,30}$`; override
0 bila mengandung `INDOMARET|ALFAMART|ALFAMIDI`.
- Item: `nama qty harga total` (4 kolom) atau `nama + angka akhir`;
  maks 8; baris `VOUCHER...(x)` → `voucher`, bukan item.
- `confident = amount != null && amount > 0`.
- `receiptNote(d)`: `{merchant} · item1, item2 (+N)` cap 200 char.

## 4. Wizard `TxInputSheet`

- State `_step` (0/1) + `_selCat`. Mode edit → `_step = 1` langsung.
- Langkah 1: `TxTypeSelector` + grid 2 kolom (ikon `svgForCategory`,
  selected = fill primer 8% + outline; sel seragam = pilihan setara,
  alasan R-14) + baris scan (`OutlinedButton.icon` kamera + hint) +
  `PrimaryButton` Lanjut (mati bila kategori null) + error scan inline.
- Langkah 2: form existing TANPA `TxTypeSelector` (tipe dari langkah 1,
  chip kecil + link Ubah kembali); `_MetaSection` tetap (editable).
- Scan sukses → `type='out'`, digits, day, note terisi; kategori =
  pilihan langkah 1 bila ada, else `Belanja`; maju ke langkah 2.
- State scan R-27: idle / scanning (`LinearProgressIndicator` +
  `rcp_scanning`) / gagal (`rcp_fail` + tombol Ulangi + isi manual bisa).
  Dialog pilih Kamera/Galeri via `AlertDialog` 2 aksi.

## 5. Service (`lib/services/receipt_scan_service.dart`)

`scanReceipt(ImageSource)` → `Future<ReceiptData>`, throw
`ReceiptScanException(trKey)` bila: bukan Android/iOS, picker null
(user batal → return null, bukan error), ML Kit gagal, teks kosong.
File foto dihapus di `finally`.

## 6. Strings (`rcp_*`, `wiz_*`, ID+EN)

`wiz_type_cat`, `wiz_need_cat`, `wiz_next`, `wiz_back`, `wiz_change`,
`rcp_scan`, `rcp_scan_hint`, `rcp_camera`, `rcp_gallery`,
`rcp_scanning`, `rcp_fail`, `rcp_partial`, `rcp_empty`.

## 7. Dep & platform

`image_picker: ^1.1.2`, `google_mlkit_text_recognition: ^0.15.0`.
image_picker pakai intent kamera sistem → tanpa izin CAMERA di Manifest,
tanpa ubah `apk.yml`. minSdk 26 memenuhi syarat ML Kit (21+).
Catat delta ukuran APK arm64 di laporan (baseline 24.4M).

## 8. Test & verifikasi

`test/receipt_parse_test.dart` (10 assert, teks struk asli anonim):
total koma-ribuan, tolak KEMBALI/DPP/HARGA JUAL, tanggal terpotong,
merchant, item 4-kolom, voucher, confident false bila tanpa total.
Parser nol import → verifikasi lokal `dart --enable-asserts` sebelum push.
Full: CI analyze (0 issue, info fatal) → test → APK.

## 9. Batas sadar

Nama barang singkatan kasir apa adanya (tanpa kamus); tulisan tangan
rusak/miring ekstrem → fallback isi manual; dompet tetap Most-used
(tak ditebak dari `SHOPEEPAY-TRXID`); foto struk orang = olah lokal saja.
Version `2.8.0+50` (fitur baru → minor).
