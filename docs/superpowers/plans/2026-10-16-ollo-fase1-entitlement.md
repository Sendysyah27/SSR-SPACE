# Fase 1 Entitlement + Limit Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Gratis dibatasi 7 dimensi + VIP user-level tanpa Midtrans, ditegakkan server + gate klien jujur.

**Architecture:** `migration_20` menambah entitlement/VIP/AI-usage + memperluas `org_plan()` (semua trigger ikut otomatis); klien baca plan via RPC `plan_status` dengan fallback DB-lama/offline; gate baru ikut pola `canXxxServer` existing.

**Tech Stack:** Flutter (stable) + Supabase Postgres (RLS + RPC SECURITY DEFINER) + pg_cron guarded + `flutter_test` + RLS suite (`supabase/test/run.sh`).

**Spec:** `docs/superpowers/specs/2026-10-16-ollo-fase1-entitlement-design.md`

## Global Constraints

- Backend SEMUA via Supabase (RLS + RPC); JANGAN pernah pakai `api.olloweb.app`.
- Adaptasi konsep saja: tanpa merek/aset/teks Ollo; nama tetap SSR SPACE.
- Migration BARU `supabase/migration_20_entitlement.sql`, jangan edit history; user jalankan manual di SQL Editor; kode klien WAJIB fallback bila RPC belum ada (DB lama/offline).
- Policy SELECT `org_members` TIDAK BOLEH subquery `org_members`; cek admin via `public.is_org_admin(org_id)`; join org lain HANYA via RPC `join_org_by_invite`; invite/kode simpan hash sha256 bawaan PG (`encode(sha256(convert_to(upper(trim(text)),'UTF8')),'hex')`), tanpa pgcrypto.
- Semua fungsi baru: `language plpgsql/sql security definer set search_path = public`; `revoke all ... from public, anon; grant execute ... to authenticated`.
- `flutter analyze` wajib 0 issue (info `prefer_const_constructors` pun fatal); `dart` lokal SELALU `--enable-asserts`.
- Strings baru wajib ID+EN parity (`test/strings_parity_test.dart`).
- Bump Skema A: `pubspec.yaml` + `lib/utils/app_info.dart` identik + entri `assets/changelog_id.md`. Usulan `2.73.0+251`.
- Angka final (spec §4, APPROVED): dompet 7, budget 7/bln, AI 30/bln, Goals 3, Debts 5, Recurring 5; existing 2/3/150 tetap.
- Jangan commit docs sendirian; jangan push tanpa diminta owner; APK hanya `*-arm64.apk` via pola `-p`.

## Review Focus

- Kode VIP salah-ketik/spasi/case (`" abc-123 "` vs `"ABC-123"`) → dinormalisasi `upper(trim())` sebelum hash, pesan `VIP_INVALID` jujur bukan error teknis.
- Redeem 2 user bersamaan atas `max_uses=1` → tepat 1 sukses, 1 `VIP_EXHAUSTED` (atomic guard increment).
- Edit budget existing saat sudah 7 bucket → HARUS lolos (itu edit, bukan bucket baru), hanya bucket ke-8 BARU ditolak.
- DB lama (belum `migration_20`) / offline → gate TAK BOLEH blokir buta; fallback hitungan lokal + `stale`, izinkan bila tak tahu.
- AI fallback struk dihitung, ML Kit on-device TIDAK dihitung (gratis tanpa batas).

---

## File Structure

