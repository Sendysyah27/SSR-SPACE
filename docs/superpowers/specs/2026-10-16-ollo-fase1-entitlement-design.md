# Spec Fase 1 — Entitlement + Limit (adaptasi konsep Ollo)

> Tanggal: 2026-10-16 · Status: **APPROVED owner (Bagian 1+2)** → lanjut writing-plans.
> Repo: `~/SSRSPACE` v2.72.0+250. Sesi ini HANYA fase 1 dari kickoff
> `docs/prompts/2026-10-16-ollo-adapt-kickoff.md`. Fase 2-5 eksplisit non-scope.
> Aturan mengikat: backend SEMUA via Supabase (RLS+RPC); jangan pernah pakai
> `api.olloweb.app`; adaptasi konsep saja (tanpa merek/aset/teks Ollo).

## 1. Tujuan & kriteria sukses

- Gratis dibatasi di 7 dimensi; Pro bebas. VIP = jalan dapat Pro TANPA Midtrans
  (Midtrans PAUSED nunggu KYC; infra disiapkan tinggal colok via
  `plan_expires_at` + tabel `subscriptions` existing).
- Semantik VIP (dikunci owner): **user-level** — redeem sukses → semua workspace
  yang user itu `owner` (role `owner` di `org_members`, bisa >1 owner) jadi Pro
  selama entitlement aktif (durasi per kode; null = permanen).
- Klien menampilkan status jujur (plan + masa aktif + sisa kuota), gate jujur
  (paywall via `requirePro`, bukan blokir buta), error jujur
  (`VIP_INVALID`/`VIP_EXHAUSTED`/`QUOTA_EXCEEDED` dipetakan ke strings).
- Sukses = CI hijau (`apk.yml` + `rls-test.yml`), suite RLS T34+ lulus,
  APK arm64 terunduh, user menjalankan `migration_20` manual, plan server
  jadi sumber kebenaran tunggal untuk semua gate.

## 2. Batasan (constraints)

- Dilarang koding sebelum spec+plan disetujui (sudah dipenuhi: approval
  Bagian 1+2 via Q&A 2026-10-16). Eksekusi menunggu plan dari skill
  writing-plans + approval plan.
- Migration: file BARU `supabase/migration_20_entitlement.sql`, jangan edit
  history; fresh install = `schema.sql` + `migration_squashed.sql` + `migration_20`;
  DB produksi = jalankan `migration_20` manual di SQL Editor. Kode klien yang
  butuh RPC baru WAJIB fallback bila RPC belum ada (DB lama/offline) — lulus CI
  tapi dimaklumi sampai user migrasi.
- Jangan commit docs sendirian (1 commit docs = 1 run CI sia-sia); spec ini
  digabung ke commit fitur berikutnya. Jangan push tanpa diminta owner.
- Bump versi Skema A bila ada perubahan kode: `pubspec.yaml` +
  `lib/utils/app_info.dart` identik + entri `assets/changelog_id.md`.
  Usulan: `2.73.0+251` (atau sesuai saat eksekusi).
- Deliverable file → `/sdcard/Download/SSR-SPACE/`, hanya varian `*-arm64.apk`,
  unduh berpola `-p "<nama-file-versi-baru>"`.
- Flutter tidak ada di Termux → verifikasi via CI. Logika murni TDD via
  `dart --enable-asserts` lokal (wajib flag itu; tanpa itu PASS palsu).
- i18n parity: setiap kunci strings baru wajib ID+EN (`test/strings_parity_test.dart`).
- RLS: policy SELECT di `org_members` TIDAK BOLEH subquery `org_members`
  (recursion); cek admin via `public.is_org_admin(org_id)`; join org lain HANYA
  via RPC `join_org_by_invite`; invite simpan hash sha256 saja (pola existing).

## 3. Konteks existing (extend, jangan duplikasi)

- `lib/services/plan_limits.dart` — `freeWorkspaces=2`, `freeMembers=3`,
  `freeAutoPerMonth=150`; gate `canCreateWorkspace/canInvite/canAutoTrack/canExportPdf`;
  `quotaCheck()` RPC `check_quota`; `canXxxServer()` pola server-dulu-lokal-fallback;
  `requirePro(context, reason)` = snackbar + push `BillingScreen`.
- `lib/services/billing_service.dart` — CUMA `currentPlan(orgId)` baca
  `organizations.plan` langsung + `proPrice=25000`.
- `lib/screens/lainnya/billing_screen.dart` — kartu Gratis/Pro statis, chip
  `bl_soon`, tanpa tombol bayar. Belum ada masukan kode VIP.
