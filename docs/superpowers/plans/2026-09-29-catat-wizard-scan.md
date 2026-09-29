# Wizard Catat + Scan Struk Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Wizard catat 2 langkah (jenis+kategori dulu, baru form) dengan scan struk ML Kit yang prefill form via preview.

**Architecture:** Parser murni `receipt_parse.dart` (nol import, TDD via `dart --enable-asserts` lokal); service tipis `receipt_scan_service.dart` (image_picker + ML Kit); refactor `tx_input_sheet.dart` tambah `_step`; strings `wiz_*`/`rcp_*`; 2 dep baru; bump `2.8.0+50`.

**Tech Stack:** Flutter stable, `image_picker ^1.1.2`, `google_mlkit_text_recognition ^0.15.0`, flutter_test di CI.

**Spec:** `docs/superpowers/specs/2026-09-29-catat-wizard-scan-design.md`

## Global Constraints

- `flutter analyze` 0 issue (info = fatal, termasuk `prefer_const_constructors`, `dangling_library_doc_comments`).
- Nominal via `amt()`/`CurrencyService`, tabular figures; copy Indonesia via `tr()` ID+EN, tanpa em dash.
- Tanpa migration, tanpa backend/key, tanpa aset baru (reuse `svgForCategory`), tanpa baca `platformBrightness` di widget.
- Token ledger: gold bukan aksen di wizard; selected = fill primer 8% + outline.
- `pubspec.yaml` dan `AppInfo.version` identik; entri `assets/changelog_id.md`.
- Verifikasi parser lokal: `dart --enable-asserts <scratch>` sebelum push.

---

### Task 1: Parser murni + test

**Files:**
- Create: `lib/services/receipt_parse.dart`
- Create: `test/receipt_parse_test.dart`

**Interfaces:**
- Consumes: nothing.
- Produces: `class ReceiptData { double? amount; DateTime? date; String? merchant; List<String> items; double? voucher; bool confident; }`, `ReceiptData parseReceipt(String raw)`, `String receiptNote(ReceiptData d)`.

- [ ] **Step 1: Tulis test gagal** — `test/receipt_parse_test.dart` (import `flutter_test` + parser): total `172,300` dari blok TOTAL; tolak KEMBALI `5,000` dan HARGA JUAL; tanggal `15.08.26`; merchant `INDOMARET`; 3 item; voucher `2,200`; confident false tanpa total; note cap 200 char. 10 expects.
- [ ] **Step 2: Verifikasi gagal lokal** — `dart --enable-asserts` scratch import file parser (tanpa flutter_test) + `flutter test` di CI nanti. Expected: FAIL "file not found".
- [ ] **Step 3: Implementasi minimal** — `receipt_parse.dart` nol import sesuai Spec §3.
- [ ] **Step 4: Verifikasi lolos lokal** — scratch `dart --enable-asserts` 10/10 PASS.
- [ ] **Step 5: Commit** — `git add lib/services/receipt_parse.dart test/receipt_parse_test.dart && git commit -m "feat: parser struk murni + test"` (commit lokal, push di akhir).

### Task 2: Strings + deps + service scan

**Files:**
- Modify: `lib/utils/strings.dart` (tambah 14 kunci `wiz_*`/`rcp_*` ID+EN)
- Modify: `pubspec.yaml` (+2 dep)
- Create: `lib/services/receipt_scan_service.dart`

**Interfaces:**
- Consumes: `parseReceipt`, `tr()`.
- Produces: `class ReceiptScanException { String trKey; }`, `Future<ReceiptData?> scanReceipt(ImageSource source)` (null = user batal).

- [ ] **Step 1: Strings** — 14 kunci ID+EN, tanpa em dash, placeholder `{n}` bila perlu.
- [ ] **Step 2: Deps** — `image_picker: ^1.1.2`, `google_mlkit_text_recognition: ^0.15.0` alfabetis di block dependencies.
- [ ] **Step 3: Service** — picker `maxWidth: 1600, imageQuality: 80`; `TextRecognizer(script: RecognisedScript.latin)`; `processImage(InputImage.fromFilePath)`; `finally` hapus file; map error → `ReceiptScanException('rcp_fail'|'rcp_empty')`.
- [ ] **Step 4: Analyze-grep** — pastikan tak ada import flutter di parser; service import flutter+N/A guard `Platform.isAndroid/iOS`? (iOS didukung ML Kit; desktop → throw `rcp_fail`).
- [ ] **Step 5: Commit** — `git add -A && git commit -m "feat: strings scan + service ML Kit"`.

### Task 3: Wizard UI

**Files:**
- Modify: `lib/widgets/tx_input_sheet.dart` (state `_step`, `_selCat`, `_scanState`; widget `_StepOne`, `_ScanRow`; dialog sumber; langkah 2 tanpa `TxTypeSelector` + chip tipe + Ubah)

**Interfaces:**
- Consumes: `scanReceipt`, `svgForCategory`, `appCategories`, `TxTypeSelector`, `PrimaryButton`.
- Produces: perilaku: baru → step 0; edit → step 1; Lanjut butuh kategori; scan sukses → prefill + step 1.

- [ ] **Step 1: State + langkah 1** — `_step`, `_selCat` (init dari editing/initialCategory), `_StepOne` grid 2 kolom + scan + Lanjut.
- [ ] **Step 2: Alur scan** — dialog Kamera/Galeri → `_scanState=scanning` → sukses prefill (type out, digits, day, note, kategori fallback `Belanja`) + step 1; gagal → error inline; batal → diam.
- [ ] **Step 3: Langkah 2** — pindah `TxTypeSelector` keluar, tambah chip tipe + Ubah; form lain utuh.
- [ ] **Step 4: Cek analyze-lokal** — `dart analyze` tak ada; baca ulang diff cari `const`+`tr()` campur, import tak dipakai.
- [ ] **Step 5: Commit** — `git commit -m "feat: wizard catat 2 langkah + scan struk"`.

### Task 4: Rilis

**Files:**
- Modify: `pubspec.yaml` (2.8.0+50), `lib/utils/app_info.dart`, `assets/changelog_id.md`, `AGENTS.md`, `AUDIT.md` (lokal)

**Interfaces:** Produces: APK arm64 di `/sdcard/Download/SSR-SPACE/`.

- [ ] **Step 1: Bump + changelog.**
- [ ] **Step 2: Push + pantau** — `git push origin main`, `gh run watch --exit-status`.
- [ ] **Step 3: Unduh APK arm64** → `/sdcard/Download/SSR-SPACE/`, catat delta size vs 24.4M.
- [ ] **Step 4: Docs lokal** — AGENTS.md + AUDIT.md §7.