- `supabase/migration_20_entitlement.sql` (BARU): kolom `plan_expires_at`, tabel `user_entitlements`/`vip_codes`/`ai_usage` + retention, `org_plan()` baru, RPC `plan_status`/`redeem_vip_code`/`record_ai_usage`, `check_quota` kind baru, trigger wallet/budget, ganti 2 query `o.plan='pro'` → `org_plan(o.id)`.
- `supabase/test/run.sh` (UBAH 1 baris): tambah `../migration_20_entitlement.sql` ke loop.
- `supabase/test/rls_test.sql` (TAMBAH T34+): redeem happy/invalid/exhausted/idempoten/expiry, org_plan via VIP, trigger wallet/budget, ai quota, no-client-access.
- `lib/services/plan_limits.dart` (UBAH): konstanta + gate murni + `canXxxServer` baru. `test/plan_limits_test.dart` (TAMBAH).
- `lib/services/billing_service.dart` (UBAH): tambah `planStatus()`. `lib/services/ai_quota.dart` (BARU): `aiAllowed` + `recordAiUse`.
- `lib/screens/lainnya/billing_screen.dart` (UBAH): masa Pro + dialog VIP. `lib/utils/strings.dart` (TAMBAH kunci). Layar wallet/budget/goals/debts/recurring + `ai_chat_screen`/`vision_scan_service`/`tx_input_sheet` (HOOK gate, kecil per file).

### Task 1: migration_20 backend

**Files:**
- Create: `supabase/migration_20_entitlement.sql`
- Modify: `supabase/test/run.sh` (1 baris loop)

**Interfaces:**
- Consumes: `org_plan(uuid)`, `check_quota(uuid,text)`, `enforce_workspace_quota()` di `supabase/migration_squashed.sql:1081-1247`; pola `join_org_by_invite()` (~577-642, idempoten + atomic guard); retention guarded pola `migration_13`.
- Produces: `public.plan_status(uuid) -> jsonb {plan, source, expires_at}`; `public.redeem_vip_code(text) -> jsonb {expires_at, duration_days}` + error `VIP_INVALID`/`VIP_EXHAUSTED`; `public.record_ai_usage(uuid, text) -> void`; `check_quota` kind `wallets|budgets|ai`; trigger `trg_wallet_quota`/`trg_budget_quota` → `QUOTA_EXCEEDED`; `org_plan()` baru (expiry + VIP-owner).

- [ ] **Step 1: Tulis migration (idempotent, guarded)**
  `alter table organizations add column if not exists plan_expires_at timestamptz`; 3 tabel `if not exists` TANPA policy client; `org_plan()` `create or replace` (pro bila org-pro-belum-expired ATAU owner entitlement aktif); `check_quota` tambah cabang `wallets` (limit 7), `budgets` (bucket bulan berjalan, limit 7), `ai` (count `ai_usage` user+org bulan berjalan, limit 30); ganti 2 query `o.plan = 'pro'` → `public.org_plan(o.id)`; `redeem_vip_code` (normalisasi + hash pola invite + idempoten + atomic `used_count=used_count+1 where used_count < max_uses`); trigger wallet (count≥7 tolak) + budget (existing-row lolos, bucket baru ≥7 tolak); pg_cron `ai_usage` 90 hari guarded; komentar contoh insert `vip_codes`.
- [ ] **Step 2: Tambah ke `run.sh` loop**
  Ubah `for f in setup.sql ../schema.sql ../migration_squashed.sql rls_test.sql` → `for f in setup.sql ../schema.sql ../migration_squashed.sql ../migration_20_entitlement.sql rls_test.sql`.
- [ ] **Step 3: Verifikasi lokal via Postgres**
  Run: `SSR_RLS_DB_URL=postgresql://<lokal> bash supabase/test/run.sh` (tanpa T34+ dulu — T34+ di Task 2; sukses = baseline + migration_20 apply bersih).
  Expected: `== SUKSES: suite RLS lulus`.

### Task 2: RLS T34+

**Files:**
- Modify: `supabase/test/rls_test.sql` (append T34+)
- Test: `supabase/test/run.sh` (dipakai ulang, dari Task 1)

**Interfaces:**
- Consumes: Task 1 (RPC + trigger + tabel).
- Produces: assert T34+ hijau; fixture existing tak pecah.