- Server existing (`supabase/migration_squashed.sql` ~baris 1070-1247, migration_17):
  `org_plan(p_org_id)` = `organizations.plan` mentah (tanpa expiry);
  `check_quota(p_org_id, kind)` kind `auto|members|workspaces`; `workspaces`
  user-scoped (pro = ada org diikuti dgn `o.plan='pro'` — baca langsung, HARUS
  diganti `org_plan(o.id)` saat VIP masuk); trigger `trg_auto_quota` /
  `trg_member_quota` / `trg_workspace_quota` → `QUOTA_EXCEEDED`.
  `enforce_workspace_quota()` juga baca `o.plan='pro'` langsung — sama, lewat `org_plan()`.
- Mapping error klien: `notif_track_service.dart` (`saveErrorStatus` cek
  `QUOTA_EXCEEDED`), `invite_token.dart` (`iv_quota`), `org_switcher_screen.dart:123`.
- `supabase/functions/create-snap/index.ts` ada; `midtrans-webhook` BELUM ada;
  workflow deploy functions BELUM ada — semua PAUSED, jangan disentuh sesi ini.
- Budget pakai UPSERT (`budget_service.dart:163 setBudget`, onConflict
  `org_id,category,month`) → trigger budget harus loloskan edit baris existing,
  hanya batasi bucket BARU. Tanpa ini, edit budget ke-7 saat sudah 7 bucket = diblok.
- Wallet create di `wallet_service.dart:24 create()` (dibungkus `_guardSpace`
  mode Bendahara — pertahankan pola, tambah catch `QUOTA_EXCEEDED` → `requirePro`).
- Owner org = member `role='owner'` (bisa >1; jangan pakai `created_by` saja).
- Hash kode pola invite: `encode(sha256(convert_to(upper(trim(text)),'UTF8')),'hex')`,
  sha256 bawaan PG tanpa pgcrypto. Idempoten + atomic guard increment pola
  `join_org_by_invite()` (squashed ~577-642).
- Goals/Debts/Recurring/tagihan = prefs lokal, bukan Supabase
  (`goal_store.dart` `_kGoals`, cap `maxGoals=20` di `savings_goal.dart:7`;
  `debt_store.dart` `kDebtsKey`, cap `maxDebts=50` di `debt_track.dart:7`;
  `recurring_bills.dart` `_kBills`, cap `maxBills=30`, payments cap 200).
  → gate lokal client-side saja (catatan jujur di UI/spec), pakai plan server
  sebagai sumber kebenaran plan.
- AI call sites (pasang gate §5): `ai_chat_screen.dart` (chat parse),
  `vision_scan_service.dart` (fallback struk; parser `firebase_ai_parser.dart` /
  `ai_zen_client.dart` / `ai_cli_client.dart`), `tx_input_sheet.dart`
  (ketik cepat AI). ML Kit on-device tetap gratis tanpa batas.
- RLS harness: `supabase/test/run.sh` apply `setup.sql` → `schema.sql` →
  `migration_squashed.sql` → `rls_test.sql` (suite panjang). **Wajib tambah
  `../migration_20_entitlement.sql` di loop.**
- Strings: kunci `bl_*` di `lib/utils/strings.dart` (~1139-1153), `iv_quota`,
  `sp_only_treasurer`. Kunci baru wajib parity ID+EN.

## 4. Tabel limit final (APPROVED owner 2026-10-16)

| Fitur | Gratis | Pro |
|---|---|---|
| Workspace / Anggota / Auto-track | 2 / 3 / 150-bln (existing) | bebas |
| Dompet | 7 | bebas |
| Budget | 7 bucket/bulan | bebas |
| AI (chat parse + fallback struk) | 30 panggilan/bulan | bebas |
| Goals / Utang-piutang / Tagihan berulang | 3 / 5 / 5 | bebas |
| Ekspor PDF | — (existing `canExportPdf`) | ✓ ; CSV/XLSX tetap gratis |

Catatan jujur: wallet/budget/AI ditegakkan server (trigger + `ai_usage`);
Goals/Debts/Recurring gate client-side (prefs lokal) dengan plan server
sebagai sumber kebenaran.

## 5. Desain backend — `supabase/migration_20_entitlement.sql` (idempotent)

1. `organizations` + `plan_expires_at timestamptz` (null = tanpa kedaluwarsa;
   siap Midtrans: settlement → `now()+30d`; kolom plan existing dipertahankan).
