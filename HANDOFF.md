# HANDOFF — Adaptasi Ollo ke SSR SPACE (Fase 1: Entitlement + Limit)

> Dibuat: 2026-10-16 · Status: **FASE 3 SELESAI 2026-10-17 — branch `feat/gamification-server`, CI hijau, APK ada, menunggu merge**
> Fase 1 (entitlement) sudah merge ke main via PR #3. File ini arsip fase 1 + catatan fase 2 di bawah.

## 0. Cara lanjut di sesi baru

1. Baca `docs/prompts/2026-10-16-ollo-adapt-kickoff.md` (mandat besar 5 fase).
2. Baca file ini sampai habis.
3. Lanjutkan di bagian **"Langkah berikutnya"** (bagian 6). Jangan ngoding sebelum spec + plan disetujui owner (aturan kickoff).
4. Alur wajib: brainstorming → spec ke `docs/superpowers/specs/` → skill writing-plans → eksekusi per fase.

## 1. Konteks & keputusan yang SUDAH dikunci (dari Q&A sesi 2026-10-16)

Kickoff: adaptasi KONSEP 5 kapabilitas Ollo (com.ollo.ollo) ke SSR SPACE.
Urutan fase: (1) entitlement+limit, (2) widget+quick-entry, (3) gamifikasi, (4) announcements/roadmap/update-log, (5) i18n + multi-currency. **Sesi ini hanya fase 1.**

Keputusan owner yang sudah dikunci:

| # | Pertanyaan | Jawaban owner |
|---|-----------|---------------|
| 1 | Scope fase 1 | **Entitlement + VIP tanpa menyalakan Midtrans** (Midtrans PAUSED nunggu KYC; infra disiapkan supaya tinggal colok) |
| 2 | Dimensi limit baru | **Dompet (7) + Budget (7/bln) + AI kuota/bulan + Fitur lanjutan (Goals/Debts/Recurring)** — semua disetujui |
| 3 | Semantik VIP | **User-level**: redeem → semua workspace yang dia **owner** jadi Pro (durasi per kode) |
| 4 | Kuota AI | **30 panggilan AI/bulan**; dihitung: chat parse + fallback AI scan struk. ML Kit on-device tetap gratis tanpa batas |

Angka usulan yang BELUM di-approve (bagian desain, lihat §3): Goals 3 / Debts 5 / Recurring 5, VIP duration 30/90/365/permanen.

## 2. Hasil audit kode existing (yang beririsan — extend, jangan duplikasi)

Repo saat ini: **v2.72.0+250**, branch `main`, kerja bersih (hanya `docs/prompts/` + `docs/reference/` untracked). **Belum ada perubahan kode di sesi ini — hanya riset.**

### Fase 1 (entitlement) — existing
- `lib/services/plan_limits.dart` — konstanta `freeWorkspaces=2`, `freeMembers=3`, `freeAutoPerMonth=150`; gate `canCreateWorkspace/canInvite/canAutoTrack/canExportPdf`; `quotaCheck()` RPC `check_quota`; `canXxxServer()` pola server-dulu-lokal-fallback; `requirePro(context, reason)` = snackbar + push `BillingScreen`.
- `lib/services/billing_service.dart` — CUMA `currentPlan(orgId)` baca `organizations.plan` langsung + `proPrice=25000`. (Catatan: spec Midtrans lama ingin harga turun jadi 15000 & sumber kebenaran subscriptions — belum dieksekusi, PAUSED.)
- `lib/screens/lainnya/billing_screen.dart` — kartu Gratis/Pro statis, chip `bl_soon` (tanpa tombol bayar). Belum ada masukan kode VIP.
- Server (di `supabase/migration_squashed.sql`, bagian `migration_17_quotas.sql` baris ~1070-1247):
  - `public.org_plan(p_org_id)` = `organizations.plan` (tanpa expiry).
  - `public.check_quota(p_org_id, kind)` → kind `auto|members|workspaces`; `workspaces` user-scoped (hitung `org_members` user; pro = ada org diikuti dgn `o.plan='pro'` — query baca `o.plan` langsung, HARUS diganti `org_plan(o.id)` saat VIP masuk).
  - Trigger `trg_auto_quota` / `trg_member_quota` / `trg_workspace_quota` → raise `QUOTA_EXCEEDED`.
  - `enforce_workspace_quota()` juga baca `o.plan='pro'` langsung — sama, harus lewat `org_plan()`.
