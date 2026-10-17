# Fase 2 Widget + Quick-Entry Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** 3 home widget Android + QS tile + shortcut + deep-link `ssrspace://quick-entry` membuka sheet catat langsung, plus share-gambar → scan struk.

**Architecture:** Pendekatan A — 1 kunci prefs per widget (existing `widget_snapshot` untouched + 2 baru); deep-link custom-scheme di-consume Dart via app_links dengan antrean prefs bila terkunci; seluruh native via inject CI apk.yml (pola SsrQsTile existing); 1 dep baru receive_sharing_intent.

**Tech Stack:** Flutter (stable) + app_links (existing) + receive_sharing_intent ^1.9.0 + CI-injected Kotlin/RemoteViews + postgres-free (prefs-lokal, tanpa migration).

**Spec:** `docs/superpowers/specs/2026-10-17-ollo-fase2-widget-design.md`

## Global Constraints

- Android saja; iOS share-extension non-goal (manual owner).
- Tanpa migration, tanpa tabel/RPC baru, tanpa domain applink (skema `ssrspace`, host `quick-entry`).
- MethodChannel `refresh` TETAP DISABLED; semua kode native baru try/catch + fail-silent.
- `android/` tidak di-commit; native hanya via inject CI `apk.yml` + assert keras.
- Tepat 1 dep baru: `receive_sharing_intent: 1.8.1` exact (1.9.0 butuh compileSdk 37).
- `flutter analyze` 0 issue (info fatal); strings baru ID+EN parity; bump Skema A + changelog; APK `*-arm64.apk` berpola `-p`.
- Adaptasi konsep saja: skema `ollo://`, merek/teks Ollo DILARANG.
- Snapshot gagal-tulis-satu tak gagalkal yang lain; toggle `widgetToday` tunggal; mask dihormati.

## Review Focus

- Ketuk widget saat logged-out/belum-workspace → buka app, antre tersimpan, tanpa crash. Test: `quickLinkReady(loggedIn:false,...)` false + `queuePending` tetap tulis (T1).
- URI rusak (skema/host/tipe salah, query ganda, null) → null, tak pernah throw (T1 parse tests).
- Pending basi >24 jam → dibuang, sheet kemarin tak terbuka (T1 expiry test).
- Berkas share hilang saat dikonsumsi → hangus + snackbar jujur, tak crash (T3 pure pick test + device).
- Snapshot korup/hilang → provider tampilkan ajakan buka app (existing null-path; T2 compat test).

---

## File Structure

- `lib/services/quick_link.dart` (BARU, murni): parse URI + antrean prefs + gate murni.
- `test/quick_link_test.dart` (BARU).
- `lib/services/widget_snapshot.dart` (UBAH): format/parse 2 varian (pakai ulang `formatSnapshot`/`parseSnapshot`/`TodaySnapshot`).
- `lib/services/today_widget.dart` (UBAH): 2 penulis baru + hapus 3 kunci saat toggle mati.
- `test/widget_snapshot_test.dart` (TAMBAH).
- `lib/services/share_intake.dart` (BARU, tipis): bungkus plugin + pilih-gambar-pertama murni (`pickFirstImage`, testable).
- `pubspec.yaml` (TAMBAH dep), wiring: `splash_screen _boot` + `main_shell` resume consume + `openTxInputSheet(initialType:)` (TANPA duplikasi sheet).
- `.github/workflows/apk.yml` (UBAH step inject): 2 provider + layout tombol + QS intent deep-link + `shortcuts.xml` + intent-filter skema + SEND image + assert keras.
- `lib/utils/strings.dart` (TAMBAH kunci), `test/strings_parity_test.dart` otomatis.
- `pubspec.yaml` + `app_info.dart` + `changelog_id.md` (rilis).

### Task 1: quick_link murni + antrean

**Files:**
- Create: `lib/services/quick_link.dart`
- Test: `test/quick_link_test.dart`

**Interfaces:**
- Consumes: `SharedPreferences` (prefs key `pending_quick_entry`).
- Produces: `String? parseQuickLink(Uri? uri)` (→ `out|in|transfer`, absen/rusak/asing → `out` bila host cocok? PUTUSKAN: spec §4.2: absen/rusak → `out`, nilai asing → `out`, skema/host salah atau null → null); `Future<void> queuePending(String type)`; `Future<String?> takePending()` (sekali-ambil + hapus; basi >24 jam → null); `bool quickLinkReady({required bool loggedIn, required bool hasOrg, required bool locked})` (true hanya bila ketiganya siap).

