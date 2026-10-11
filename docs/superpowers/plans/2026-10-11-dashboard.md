# Dashboard Beranda (Batch 16) Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Seksi dashboard di Beranda: kartu budget traffic-light + grid fitur + utang ringkas, bisa disusun/sembunyikan, rilis 2.28.0+102.

**Architecture:** Hero surplus fixed; di bawahnya seksi Dashboard merender 3 kartu sesuai `dashboard_order` prefs (pola `reports_section_order`); mode Susun = panah ↑↓ + mata (pola laporan). Data 100% reuse `_load` Beranda + prefs-lokal, nol query server baru. Tanpa migration, tanpa dep baru.

**Tech Stack:** Flutter stable, shared_preferences. CI: analyze (0 issue termasuk info) → test → APK.

**Spec:** `docs/superpowers/specs/2026-10-11-dashboard-design.md`

## Global Constraints

- Bahasa UI Indonesia, copy baru lewat `lib/utils/strings.dart` ID+EN kunci `dash_*`, tanpa em dash, tanpa klaim palsu.
- Nominal lewat `amt()`; warna hanya `colorScheme` + token `AppColors` existing (nol hardcode).
- `flutter analyze` 0 issue (info pun fatal); `dart` lokal WAJIB `--enable-asserts`; komentar kepala file `//` bukan `///` (dangling doc = merah); `const` hanya di call-site full-const.
- Version Skema A: `pubspec.yaml` + `lib/utils/app_info.dart` identik (2.28.0+102) + entri `assets/changelog_id.md` paling atas.
- Tiap task commit sendiri; bila CI merah: fix commit baru, JANGAN amend. Tester hanya `*-arm64.apk` pola `-p` spesifik ke `/sdcard/Download/SSR-SPACE/`.
- `flutter` tak ada lokal: logika murni diverifikasi `dart --enable-asserts` probe, suite penuh via CI.
- Catat lokal `AGENTS.md` + `AUDIT.md` §7, gabung push implementasi (bukan commit docs sendirian).

## Review Focus

- Order prefs rusak/asing → fallback default, kartu tak dikenal dibuang (bukan crash).
- Budget limit 0 / spent > limit → lampu merah, persen >100% tampil apa adanya.
- Tanpa budget / tanpa utang → CTA, bukan kartu kosong.
- Dark mode: kartu baru tetap kontras (verifikasi device, CI tak bisa screenshot).
- `mounted` guard tiap setState pasca-await.

---

### Task 1: Fondasi murni dashboard_cards + test

**Files:**
- Create: `lib/services/dashboard_cards.dart`
- Create: `test/dashboard_cards_test.dart`

**Interfaces:**
- Consumes: nothing (murni, nol import Flutter).
- Produces: `kDashboardDefault=['budget','fitur','utang']`, `parseDashboardOrder(dynamic)->List<String>`, `serializeDashboardOrder(List<String>)->String`, `moveDashboardCard(List<String>,String,int)->List<String>` (dir -1/+1, jepit batas), `isDashboardHidden(Set<String>,String)->bool`, `budgetLight({required double spent, required double limit, required int warnPct})->String` ('green'/'gold'/'red'; limit<=0 → 'green').

- [ ] **Step 1: Tulis test (TDD RED)** — `test/dashboard_cards_test.dart`: default 3 id; parse rusak (null/string/list asing) → default; round-trip serialize; geser atas-bawah + jepit di ujung; id asing dibuang; lampu: 30/100+warn80 → green, 85/100 → gold, 100/100 + 150/100 → red, limit 0 → green.
- [ ] **Step 2: Buktikan RED** — probe `dash_probe.dart` (plain dart, import relatif lib) assert 2-3 perilaku inti → gagal file-hilang. Hapus probe setelah GREEN.
- [ ] **Step 3: Implementasi minimal** di `lib/services/dashboard_cards.dart` (header `//`).
- [ ] **Step 4: Verifikasi lokal** — probe penuh `dart --enable-asserts` semua case hijau, hapus probe.
- [ ] **Step 5: Commit** — `git add lib/services/dashboard_cards.dart test/dashboard_cards_test.dart && git commit -m "feat: fondasi murni dashboard cards"` (JANGAN push; push digabung akhir).

### Task 2: Strings + state order + mode Susun di Beranda

**Files:**
- Modify: `lib/utils/strings.dart` (kunci `dash_*`: dashboard, susun, selesai, tampilkan, sembunyikan, buat_budget, budget_sisa? — final: `dash_title`, `dash_arrange`, `dash_done`, `dash_show`, `dash_hide`, `dash_make_budget`, `dash_budget`, `dash_feature`, `dash_debt`, ID+EN)
- Modify: `lib/screens/beranda/beranda_screen.dart` (state: `dashOrder`, `dashHidden`, `arranging`; load/save prefs `dashboard_order`/`dashboard_hidden`; header seksi + tombol Susun/Selesai di `_content` tepat bawah hero)