- [ ] **Step 1: Tulis T34+ (gagal-dulu bila migration salah)**
    Assert: (a) redeem happy → `plan_status` pro via vip; (a2) redeem kode
  lowercase + spasi (`"  <kode>  "`) → sukses (normalisasi `upper(trim())`);
  (b) kode salah → `VIP_INVALID`; (c) `max_uses=1` user kedua → `VIP_EXHAUSTED`; (d) redeem sama 2x → `used_count` tetap 1; (e) entitlement lampau → plan free; (f) org `plan='free'` + owner entitlement aktif → `org_plan` pro; (g) wallet ke-8 free → `QUOTA_EXCEEDED`, Pro lolos; (h) budget bucket ke-8 baru ditolak + edit existing lolos + Pro lolos; (i) 30x `record_ai_usage` → `check_quota('ai')` `allowed=false`; (j) anon/client SELECT `vip_codes` / INSERT `user_entitlements` ditolak.
- [ ] **Step 2: Jalankan suite**
  Run: `SSR_RLS_DB_URL=postgresql://<lokal> bash supabase/test/run.sh`
  Expected: `== SUKSES: suite RLS lulus` (157 range T lama + T34+).
- [ ] **Step 3: Commit**
  ```bash
  git add supabase/migration_20_entitlement.sql supabase/test/run.sh supabase/test/rls_test.sql
  git commit -m "feat: entitlement VIP + limit wallet/budget/AI (migration_20 + RLS T34+)"
  ```

### Task 3: Gate plan_limits + test

**Files:**
- Modify: `lib/services/plan_limits.dart`
- Test: `test/plan_limits_test.dart`

**Interfaces:**
- Consumes: `quotaCheck(orgId, kind)` existing; `planStatus()` dari Task 4 (untuk gate lokal Goals/Debts/Bills — bila Task 4 belum ada, gate lokal pakai `currentPlan()` sementara, JANGAN duplikasi logika).
- Produces: `PlanLimits.freeWallets=7`, `freeBudgetsPerMonth=7`, `freeAiPerMonth=30`, `freeGoals=3`, `freeDebts=5`, `freeBills=5`; `canAddWallet/canAddBudget/canUseAi/canAddGoal/canAddDebt/canAddBill({required String plan, required int used})`; `canAddWalletServer/canAddBudgetServer/aiAllowedServer(orgId)` pola server-dulu-lokal-fallback.

- [ ] **Step 1: Tulis test gagal**
  ```dart
  test('Gratis: dompet maks 7', () {
    expect(canAddWallet(plan: 'free', used: 6), isTrue);
    expect(canAddWallet(plan: 'free', used: 7), isFalse);
    expect(PlanLimits.freeWallets, 7);
  });
  ```
  + pola sama untuk budget (6/7), AI (29/30), Goals (2/3), Debts (4/5), Bills (4/5); Pro selalu `isTrue` di 99/9999.
- [ ] **Step 2: Verifikasi gagal**
  Run: CI `flutter test test/plan_limits_test.dart` (lokal tak ada flutter).
  Expected: FAIL (fungsi belum ada).
- [ ] **Step 3: Implement gate di `plan_limits.dart`**
  Konstanta + 6 fungsi murni (`isPro(plan) || used < limit`) + 3 server-gate (`quotaCheck` kind `wallets`/`budgets`/`ai`; null → fallback lokal existing).
- [ ] **Step 4: Verifikasi lolos**
  Run: CI `flutter test test/plan_limits_test.dart` (atau full `flutter test` bila digabung Task 4-6).
  Expected: PASS.
- [ ] **Step 5: Commit**
  ```bash
  git add lib/services/plan_limits.dart test/plan_limits_test.dart
  git commit -m "feat: gate limit wallet/budget/AI/goals/debts/bills"
  ```

### Task 4: Billing status + layar VIP

**Files:**
- Modify: `lib/services/billing_service.dart`, `lib/screens/lainnya/billing_screen.dart`, `lib/utils/strings.dart`
- Test: `test/strings_parity_test.dart` (otomatis ikut bila kunci parity)

