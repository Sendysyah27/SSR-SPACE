# Spec Fase 2 — Widget + Quick-Entry Suite (adaptasi konsep Ollo)

> Tanggal: 2026-10-17 · Status: **APPROVED owner (scope)** → menunggu review spec.
> Lanjutan kickoff `docs/prompts/2026-10-16-ollo-adapt-kickoff.md` fase 2.
> Referensi perilaku (jangan dikutip mentah): `LAPORAN-ollo.md` baris 44-45,
> 149-152, 189; `fitur.json`; 12 SS `docs/reference/ollo-screenshots/`.
> Adaptasi konsep saja: tanpa merek/aset/teks/skema Ollo (`ollo://` DILARANG).

## 1. Tujuan & kriteria sukses

- 3 widget home Android: Hari-ini (existing) + Budget + Saldo — angka dari
  prefs-lokal, tap tombol → sheet catat langsung (bukan sekadar buka app).
- QS tile + shortcut icon → sheet catat langsung (tipe keluar default).
- Share gambar dari app lain → scan struk → prefill sheet (tanpa auto-save).
- Sukses = CI hijau (analyze 0 issue + test + kompilasi native APK),
  APK arm64, perilaku jujur saat terkunci/offline/belum-login
  (antre, bukan gagal diam-diam; tak pernah blokir buta).

## 2. Batasan

- Android saja. iOS share-extension butuh Xcode (tak ada di CI APK) → non-goal,
  dicatat sebagai langkah manual owner bila perlu.
- Backend SEMUA existing (Supabase read-only via service yang ada);
  **tanpa migration, tanpa tabel/RPC baru, tanpa domain applink**
  (skema custom `ssrspace://`, tanpa `assetlinks.json`).
- Aturan FC 2.13.1: semua kode native baru try/catch Throwable + fail-silent;
  MethodChannel `refresh` TETAP DISABLED (provider baca prefs periodik saja).
- `android/` tidak di-commit — seluruh native via inject CI `apk.yml`
  (pola existing SsrQsTile + today_widget).
- Dep baru tepat 1: `receive_sharing_intent: 1.8.1` exact (1.9.0 butuh
  compileSdk 37 > maks AGP 9.1.0 = 36; API instance getInitialMedia/
  getMediaStream/reset/SharedMediaFile sama di 1.8.x).
- Bump Skema A + changelog; strings baru ID+EN parity; APK arm64 berpola.
- Dilarang koding sebelum spec + plan disetujui. Docs ikut commit fitur.

## 3. Konteks existing (extend, jangan duplikasi)

- `lib/services/widget_snapshot.dart` — `formatSnapshot`/`parseSnapshot`/
  `TodaySnapshot`/`widgetBudgetLeft` (Dart murni + test `widget_snapshot_test`).
  Format `{date,text,text2,masked}`; provider toleran (rusak → ajakan buka app).
- `lib/services/today_widget.dart` — `refreshTodayWidget` (tulis key
  `widget_snapshot`, toggle `widgetToday`, default OFF),
  `refreshBudgetWidgetSnapshot(orgId)` (hitung server: todayOut + sisa budget),
  `requestWidgetRefresh()` DISABLED + alasan, `clearTodaySnapshot()`.
- Native inject `apk.yml:500-640` — 1 provider (`today_widget.xml`:
  wg_title/wg_line/wg_line2, tap → launch app), `SsrQsTile`
  (subtitle = snapshot text, tap → launch app), `updatePeriodMillis` 30 mnt.
- `openTxInputSheet(context, {initialType, ...})`
  (`tx_input_sheet.dart:57`) — entry sheet existing (wizard + ketik cepat +
  voice + scan); deep-link cukup panggil ini dengan `initialType`.
- `app_links` sudah dep — dipakai PIN/recovery (`pin_link_verify`,
  `splash _boot:72 getInitialLink`). Pola consume-awal di splash dipakai ulang.
- Vision scan: `vision_scan_service` (`InputImage.fromFilePath`) + ML Kit
  on-device gratis; AI-fallback berkuota (fase 1) — share-gambar ikut aturan itu.

## 4. Desain

### 4.1 Tiga widget, satu kunci per widget (pendekatan A, approved)

- Key existing `widget_snapshot` (Hari-ini: keluar-hari-ini + sisa budget)
  TAK DIUBAH (provider lama kompatibel).
- Key baru `widget_snapshot_budget` (format sama): `text` = sisa budget bulan
  (`wg_budget_left`), `text2` = lampu/status (mis. aman/waspada/bahaya +
  proyeksi) — angka dari `fetchBudgetLimits` + agregasi existing
  (pakai ulang logika `refreshBudgetWidgetSnapshot`, tanpa duplikasi hitung).
- Key baru `widget_snapshot_balance`: `text` = total saldo semua dompet
  (`wallet_balance`), `text2` = jumlah dompet / tanggal update.
- Penulis: 2 fungsi baru di `today_widget.dart` dipanggil dari titik yang sama
  dengan penulis existing (Beranda load + jalur simpan + budget berubah);
  gagal tulis satu kunci tak menggagalkan yang lain (try/catch per kunci).
  Toggle tetap 1 (`widgetToday`): mati → hapus ketiga kunci.
- Mask: ketiga snapshot hormati `maskAmounts` (placeholder, bukan angka).

### 4.2 Deep-link `ssrspace://quick-entry?type=`

- Skema custom `ssrspace`, host `quick-entry`, query `type=out|in|transfer`
  (absen/rusak → `out`; nilai asing → `out`, jangan crash).