- [ ] **Step 1: Tulis test gagal**
  ```dart
  test('parse tipe valid', () {
    expect(parseQuickLink(Uri.parse('ssrspace://quick-entry?type=in')), 'in');
  });
  test('skema salah → null', () {
    expect(parseQuickLink(Uri.parse('https://x?type=out')), isNull);
  });
  test('pending basi dibuang', () async {
    await queuePendingAt('out', DateTime.now().subtract(const Duration(hours: 25)));
    expect(await takePending(), isNull);
  });
  ```
  + tipe absen → `out`; tipe asing → `out`; take-kedua → null; ready hanya (true,true,false).
- [ ] **Step 2: Verifikasi gagal** — Run CI `flutter test test/quick_link_test.dart`. Expected: FAIL (file belum ada).
- [ ] **Step 3: Implement** sesuai signature di atas. `queuePendingAt` test-only? JANGAN helper khusus-test di produksi — tulis via prefs mentah di test (setString manual format `{type,at}`), produksi hanya `queuePending/takePending`.
- [ ] **Step 4: Verifikasi lolos** — CI `flutter test test/quick_link_test.dart`. Expected: PASS (lokal boleh `dart --enable-asserts` bila file murni tanpa import flutter — catat bila tak bisa).
- [ ] **Step 5: Commit**
  ```bash
  git add lib/services/quick_link.dart test/quick_link_test.dart
  git commit -m "feat: deep-link quick-entry parse + antrean"
  ```

### Task 2: snapshot 2 varian + penulis

**Files:**
- Modify: `lib/services/widget_snapshot.dart`, `lib/services/today_widget.dart`
- Test: `test/widget_snapshot_test.dart` (append)

**Interfaces:**
- Consumes: `formatSnapshot/parseSnapshot/TodaySnapshot/widgetBudgetLeft` (existing); `fetchBudgetLimits`, `TransactionService().listMonth`, `topOf/isSavingCategory`, `amt/tr`, `maskAmounts/widgetToday` (existing); `WalletService`+`wallet_balance` untuk total saldo (baca service existing, jangan query mentah).
- Produces: `Future<void> refreshWidgetBudgetSnapshot(String orgId)`; `Future<void> refreshWidgetBalanceSnapshot(String orgId)`; key `widget_snapshot_budget`, `widget_snapshot_balance` (format identik § spec 4.1); toggle mati → hapus ketiga kunci.

- [ ] **Step 1: Tulis test gagal** — format budget/balance round-trip via `formatSnapshot`+`parseSnapshot`; snapshot lama tanpa text2 → text2 kosong; rusak → null; `widgetBudgetLeft` negatif (jebol) apa adanya.
- [ ] **Step 2: Verifikasi gagal** — CI `flutter test test/widget_snapshot_test.dart`. Expected: FAIL (asersi baru).
- [ ] **Step 3: Implement penulis** — tiru `refreshBudgetWidgetSnapshot`: budget = limit−spent per kategori (text) + lampu (text2); balance = total saldo (text) + jumlah-dompet/tanggal (text2); try/catch PER KUNCI; hormati mask; toggle mati → remove 3 key. Panggil dari titik yang sama dengan penulis existing (jangan bikin scheduler baru).
- [ ] **Step 4: Verifikasi lolos** — CI test. Expected: PASS.
- [ ] **Step 5: Commit**
  ```bash
  git add lib/services/widget_snapshot.dart lib/services/today_widget.dart test/widget_snapshot_test.dart
  git commit -m "feat: snapshot widget budget + saldo"
  ```

### Task 3: wiring deep-link + share-intake (Dart)

**Files:**
- Create: `lib/services/share_intake.dart`
- Modify: `pubspec.yaml`, `lib/screens/auth/splash_screen.dart` (`_boot`), `lib/screens/shell/main_shell.dart` (resume consume), pemanggil `openTxInputSheet` (1 titik consume → sheet)
- Test: `test/share_intake_test.dart` (murni: `pickFirstImage`)

**Interfaces:**
- Consumes: T1 (`parseQuickLink/queuePending/takePending/quickLinkReady`); `AppLinks().getInitialLink/uriLinkStream` (existing); `openTxInputSheet(initialType:)` (existing); `vision_scan_service` (existing); prefs `pending_share_image`.
- Produces: `({String? first, bool hadMore}) pickFirstImage(List<String> paths)` (murni: kosong → `(null, false)`; 1 → `(itu, false)`; N → `(pertama, true)`); wiring dingin (initial link + initial media) + hangat (stream).