**Interfaces:**
- Consumes: RPC `plan_status` (Task 1); `currentPlan()` existing (fallback); `redeem_vip_code` via `SupabaseConfig.client.rpc`.
- Produces: `Future<Map<String, dynamic>> planStatus(String orgId)` → `{plan: String, source: String?, expiresAt: String?, stale: bool}` (catch → `{plan: currentPlan, source: null, expiresAt: null, stale: true}`).

- [ ] **Step 1: Tambah `planStatus()` + fallback**
  RPC `plan_status` params `{'p_org_id': orgId}`; sukses → map + `stale:false`; catch → `currentPlan()` + `stale:true`. Jangan rethrow.
- [ ] **Step 2: Layar — masa Pro + dialog VIP**
  `_load` pakai `planStatus` (bukan `currentPlan` saja); label `"Pro sampai {tgl}"` bila `expiresAt` non-null, `"Pro"` bila permanen, existing bila free; tile "Masukkan kode VIP" → dialog → rpc `redeem_vip_code` → snackbar `bl_vip_ok` / `bl_vip_invalid` / `bl_vip_exhausted` → reload; daftar limit Gratis = tabel spec §4.
- [ ] **Step 3: Strings ID+EN**
  `bl_pro_until`, `bl_vip_title`, `bl_vip_hint`, `bl_vip_redeem`, `bl_vip_ok`, `bl_vip_invalid`, `bl_vip_exhausted`, `bl_limit_wallets/budgets/ai/goals/debts/bills`, `q_ai_exceeded`, `q_wallet_exceeded`, `q_budget_exceeded` — tiap kunci ada `id` + `en`.
- [ ] **Step 4: Verifikasi**
  Run: CI `flutter analyze` (0 issue) + `flutter test test/strings_parity_test.dart`.
  Expected: PASS.
- [ ] **Step 5: Commit**
  ```bash
  git add lib/services/billing_service.dart lib/screens/lainnya/billing_screen.dart lib/utils/strings.dart
  git commit -m "feat: status Pro + redeem kode VIP di Billing"
  ```

### Task 5: Gate AI (ai_quota + 3 call sites)

**Files:**
- Create: `lib/services/ai_quota.dart`
- Modify: `lib/screens/lainnya/ai_chat_screen.dart`, `lib/services/vision_scan_service.dart`, `lib/widgets/tx_input_sheet.dart`

**Interfaces:**
- Consumes: `quotaCheck` / `canUseAi` (Task 3); `SupabaseConfig.client.rpc('record_ai_usage', ...)`.
- Produces: `Future<bool> aiAllowed(String orgId)` (server `check_quota('ai')`, null → true + catat prefs lokal, jangan blokir buta); `Future<void> recordAiUse(String orgId, String kind)` (rpc; catch → diam, fail-silent).

- [ ] **Step 1: Tulis `ai_quota.dart`**
  `aiAllowed` = `quotaCheck(orgId,'ai')` → `allowed==true`; null/exception → true. `recordAiUse` try rpc, catch diam.
- [ ] **Step 2: Hook 3 call sites (prefill tetap, simpan tetap manual)**
  `ai_chat_screen` tiap kirim → bila tidak allowed → `requirePro(q_ai_exceeded)` + batal; sukses → `recordAiUse(orgId,'chat')`. `vision_scan_service` HANYA jalur fallback AI (bukan ML Kit) → sama dengan kind `'receipt'`. `tx_input_sheet` ketik-cepat AI → sama, kind `'quick'`.
- [ ] **Step 3: Verifikasi**
  Run: CI `flutter analyze` + `flutter test` (tak ada test baru; regresi `ai_*_test`, `receipt_*_test`, `quick_input_test` harus hijau).
  Expected: PASS.
- [ ] **Step 4: Commit**
  ```bash
  git add lib/services/ai_quota.dart lib/screens/lainnya/ai_chat_screen.dart lib/services/vision_scan_service.dart lib/widgets/tx_input_sheet.dart
  git commit -m "feat: gate kuota AI 30/bln (chat + fallback struk + ketik-cepat)"
  ```