- Mapping error klien: `notif_track_service.dart` (`saveErrorStatus` cek `QUOTA_EXCEEDED`), `invite_token.dart` (`iv_quota`), `org_switcher_screen.dart:123`.
- Tabel `subscriptions` ada (migration_04) — `org_id, plan, status,...`; dipakai Midtrans nanti.
- `supabase/functions/create-snap/index.ts` ada; `midtrans-webhook` BELUM ada; workflow deploy functions BELUM ada.
- RLS test suite: `supabase/test/run.sh` apply: `setup.sql` → `schema.sql` → `migration_squashed.sql` → `rls_test.sql` (157 range T; suite panjang). **`run.sh` harus ditambah `../migration_20_entitlement.sql` saat implementasi.**

### Fase 2-5 (untuk konteks, JANGAN dikerjakan sesi fase 1)
- Widget: `lib/services/today_widget.dart`, `widget_snapshot.dart` + provider native di-inject CI (`apk.yml`) — QS tile + deep link refresh sudah ada pola.
- Gamifikasi: `calm_streak.dart`, `game_badges.dart` (9 badge), `game_challenge.dart`, `game_level.dart`, `game_store.dart`, `save30.dart`; layar `arcade_screen.dart`.
- Update-log: `lib/screens/lainnya/update_log_screen.dart` + `assets/changelog_id.md`; announcements & roadmap BELUM ada.
- i18n/currency: `lib/utils/strings.dart` (ID/EN, `tr()`, `stringTable`, ada `test/strings_parity_test.dart` — kunci ID/EN wajib parity); `lib/services/currency.dart` (kurs open.er-api.com + cache, `amt()`).

### Temuan penting teknis (jangan lupa)
- **Budget pakai UPSERT** (`budget_service.dart setBudget`, onConflict `org_id,category,month`) → trigger BEFORE INSERT budget harus: kalau baris (org,category,month) sudah ada → lolos (itu edit, bukan bucket baru); baru hitung cap untuk baris baru. Tanpa ini, edit budget ke-7 saat sudah 7 bucket = diblok.
- **Wallet create** ada di `wallet_service.dart create()` (dibungkus `_guardSpace` untuk mode Bendahara — pertahankan pola).
- **Owner org** = member `role='owner'` di `org_members` (bisa >1 owner; jangan pakai `created_by` saja).
- Hash kode: pola invite — `encode(sha256(convert_to(upper(trim(text)),'UTF8')),'hex')`, **sha256 bawaan PG, tanpa pgcrypto**.
- Pola idempoten + atomic guard increment: contoh `join_org_by_invite()` di squashed (~baris 577-642).
- Goals/Debts/Recurring/tagihan: **prefs lokal** (bukan Supabase) → gate client-side saja (catatan jujur di spec).
- AI call sites (untuk gate kuota): `ai_chat_screen.dart`, `ai_draft_screen.dart`, `vision_scan_service.dart` (fallback struk), `tx_input_sheet.dart` (ketik cepat AI), parser: `firebase_ai_parser.dart` / `ai_zen_client.dart` / `ai_cli_client.dart`.
- Migration berikutnya = **`migration_20_*`** (02..19 sudah disquash ke `migration_squashed.sql`; fresh install = `schema.sql` + `migration_squashed.sql` + migration baru). User jalankan manual di SQL Editor.
- Version bump wajib (Skema A): `pubspec.yaml` + `AppInfo.version` + entri `assets/changelog_id.md`.
- Verifikasi = CI (flutter tidak ada di Termux): `apk.yml` + `rls-test.yml`.