- [ ] **Step 1: Tambah dep + tulis test gagal** — `receive_sharing_intent: 1.8.1` exact di pubspec (pin: 1.9.0 butuh compileSdk 37); test `pickFirstImage` (kosong → `(null, false)`; 1 → `(itu, false)`; 3 → `(pertama, true)`).
- [ ] **Step 2: Verifikasi gagal** — CI test. Expected: FAIL.
- [ ] **Step 3: Implement wiring** — splash `_boot` sesudah PIN+workspace: consume `takePending` bila ready → `openTxInputSheet(initialType)`; `uriLinkStream` → parse → ready? langsung : queue; MainShell resume → coba consume; share: initial+stream → gambar pertama → scan → prefill sheet (TANPA auto-save); multi → snackbar `wg_share_first`; terkunci → queue path, berkas hilang → hangus + snackbar; `reset()` sesudah proses. Tanpa duplikasi sheet/scan.
- [ ] **Step 4: Verifikasi lolos** — CI analyze+test. Expected: PASS.
- [ ] **Step 5: Commit**
  ```bash
  git add lib/services/share_intake.dart test/share_intake_test.dart pubspec.yaml lib/screens/auth/splash_screen.dart lib/screens/shell/main_shell.dart
  git commit -m "feat: deep-link + share-intake wiring"
  ```

### Task 4: native inject (provider + tombol + QS + shortcut + filter)

**Files:**
- Modify: `.github/workflows/apk.yml` (step inject saja)
- Test: assert keras di step (gagal = merah eksplisit); kompilasi native = bukti

**Interfaces:**
- Consumes: T1 (URI exact `ssrspace://quick-entry?type=out|in`); T2 (key `flutter.widget_snapshot_budget`, `flutter.widget_snapshot_balance` — prefix `flutter.` pola existing).
- Produces: provider `budget_widget`+`balance_widget` (+info 30 mnt), tombol Catat Keluar/Masuk di 3 layout (PendingIntent VIEW URI, explicit package, immutable, try/catch), QS onClick → deep-link out, `shortcuts.xml` 1 item, intent-filter skema + SEND/SEND_MULTIPLE image/*, assert keras tiap artefak.

- [ ] **Step 1: Tulis inject** — tiru blok provider/QS existing baris ~500-640: duplikasi terpola untuk 2 provider; tombol via `setOnClickPendingIntent` + `Intent(VIEW, Uri.parse(...))` + `setPackage`; QS ganti launch-intent → deep-link intent; shortcuts.xml + meta-data; filter skema (VIEW/DEFAULT/BROWSABLE, scheme=ssrspace host=quick-entry) + SEND image (single+multiple); assert: grep Manifest hasil untuk tiap provider/activity-alias/filter/shortcuts meta.
- [ ] **Step 2: Verifikasi** — CI `build-apk` (analyze+test lolos + Gradle kompilasi native). Expected: hijau. Tanpa commit terpisah untuk coba-coba — amalkan sekali, perbaiki bila merah dengan vonis log.
- [ ] **Step 3: Commit**
  ```bash
  git add .github/workflows/apk.yml
  git commit -m "feat: native widget budget/saldo + tombol catat + QS + shortcut"
  ```

### Task 5: strings + rilis

**Files:**
- Modify: `lib/utils/strings.dart`, `pubspec.yaml`, `lib/utils/app_info.dart`, `assets/changelog_id.md`

**Interfaces:**
- Consumes: semua Task 1-4 hijau.

- [ ] **Step 1: Strings + bump + changelog** — kunci `wg_budget_title`, `wg_balance_title`, `wg_balance_total`, `wg_share_first`, `wg_locked_queued`, `ql_invalid_ignored` (ID+EN; pakai ulang `wg_out_today`/`wg_budget_left`; label shortcut statis "Catat" tanpa kunci); versi + changelog (aturan Skema A).
- [ ] **Step 2: CI hijau penuh** — push branch → kedua workflow hijau (dipicu manual `workflow_dispatch --ref` bila bukan main, seperti fase 1).
- [ ] **Step 3: APK + device checklist** — unduh `-p "SSR-SPACE-<ver>-arm64.apk"` (bila putus: `curl -C -` resume hingga byte-pas + `testzip`); checklist spec §4.6.
- [ ] **Step 4: Commit rilis**
  ```bash
  git add lib/utils/strings.dart pubspec.yaml lib/utils/app_info.dart assets/changelog_id.md
  git commit -m "chore: bump <ver> widget + quick-entry"
  ```
