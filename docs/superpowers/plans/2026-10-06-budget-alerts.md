# Budget Alerts Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Real-time budget alerts via Postgres trigger + client banner/badge.

**Architecture:** Migration 16 adds `warn_pct` + `budget_alerts` table + fail-open AFTER INSERT trigger; RLS member-read; client polls on resume, no client writes. Warn default 80, breach fixed 100.

**Tech Stack:** Supabase Postgres (RLS, SECURITY DEFINER trigger, pg harness `supabase/test/run.sh`), Flutter (existing patterns: `verifyPin`, hub badge ala Space activity, `tr()` strings).

**Spec:** `docs/superpowers/specs/2026-10-06-budget-alerts-design.md`

## Global Constraints

- Setiap migration baru, jangan edit history; user jalankan manual di Dashboard.
- Policy SELECT di `org_members` TIDAK BOLEH subquery `org_members` (rekursi); cek member via `exists (select ... from org_members where org_id = ... and user_id = auth.uid())`.
- Trigger alert fail-open: exception apa pun → RETURN NEW (insert user tak boleh diblokir).
- Agregasi kategori ikut grup lapis-atas (`split_part(cat,' > ',1)`), null/kosong → 'Lainnya' (mirror client).
- `flutter analyze` 0 issue (bahkan info), `flutter test` hijau via CI.
- Version bump Skema A (pubspec + AppInfo identik) + entri `assets/changelog_id.md`.
- Copy UI Indonesia hanya lewat `lib/utils/strings.dart` (ID+EN).

## Review Focus

- Insert 2x melewati ambang yang sama menghasilkan 1 baris (dedup unique) — Task 1 T22.
- Kategori `Makan > Jajan` masuk grup `Makan`, bukan grup sendiri — Task 1 T24.
- Trigger error (mis. budget limit 0/NULL) tidak menggagalkan insert transaksi — Task 1 T26.
- `warn_pct` 0/101/negatif ditolak (check + validasi client) — Task 3.
- Alert bulan lalu tidak muncul di banner bulan berjalan — Task 2.

---

### Task 1: Migration 16 + trigger + RLS + server tests

**Files:**
- Create: `supabase/migration_16_budget_alerts.sql`
- Modify: `supabase/test/rls_test.sql` (append T21–T27 sebelum baris SELESAI)
- Test: `SSR_RLS_DB_URL=postgresql://… bash supabase/test/run.sh` (lokal bila ada Postgres, wajib via CI `rls-test.yml`)

**Interfaces:**
- Consumes: tabel `budgets(org_id, category, month, limit_amount)`, `transactions(org_id, type, amount, date, category)`, helper RLS `public.is_org_admin` (tidak dipakai di sini).
- Produces: `budgets.warn_pct int default 80`, tabel `budget_alerts` + trigger `check_budget_alert()` yang dipakai Task 2 (select saja).

- [ ] **Step 1: Tulis test T21–T27 yang gagal** di `supabase/test/rls_test.sql` sebelum baris `-- ===== Selesai =====`, pola `t_assert` + `set test.user_id` seperti T17–T20:
  - T21 warn: budget (org A, cat 'Makan', limit 100000) + insert out 85000 → 1 baris `(org A, bulan ini, 'Makan', 'warn')`.
  - T22 dedup: insert out 5000 lagi → count baris warn tetap 1.
  - T23 breach: insert out 20000 (total ≥100000) → 1 baris level 'breach', warn tetap 1.
  - T24 subkategori: budget 'Minum', insert cat 'Minum > Kopi' 90000/100000 → warn grup 'Minum'.
  - T25 negatif: transfer/in ke budget cat + insert client langsung ke `budget_alerts` → ditolak RLS; user org B select alerts org A → kosong.
  - T26 fail-open: (bila mungkin via limit 0 — CHECK melarang; sebagai gantinya) insert out ke kategori tanpa budget → insert lolos, tanpa baris alert.
  - T27 custom: budget cat 'Jajan' limit 100000 + warn_pct 50 + insert 55000 → warn muncul di 55%.
- [ ] **Step 2: Jalankan suite, pastikan T21–T27 gagal** (tabel/trigger belum ada).
- [ ] **Step 3: Tulis `supabase/migration_16_budget_alerts.sql`**: `alter table budgets add column warn_pct int not null default 80 check (warn_pct between 1 and 100)`; create table + unique + RLS SELECT member-only tanpa write; fungsi + trigger `AFTER INSERT ON transactions FOR EACH ROW WHEN (NEW.type='out')` sesuai Spec §3 (top = `nullif(split_part(NEW.category,' > ',1),'')` fallback 'Lainnya'; bulan = `substring(NEW.date,1,7)`; guard `if not exists` sebelum insert; `exception when others then return NEW`).
- [ ] **Step 4: Jalankan suite, pastikan semua hijau** (CI `rls-test.yml` sebagai verifikasi final).
- [ ] **Step 5: Commit** `git add supabase/migration_16_budget_alerts.sql supabase/test/rls_test.sql && git commit -m "feat: budget alerts trigger + RLS (migration_16)"` (push digabung Task 4).