## 3. Desain Bagian 1 yang SUDAH dipresentasikan (menunggu approval owner)

**(dituangkan apa adanya — kalau owner sudah komentar, update dulu di sini lalu lanjut)**

**Pendekatan terpilih:** `user_entitlements` (user-level VIP) + `org_plan()` diperluas (pro bila org pro belum expired ATAU owner-nya punya entitlement aktif). Alternatif dibuang: (a) loop tulis plan ke semua org saat redeem → org baru tak dapat; (b) tabel profil user → tidak ada di skema.

**`migration_20_entitlement.sql`** (idempotent):
1. `organizations` + `plan_expires_at timestamptz` (null = tanpa kedaluwarsa; siap Midtrans: settlement → now()+30d).
2. Tabel baru:
   - `user_entitlements` (user_id, plan='pro', expires_at null=permanen, source `vip_code|manual`, source_ref, granted_at) — RLS tanpa policy client (RPC-only).
   - `vip_codes` (code_hash unique, duration_days null=permanen, max_uses, used_count, note) — client nol akses; kode dibuat owner via SQL Editor (contoh insert di komentar migration).
   - `ai_usage` (user_id, org_id, kind, created_at, index user+org+created_at) + pg_cron retention 90 hari (guarded pola migration_13).
3. `org_plan()` diperluas (org pro+expiry ATAU owner entitlement aktif) → semua trigger ikut otomatis; 2 query lama `o.plan='pro'` (check_quota workspaces + enforce_workspace_quota) diganti `org_plan(o.id)`.
4. RPC baru:
   - `plan_status(p_org_id)` → `{plan, source org|vip|null, expires_at}`.
   - `redeem_vip_code(p_code)` → validate → idempoten (user sama + kode sama = kembalikan entitlement lama, tidak makan kuota) → insert → `{expires_at, duration_days}`; error `VIP_INVALID`/`VIP_EXHAUSTED`.
   - `check_quota` + kind baru: `wallets` (7/org), `budgets` (7/org/bulan), `ai` (30/user/org/bulan); `record_ai_usage(p_org_id, p_kind)`.
5. Trigger baru: wallets BEFORE INSERT (≥7 → QUOTA_EXCEEDED); budgets BEFORE INSERT (≥7 bucket bulan itu → tolak; edit baris existing lolos).

**Tabel limit final (usulan, belum approve angka Goals/Debts/Recurring):**

| Fitur | Gratis | Pro |
|---|---|---|
| Workspace / Anggota / Auto-track | 2 / 3 / 150-bln (existing) | bebas |
| Dompet | 7 | bebas |
| Budget | 7/bulan | bebas |
| AI (chat + fallback struk) | 30/bulan | bebas |
| Goals / Utang-piutang / Tagihan berulang | 3 / 5 / 5 | bebas |
| Ekspor PDF | — | ✓ (existing); CSV/XLSX tetap gratis |

**Catatan jujur:** wallet/budget/AI ditegakkan server; Goals/Debts/Recurring gate client-side (memakai plan server sebagai sumber kebenaran plan).

**Media pembawa keputusan:** Bagian 1 ini BELUM di-approve saat sesi pause — owner minta handoff dulu. Sesi baru: tampilkan ringkas lagi / tanyakan apakah sudah oke, lanjut Bagian 2.

## 4. Bagian 2 desain yang BELUM dipresentasikan (siapkan saat lanjut)