**Interfaces:**
- Consumes: Task 1 (parse/serialize/move).
- Produces: state terisi saat `_load` sukses; header render; mode Susun toggle.

- [ ] **Step 1: Tambah kunci strings**, pastikan nol tabrakan prefix (`dash_*` belum dipakai).
- [ ] **Step 2: State + load/save prefs** — load di `_load` (fail-open default), save tiap geser/sembunyi. `mounted` guard.
- [ ] **Step 3: Header seksi + dispatcher** — bawah `_surplusCard`: baris judul + TextButton Susun/Selesai; dispatcher `_dashCard(String id)` map id→widget, default `SizedBox.shrink()` (Task 3-4 mengisi case `budget`/`fitur`/`utang`). Mode Susun: bungkus tiap kartu baris panah ↑↓ (panggil `moveDashboardCard` + save) + ikon mata (toggle hidden + save).
- [ ] **Step 4: Commit** — `feat: dashboard order state + mode susun` (jangan push).

### Task 3: Kartu Budget traffic-light (+ CTA kosong)

**Files:**
- Modify: `lib/screens/beranda/beranda_screen.dart` (widget `_DashBudgetCard` <50 baris + render di urutan order)

**Interfaces:**
- Consumes: `spent` + `limits` existing di `_load` (top-level, non-tabungan — SAMA seperti loop pace; jangan definisi baru), `budgetLight`, `onBudget` callback existing.
- Produces: kartu Top-3 by spent (dot + nama + `terpakai/limit` + % tabular); ketuk → `onBudget`; tanpa budget → CTA buat.

- [ ] **Step 1: Widget kartu** — SectionCard, dot `BoxDecoration`/`Icon` warna: green=`scheme.primary`, gold=`AppColors.gold` (cek token ada), red=`scheme.error`. Tanpa warna literal.
- [ ] **Step 2: Render sesuai order** — hanya bila id `budget` tampil; sembunyi fail-open bila hitung gagal.
- [ ] **Step 3: Commit** — `feat: kartu budget traffic-light dashboard`.

### Task 4: Grid Fitur + Utang ringkas (+ hook loadDebts)

**Files:**
- Modify: `lib/screens/beranda/beranda_screen.dart` (`_DashFeatureGrid`, `_DashDebtCard`, render order, `loadDebts` di `_load` + field `dashDebts`)

**Interfaces:**
- Consumes: layar existing (Wallets, RecurringBills, Subscriptions, BillSplits, Debts, Goals, NfcCards, NotifSettings) via `Navigator.push`; `loadDebts`+`debtTotals` (pola splits); `AppIcons` (wallet, bills, calendar, transfer, billing, topup, scan, tracking).
- Produces: grid 4×2 tile buka layar benar; kartu utang (sisa utang vs piutang + progres) ketuk → DebtsScreen; kosong → CTA catat.

- [ ] **Step 1: Grid fitur** — 8 tile, label via `tr` existing (o_wallets, rb_title, sub_title, bs_title, db_title, goal_title, nfc_title, o_tracking). Tanpa copy baru bila kunci ada.
- [ ] **Step 2: Utang ringkas** — `dashDebts` di-load di `_load` (fail-open []); kartu pakai `debtTotals`; CTA bila kosong.
- [ ] **Step 3: Commit** — `feat: grid fitur + utang ringkas dashboard`.

### Task 5: Version, CI hijau, APK, docs

**Files:**
- Modify: `pubspec.yaml`, `lib/utils/app_info.dart` (2.28.0+102), `assets/changelog_id.md` (entri + "Versi terpasang")
- Modify (lokal saja): `AGENTS.md`, `AUDIT.md` §7, spec+plan ikut commit implementasi

**Interfaces:**
- Consumes: Task 1-4 (semua hijau lokal).

- [ ] **Step 1: Bump + changelog**, pastikan `flutter analyze` non-fatal lokal tak bisa — andalkan CI.
- [ ] **Step 2: Push + pantau** — `git push origin main`, `gh run watch --exit-status`; merah → diagnosis log → fix commit baru (hex: info lint, import salah file, `!` redundan).
- [ ] **Step 3: APK** — hijau → `gh release download ci-apk -p "SSR-SPACE-2.28.0-102-arm64.apk" -D /sdcard/Download/SSR-SPACE/ --clobber`.
- [ ] **Step 4: Docs lokal** — AGENTS.md bullet + AUDIT.md §7 baris (aktivitas ini boleh tertinggal ≤1 sesi dari push).