### Task 6: Gate wallet/budget/lokal + restore jujur

**Files:**
- Modify: `lib/services/wallet_service.dart`, `lib/services/budget_service.dart`, layar goals/debts/recurring (`goals_screen.dart`, `debts_screen.dart`, `recurring_bills_screen.dart`), service restore/backup (`backup_json.dart` / pemanggil restore)

**Interfaces:**
- Consumes: `canAddWalletServer/canAddBudgetServer` (Task 3), `planStatus` (Task 4), `requirePro`.
- Produces: QUOTA → paywall (bukan error teknis); tambah lokal ke-N+1 free → paywall.

- [ ] **Step 1: Wallet/budget catch QUOTA**
  `WalletService.create` catch `PostgrestException` berisi `QUOTA_EXCEEDED` → lempar pesan `q_wallet_exceeded` untuk `requirePro` (pertahankan `_guardSpace` mapping `42501` Bendahara). `setBudget` sama → `q_budget_exceeded`. (Pre-check opsional via server-gate untuk UX; trigger tetap penegak.)
- [ ] **Step 2: Gate lokal Goals/Debts/Bills**
  Saat tambah item melebihi `freeGoals/freeDebts/freeBills` dan plan server != pro → `requirePro` + batal; offline/RPC-gagal → izinkan (jangan blokir buta). Caps teknis `maxGoals/maxDebts/maxBills` tetap.
- [ ] **Step 3: Restore backup jujur**
  Catch `QUOTA_EXCEEDED` per item → hitung sukses/gagal + pesan kuota (jangan "gagal" generik).
- [ ] **Step 4: Verifikasi**
  Run: CI `flutter analyze` + `flutter test`.
  Expected: PASS.
- [ ] **Step 5: Commit**
  ```bash
  git add lib/services/wallet_service.dart lib/services/budget_service.dart lib/screens/lainnya/goals_screen.dart lib/screens/lainnya/debts_screen.dart lib/screens/lainnya/recurring_bills_screen.dart lib/services/backup_json.dart
  git commit -m "feat: paywall wallet/budget/goals/debts/bills + restore jujur"
  ```

### Task 7: Rilis (bump + changelog + APK + instruksi)

**Files:**
- Modify: `pubspec.yaml`, `lib/utils/app_info.dart`, `assets/changelog_id.md`

**Interfaces:**
- Consumes: semua Task 1-6 hijau.

- [ ] **Step 1: Bump + changelog**
  `version: 2.73.0+251` + `AppInfo.version = '2.73.0+251'` identik + seksi `## Yang baru di 2.73.0+251` (limit baru + VIP + masa Pro) + `Versi terpasang: 2.73.0+251.`
- [ ] **Step 2: CI hijau penuh**
  Run: push branch → `gh run watch ... --exit-status` (atau tunggu run `main` bila owner minta push main).
  Expected: analyze 0 issue + `flutter test` + build arm64 + rls-test hijau.
- [ ] **Step 3: APK + instruksi migration**
  Run: `gh release download ci-apk -p "SSR-SPACE-2.73.0-251-arm64.apk" -D /sdcard/Download/SSR-SPACE/ --clobber` + tulis instruksi user: jalankan `supabase/migration_20_entitlement.sql` di Dashboard → SQL Editor (sekali, idempotent).
  Expected: file ada, ukuran utuh (bandingkan byte rilis).
  Cek device (owner): redeem kode asli → masa Pro tampil; dompet ke-8 / budget ke-8 / AI ke-31 → paywall; edit budget existing lolos; matikan internet → gate tak blokir buta (stale/fallback).
- [ ] **Step 4: Commit rilis**
  ```bash
  git add pubspec.yaml lib/utils/app_info.dart assets/changelog_id.md
  git commit -m "chore: bump 2.73.0+251 entitlement VIP + limit"
  ```