Isi yang direncanakan (sudah riset, tinggal ditulis rapi):
- `billing_service.dart`: `planStatus(orgId)` via RPC `plan_status` + fallback baca lama bila RPC gagal (DB lama/offline).
- `plan_limits.dart`: konstanta baru + gate baru; `requirePro` tetap pola.
- `BillingScreen`: masa aktif Pro ("Pro sampai {tgl}"), tile "Masukkan kode VIP" → dialog → redeem → snackbar hasil (invalid/expired/exhausted), daftar limit Gratis diperbarui.
- Gate AI: helper `ai_quota.dart` (`aiAllowed` pre-check via check_quota('ai') + fallback prefs; `recordAiUse` setelah sukses) dipasang di ai_chat_screen + vision_scan_service (fallback) + tx_input_sheet.
- Gate wallet/budget: catch `QUOTA_EXCEEDED` → `requirePro` di layar wallet & dialog budget (plus restore backup: map error jujur).
- Gate lokal: goals_screen/debts_screen/recurring_bills_screen saat tambah item ke-N → paywall.
- Strings baru ID+EN (wajib parity test), changelog, bump 2.73.0+251 (atau sesuai).
- Test: `plan_limits_test` (gate baru), RLS T34+ (redeem happy/invalid/exhausted/idempoten, expiry dihormati, org_plan pro via VIP, wallet/budget quota trigger, ai quota, client tak bisa baca vip_codes/tulis user_entitlements), `run.sh` + `rls_test.sql` diperbarui.

## 5. Aturan yang mengikat (dari kickoff + AGENTS.md)

- Backend SEMUA via Supabase (RLS + RPC); **jangan pernah pakai api.olloweb.app** (milik Ollo).
- Adaptasi konsep saja — tanpa merek/aset/teks Ollo; nama tetap SSR SPACE.
- Dilarang langsung koding sebelum spec fase + plan disetujui owner.
- Migration: tulis file baru (jangan edit history); jalankan manual oleh user; dieksekusi di app = HANYA jika sudah ada di DB (kode yang butuh migration baru harus lulus CI tapi dimaklumi sampai user menjalankan).
- Jangan commit tanpa diminta owner. Docs (HANDOFF/spec/plan) boleh ikut commit fitur berikutnya, jangan commit docs sendirian.
- Bump versi + changelog untuk tiap perubahan kode yang di-push.
- Deliverable file → `/sdcard/Download/SSR-SPACE/`.

## 6. Langkah berikutnya (checklist sesi baru)

SELESAI 2026-10-16 (semua dicentang):

- [x] Konfirmasi owner atas desain Bagian 1 (angka 7/7/30/3/5/5 + semantik VIP owner + kode dibuat via SQL Editor).
- [x] Presentasikan Bagian 2 (klien/UX/test/rilis) → approval.
- [x] Tulis spec: `docs/superpowers/specs/2026-10-16-ollo-fase1-entitlement-design.md` (self-review placeholders/konsistensi/scope/ambiguitas).
- [x] Review spec oleh owner → skill **writing-plans** → `docs/superpowers/plans/2026-10-16-ollo-fase1-entitlement.md`.
- [x] Eksekusi SDD (9 task + T8/T9, review per task + final review + 2 fix wave) → branch `feat/entitlement-vip`, CI hijau (rls-test run `38917562148`, build-apk run `38917934095`), APK `SSR-SPACE-2.73.0-251-arm64.apk` (41.160.963 byte) di `/sdcard/Download/SSR-SPACE/`.
- [ ] OWNER: jalankan `supabase/migration_20_entitlement.sql` sekali di Dashboard → SQL Editor (idempotent).
- [ ] OWNER: putuskan merge — PR `feat/entitlement-vip` → `main` (buat via `gh pr create`, CI PR jalan otomatis) atau merge langsung. Setelah merge: device-check (redeem → masa Pro, dompet-8/budget-8/AI-31 → paywall, edit-budget lolos, offline → stale-allow).
- [ ] Fase berikutnya (fase 2 widget+quick-entry) bikin kickoff/handoff baru; file ini arsip.

## 7. Referensi bahan

- Kickoff: `docs/prompts/2026-10-16-ollo-adapt-kickoff.md`
- Laporan RE Ollo: `/sdcard/Download/revapp-ollo/LAPORAN-ollo.md` (+ `fitur.json`, `ollo-reveng-v1.7.7.zip`)
- Screenshot Ollo: `docs/reference/ollo-screenshots/` (12 SS — pola flow: quick entry numpad+grid kategori, wallet grouping + bottom bar AI chip FREE, home period tabs + menu grid, profile preferences grid)
- Spec Midtrans lama (PAUSED): `docs/superpowers/specs/2026-09-29-billing-midtrans-design.md`