2. Tabel baru (ketiganya **tanpa policy client** = RPC-only; client baca/tulis
   langsung = ditolak):
   - `user_entitlements` (`user_id uuid` ref `auth.users`, `plan text='pro'`,
     `expires_at timestamptz` null=permanen, `source text` (`vip_code|manual`),
     `source_ref text`, `granted_at timestamptz default now()`).
   - `vip_codes` (`code_hash text unique`, `duration_days int` null=permanen,
     `max_uses int default 1`, `used_count int default 0`, `note text`).
     Kode dibuat owner via SQL Editor (contoh insert di komentar migration).
   - `ai_usage` (`user_id`, `org_id`, `kind text`, `created_at default now()`,
     index `(user_id, org_id, created_at)`); retention pg_cron 90 hari pola
     guarded migration_13 (NOTICE + lewati bila ext tak ada).
3. `org_plan()` diperluas (SECURITY DEFINER, `set search_path=public`):
   pro bila (`organizations.plan='pro'` DAN (`plan_expires_at` null ATAU > now()))
   ATAU ada owner (`org_members role='owner'`) dengan entitlement aktif
   (`expires_at` null ATAU > now()). Ganti 2 query lama `o.plan='pro'`
   (cabang `workspaces` di `check_quota` + `enforce_workspace_quota()`)
   menjadi `public.org_plan(o.id)`. Semua trigger existing ikut otomatis.
4. RPC baru (SECURITY DEFINER, revoke public/anon, grant authenticated;
   `NOT_AUTHENTICATED` bila `auth.uid()` null):
   - `plan_status(p_org_id)` → `{plan, source org|vip|null, expires_at}`.
     Non-member → `NOT_MEMBER` (fail-closed); member baca plan org sendiri OK.
   - `redeem_vip_code(p_code)` → normalisasi `upper(trim())` → hash pola invite →
     cari baris; tak ada → `VIP_INVALID`; `used_count >= max_uses` → `VIP_EXHAUSTED`;
     idempoten: user sama + kode sama (cocok `source_ref`) → kembalikan entitlement
     lama TANPA increment; else INSERT entitlement
     (`expires_at` = null bila permanen else `now()+duration`) + atomic
     `used_count = used_count+1` dengan guard `where used_count < max_uses`
     (0 row → `VIP_EXHAUSTED` lawan race) → return `{expires_at, duration_days}`.
   - `check_quota` + kind baru: `wallets` (hitung `wallets` per org, limit 7),
     `budgets` (hitung bucket `budgets` distinct `(category, month)` bulan berjalan
     per org, limit 7), `ai` (hitung `ai_usage` user+org sejak awal bulan, limit 30;
     kind `ai` user-scoped tapi butuh `p_org_id` untuk konteks workspace).
     Kind asing tetap `QUOTA_UNKNOWN_KIND`. Bentuk return sama:
     `{allowed, used, limit, plan}` dengan `plan` dari `org_plan()` baru.
   - `record_ai_usage(p_org_id, p_kind)` → insert `ai_usage` (dipanggil klien
     SETELAH panggilan AI sukses; pre-check via `check_quota('ai')`).
5. Trigger baru (SECURITY DEFINER, fail-open hanya untuk error tak terduga —
   `QUOTA_EXCEEDED` selalu diteruskan):
   - wallets BEFORE INSERT: Pro (`org_plan <> 'free'`) lolos; else hitung
     `wallets` org → ≥7 → `QUOTA_EXCEEDED`.
   - budgets BEFORE INSERT: Pro lolos; else bila baris `(org,category,month)`
     sudah ada → lolos (itu edit via UPSERT, bukan bucket baru); else hitung
     bucket bulan itu → ≥7 → `QUOTA_EXCEEDED`.

## 6. Desain klien

- `billing_service.dart`: tambah `planStatus(orgId)` via RPC `plan_status`
  → `{plan, source, expiresAt}`; catch (RPC belum ada/offline) → fallback
  `currentPlan()` lama + `expiresAt=null` + flag `stale`. Jangan blokir buta.
- `plan_limits.dart`: konstanta `freeWallets=7`, `freeBudgetsPerMonth=7`,
  `freeAiPerMonth=30`, `freeGoals=3`, `freeDebts=5`, `freeBills=5`; gate murni
  `canAddWallet/canAddBudget/canUseAi/canAddGoal/canAddDebt/canAddBill`
  (Pro ATAU used<limit) + `canXxxServer()` pola server-dulu-lokal-fallback
  untuk wallets/budgets/ai; Goals/Debts/Bills cek plan server via `planStatus`
  lalu bandingkan hitungan prefs lokal. `requirePro` tetap pola existing.