- `lib/services/quick_link.dart` (Dart murni, testable):
  `parseQuickLink(Uri?) → String?` (tipe valid atau null) +
  antrean satu-slot di prefs `pending_quick_entry` (`{type, at}`):
  `queuePending(type)`, `takePending()` (baca + hapus atomik di mata pemanggil),
  kedaluwarsa 24 jam (basi → buang, jangan buka sheet kemarin).
- Konsumsi HANYA bila: sesi login ada + workspace aktif ada + PIN/lock lolos.
  Belum-login / belum-workspace / terkunci → biarkan antre (jujur, coba lagi
  saat kondisi siap — cek di tiap resume MainShell + sesudah unlock).
- Wiring: `splash _boot` (sesudah PIN/unlock + workspace, pola consume-awal
  seperti PinLinkVerify) + `uriLinkStream` saat app hidup → panggil
  `openTxInputSheet(initialType: type)` (tanpa duplikasi sheet).

### 4.3 Native inject (CI `apk.yml`, pola existing)

- 2 provider baru (`budget_widget`, `balance_widget` + `_info.xml`,
  `updatePeriodMillis` 30 mnt sama) + layout masing-masing berisi 2 tombol
  (Catat Keluar / Catat Masuk) → PendingIntent VIEW ke
  `ssrspace://quick-entry?type=out|in` (explicit package, immutable,
  fail-silent). Widget kecil (<200dp): tombol boleh hilang, angka tetap
  (pola Ollo: sembunyikan baris, bukan crash) — layout pakai `minWidth` wajar.
- Widget Hari-ini existing + 2 tombol yang sama (tambah ke layout existing).
- `SsrQsTile.onClick` → deep-link `type=out` via `startActivityAndCollapse`
  (ganti launch biasa); subtitle tetap snapshot text.
- `res/xml/shortcuts.xml` + `<meta-data android.app.shortcuts>` di Manifest:
  1 item "Catat" → deep-link `type=out` (icon existing, label strings?
  label shortcut = resource statis → ID saja, catat jujur di spec).
- Intent-filter skema di MainActivity: `VIEW + DEFAULT + BROWSABLE`,
  `data scheme=ssrspace host=quick-entry` (tanpa host web/domain).
- Intent-filter share: `SEND + SEND_MULTIPLE`, `mimeType=image/*`
  (teks/video/other DITOLAK di level filter — tak masuk app).
- Assert keras di step inject (pola existing): provider/tile/shortcut/
  filter harus ada di Manifest hasil generate, gagal = merah eksplisit.

### 4.4 Share gambar → scan (Android)

- `ReceiveSharingIntent.instance.getInitialMedia()` (cold) +
  `getMediaStream()` (warm) + `reset()` sesudah diproses (pola example plugin).
- Hanya file gambar pertama (multiple → pertama saja + catatan jujur di UI? —
  putusan: proses pertama, abaikan sisanya diam-diam? JUJUR: snackbar
  "hanya gambar pertama diproses" bila >1). Non-gambar tak sampai (filter).
- Alir ke `vision_scan_service` (jalur scan existing: ML Kit gratis dulu,
  fallback AI ikut kuota fase 1) → hasil prefill `TxInputSheet`
  (preview, TANPA auto-save; foto milik app pengirim, tak dihapus/diutak-atik).
- Terkunci/belum-workspace → antre path file (prefs `pending_share_image`,
  file pengirim bisa hilang bila pemicu reboot — batas sadar: hanguskan bila
  berkas tak ada saat dikonsumsi, snackbar jujur).

### 4.5 Strings + copy (ID+EN, parity)

- `wg_budget_title`, `wg_balance_title`, `wg_balance_total`,
  `wg_share_first` (hanya-gambar-pertama), `wg_locked_queued`
  (terkunci → diantre), `ql_invalid_ignored`.
  Pakai ulang kunci existing (`wg_out_today`, `wg_budget_left` — sudah ada,
  jangan duplikat). Label shortcut native statis "Catat" (resource build-time,
  tanpa kunci strings — batas sadar §6).

### 4.6 Testing

- `test/widget_snapshot_test.dart` += format/parse 2 kunci baru + kompat
  lama (text2 kosong) + mask + rusak → null.
- `test/quick_link_test.dart` (baru, murni): parse URI (valid/absen/asing/
  skema-salah → null), antre-ambil-sekali, kedaluwarsa 24 jam, hapus-saat-ambil.
- `test/share_intake_test.dart` (baru, murni): pilih-gambar-pertama,
  multi → flag jujur, berkas-hilang → hangus.
- CI: analyze 0 issue + flutter test + kompilasi native (bukti inject) +
  assert keras Manifest. Tanpa RLS test (tanpa migration).
- Device: 3 widget tampil angka benar; ketuk tombol/QS/shortcut → sheet tipe
  benar (kunci → unlock → sheet); share 1 & multi gambar; offline → antre;
  toggle mati → snapshot hilang + widget ajakan.

## 5. Non-goals

iOS share-extension (butuh Xcode, manual owner), applink web/domain,
widget ke-4+, tema widget terang/gelap khusus (ikut sistem via textColor
existing), riwayat/undo antrean, kuota AI baru (pakai fase 1).

## 6. Risiko & catatan jujur

- Widget refresh ikut `onUpdate` sistem (30 mnt, bisa basi — label tanggal jujur
  existing dipertahankan; channel refresh tetap mati pasca-FC 2.13.1).
- OEM agresif bisa menunda provider/QS subtitle — snapshot prefs tetap benar,
  tampilkan apa adanya.
- Shortcut label statis ID (resource build-time) — keterbatasan sadar.
- Gambar share milik app lain: salin ke cache sebelum scan bila API butuh path
  stabil; hapus salinan sesudah prefill (tanpa simpan permanen).