## Fase 2 — Widget + Quick-Entry (SELESAI 2026-10-17)

- Spec: `docs/superpowers/specs/2026-10-17-ollo-fase2-widget-design.md`, plan: `docs/superpowers/plans/2026-10-17-ollo-fase2-widget-design.md`, ledger: `.superpowers/sdd/2026-10-17-ollo-fase2-widget-design/`.
- Scope approved owner: 3 widget (Hari-ini+Budget+Saldo), ketuk → sheet langsung (PIN-gate antre), QS+shortcut → sheet, deep-link `ssrspace://quick-entry`, share-gambar ikut (tanpa iOS).
- Eksekusi SDD: T1 quick_link murni → T2 snapshot → T3 wiring+share → T4 native inject → T5 strings+rilis 2.74.0+252; review per task + final review Yes + 2 one-liner.
- CI saga: mounted-guards 12x → dep 1.9.0 compileSdk 37 (pin 1.8.1) → JVM target (patch CI Java+Kotlin 17) → shortcut @string → assert salah alamat → HIJAU (rls + build-apk). APK `SSR-SPACE-2.74.0-252-arm64.apk` (41.234.307, ZIP-OK) di `/sdcard/Download/SSR-SPACE/`. Tanpa migration.
- Sisa owner: merge ke main + device-check (3 widget, ketuk → sheet tipe benar, QS/shortcut, share 1 & multi, terkunci → antre).

## Fase 3 — Gamifikasi Server (SELESAI 2026-10-17)

- Spec: `docs/superpowers/specs/2026-10-17-ollo-fase3-gamification-design.md`, plan: `docs/superpowers/plans/2026-10-17-ollo-fase3-gamification.md`, ledger: `.superpowers/sdd/2026-10-17-ollo-fase3-gamification/`.
- Scope approved owner: gamifikasi server-authoritative (streak global lintas-device, XP/level server, 8 badge server-derivable) + notifikasi pencapaian + fallback lokal jujur; badge sinyal-lokal (goal1/emsafe/save30) tetap klien; tantangan mingguan tetap lokal.
- Eksekusi SDD (6 task, commits `8e4397e` `ac18a89` `09c5bcc` `7871561` `7b33d34` `3608c2f`): T1 `migration_21` + `run.sh` → T2 RLS T35+ → T3 `game_badges`/`calm_streak` → T4 `gamification_service`+`achievement_notify`+strings → T5 wiring Arcade+Beranda → T6 rilis 2.75.0+253.
- Server: `migration_21_gamification.sql` (indeks `transactions(created_by,date)`, tabel RPC-only `user_achievements`, RPC `gamification_status` read-time + `ack_achievements` dedupe). Klien: server-dulu, return null → fallback lokal (tidak blokir).
- **OWNER WAJIB: jalankan `supabase/migration_21_gamification.sql` SEKALI di Dashboard → SQL Editor (idempotent).** Cross-device baru aktif setelah itu.
- CI hijau: rls-test `38991705492` + build-apk `38991702839` (analyze 0, test lulus, build arm64). APK `SSR-SPACE-2.75.0-253-arm64.apk` (41.234.475 B) di `/sdcard/Download/SSR-SPACE/`.
- Sisa owner: merge ke main + device-check (catat tx beberapa hari → streak naik, milestone 3 hari → notif "Pencapaian", HP-2 → streak/badge sama, offline → fallback lokal tanpa crash).
- Fix wave final review (2.75.0+254, klien saja tanpa migration): `fallbackXp` bersama Beranda+Arcade (server menang saat ada), notif pencapaian sekali (seen-filter + ack semua + serial sesi), paritas clean30 `topOf`, buang `stale`/`streakBest`, id notif stabil per badge, tes parser+sync.