- `BillingScreen`: tampilkan masa Pro (`"Pro sampai {tgl}"` bila `expiresAt`,
  `"Pro"` bila permanen, paket aktif existing bila free); tile
  "Masukkan kode VIP" → dialog input → `redeem_vip_code` → snackbar hasil
  (`VIP_INVALID`/`VIP_EXHAUSTED` jujur, sukses → reload status); daftar limit
  Gratis diperbarui ke tabel §4.
- `ai_quota.dart` (baru, tipis): `aiAllowed(orgId)` = `check_quota('ai')`
  allowed (fallback prefs counter lokal bila server tak jawab — jangan blokir
  buta); `recordAiUse(orgId, kind)` setelah sukses. Pasang di: `ai_chat_screen`
  (tiap kirim), `vision_scan_service` (hanya jalur fallback AI, bukan ML Kit),
  `tx_input_sheet` (ketik-cepat AI). Mentok → `requirePro`.
- Wallet/budget: `create()` / `setBudget()` catch `QUOTA_EXCEEDED` →
  `requirePro` (pertahankan `_guardSpace` mapping Bendahara). Restore backup:
  petakan error jujur (hitung sukses/gagal; QUOTA → pesan kuota, bukan "gagal" generik).
- Goals/Debts/Recurring: saat tambah item ke-N+1 (free) → `requirePro`
  (cek plan via `planStatus`; offline/RPC-gagal → izinkan, jangan blokir buta;
  store caps `maxGoals/maxDebts/maxBills` tetap sebagai batas teknis atas).
- Strings baru (ID+EN, parity): `bl_pro_until` ("Pro sampai {d}"),
  `bl_vip_title`, `bl_vip_hint`, `bl_vip_redeem`, `bl_vip_ok`, `bl_vip_invalid`,
  `bl_vip_exhausted`, `bl_limit_wallets/budgets/ai/goals/debts/bills`,
  `q_ai_exceeded`, `q_wallet_exceeded`, `q_budget_exceeded`.
- Rilis: bump `2.73.0+251` + changelog; APK `SSR-SPACE-2.73.0-251-arm64.apk`.

## 7. Testing

- `test/plan_limits_test.dart`: gate murni baru (batas-1 lolos, tepat-batas
  ditolak, Pro selalu lolos; Goals/Debts/Bills murni).
- `supabase/test/rls_test.sql` += T34+: (a) redeem happy → entitlement ada + `plan_status` pro via vip;
  (b) kode salah → `VIP_INVALID`; (c) `max_uses=1` dipakai 2 user →
  kedua `VIP_EXHAUSTED`; (d) idempoten (redeem sama 2x, `used_count` tetap 1);
  (e) expiry dihormati (entitlement lampau → plan free);
  (f) `org_plan` pro via VIP-owner (org `plan='free'` tapi owner entitlement aktif);
  (g) wallet trigger (insert ke-8 free → `QUOTA_EXCEEDED`, Pro lolos);
  (h) budget trigger (bucket ke-8 baru ditolak, edit existing lolos, Pro lolos);
  (i) ai quota (`record_ai_usage` 30x → `check_quota('ai')` allowed=false);
  (j) client tak bisa SELECT `vip_codes` / INSERT `user_entitlements`.
  Fixture existing tak boleh pecah (batas fixture jauh di bawah cap baru).
- `run.sh`: tambah `../migration_20_entitlement.sql` ke loop baseline.
- CI: `rls-test.yml` + `apk.yml` (analyze 0 issue — `prefer_const_constructors`
  info pun fatal; `flutter test`; build arm64).
- Verifikasi device: redeem kode asli, expiry tampil, gate mentok muncul paywall,
  backup-restore jujur, offline tak blokir buta.

## 8. Non-goals (fase 2-5, jangan campur)

Widget/quick-entry, gamifikasi, announcements/roadmap/update-log, i18n baru,
multi-currency baru, tombol bayar Midtrans/webhook, App Check, top-up NFC.
Spec Midtrans lama (`2026-09-29-billing-midtrans-design.md`) tetap PAUSED.

## 9. Risiko & catatan jujur

- Goals/Debts/Recurring prefs-lokal = gate client-side (bisa diakali user
  teknis); dicatat jujur di UI/spec, bukan klaim "server-enforced".
- `plan_expires_at` + `subscriptions` disiapkan tapi webhook Midtrans belum ada —
  kolom expiry hanya ditulis VIP + (nanti) settlement manual/SQL.
- Race redeem (`max_uses=1`, 2 user bersamaan) ditutup atomic guard increment;
  tanpa itu kuota jebol.
- UPSERT budget tanpa pengecualian edit = bug pemblokir edit sah (ditutup §5.5).