### Task 2: Poll alerts + banner Budget + badge hub

**Files:**
- Modify: `lib/screens/shell/main_shell.dart:55-57` (tambah poll di `resumed`)
- Modify: `lib/screens/budget/budgets_screen.dart` (banner atas daftar, ikut pola `_NoWalletBanner` transaksi)
- Modify: `lib/screens/lainnya/other_screen.dart` (badge count di tile Budget, pola `unseenCount`/`lastSeen` baris 786-787; seen disimpan per bulan di prefs `ba_seen_<org>_<month>`)
- Modify: `lib/utils/strings.dart` (kunci `ba_warn`, `ba_breach`, `ba_title`)
- Test: `test/budget_alerts_test.dart` (pure: format label banner dari row map + filter bulan berjalan; stub `tr()` seperti `datetime_test.dart`)

**Interfaces:**
- Consumes: tabel `budget_alerts` Task 1 (select `.eq('org_id',...).eq('month', currentMonth())` via `SupabaseConfig.client`).
- Produces: tidak ada (leaf UI).

- [ ] **Step 1: Tulis failing test** `test/budget_alerts_test.dart`: `alertLabel({'category':'Makan','level':'warn','spent':85000,'limit_amount':100000})` → string non-kosong mengandung 'Makan'; `isCurrentMonth('2026-10')` true bila sama dengan `currentMonth()` dari `services/month.dart`, false untuk bulan lain.
- [ ] **Step 2: Verifikasi gagal lokal** `dart --enable-asserts test/budget_alerts_test.dart` (wajib flag ini; tanpa itu PASS palsu).
- [ ] **Step 3: Implementasikan helper** `lib/services/budget_alerts.dart`: `Future<List<Map<String, dynamic>>> fetchAlerts(String orgId, String month)`, `String alertLabel(Map<String, dynamic> row)`, `bool isCurrentMonth(String m)`.
- [ ] **Step 4: Pasang banner + badge + poll resume**; badge = count alerts bulan ini minus seen; tap banner/tile → tandai seen (prefs saja, tanpa write server).
- [ ] **Step 5: Tambah strings `ba_*`** ID+EN; pastikan tidak ada `const` pecah (pelajaran i18n: `tr()` di dalam `const`).
- [ ] **Step 6: Verifikasi lokal** `dart --enable-asserts` untuk test baru; widget/analyze lewat CI.
- [ ] **Step 7: Commit** sesuai pola Bahasa commit (`feat: budget alerts banner + badge`).

### Task 3: Field warn_pct di dialog + service

**Files:**
- Modify: `lib/services/budget_service.dart:64` (`setBudget` + param `warnPct`, include di upsert)
- Modify: `lib/screens/budget/budgets_screen.dart:90-112` (form tambah: parse int 1–100, err `b_err_warn`) dan `_openEdit` ~baris 128–200 (field warn prefill dari row, ikut PIN flow yang ada)
- Modify: konstruksi `Budget(...)` di `budget_service.dart:55-60` (+ `warnPct: (r['warn_pct'] as num?)?.toInt() ?? 80`)
- Modify: `lib/utils/strings.dart` (`b_f_warn`, `b_err_warn`)
- Test: tambah case di `test/budget_alerts_test.dart` (validasi `parseWarnPct('0')→null`, `'101'→null`, `'80'→80`, `''→80`)

**Interfaces:**
- Consumes: kolom `warn_pct` Task 1.
- Produces: tidak ada.

- [ ] **Step 1: Tulis failing test** validasi di atas.
- [ ] **Step 2–4: Implement + verifikasi lokal + pasang UI** (validasi client cerminkan CHECK 1–100; server tetap otoritas).
- [ ] **Step 5: Commit** (`feat: warn_pct custom per budget`).

### Task 4: Docs, bump, push, CI

**Files:**
- Modify: `pubspec.yaml` + `lib/utils/app_info.dart` (identik, +build atau +patch), `assets/changelog_id.md` (seksi baru + Versi terpasang), `AGENTS.md` + `AUDIT.md` §7 (lokal).
- Test: CI `apk.yml` (analyze+test+build) dan `rls-test.yml` hijau; APK ke `ci-apk` otomatis.

- [ ] **Step 1: Catat docs + bump version.**
- [ ] **Step 2: Ingatkan migration_16 manual** di pesan akhir (user jalankan di Dashboard).
- [ ] **Step 3: Commit + push + `gh run watch` sampai hijau.**
