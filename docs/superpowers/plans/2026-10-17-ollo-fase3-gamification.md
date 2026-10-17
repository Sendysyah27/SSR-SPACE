# Fase 3 Gamifikasi Server Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Gamifikasi server-authoritative (streak 3/7/14/30/100 global + XP/level + 8 badge server-derivable) dengan notifikasi pencapaian + fallback lokal jujur.

**Architecture:** `migration_21` menambah tabel RPC-only `user_achievements` + 2 RPC (`gamification_status` hitung read-time & catat-saat-unlock, `ack_achievements` dedupe notif). Klien baca server-dulu, fallback hitung lokal (pola `plan_limits`). Badge sinyal-lokal (goal1/emsafe/save30) tetap klien.

**Tech Stack:** Flutter (stable) + Supabase Postgres (RLS + RPC SECURITY DEFINER) + `flutter_test` + RLS suite (`supabase/test/run.sh`) + `flutter_local_notifications`.

**Spec:** `docs/superpowers/specs/2026-10-17-ollo-fase3-gamification-design.md`

## Global Constraints

- Backend SEMUA via Supabase (RLS + RPC); JANGAN pernah pakai `api.olloweb.app`.
- Adaptasi konsep saja: tanpa merek/aset/teks Ollo; nama tetap SSR SPACE.
- Migration BARU `supabase/migration_21_gamification.sql`, jangan edit history; user jalankan manual di SQL Editor; kode klien WAJIB fallback bila RPC belum ada (DB lama/offline).
- Tabel baru RPC-only: RLS aktif TANPA policy client (pola `user_entitlements`/`heartbeat`).
- Semua fungsi baru: `language plpgsql/sql security definer set search_path = public`; `revoke all ... from public, anon; grant execute ... to authenticated`.
- `flutter analyze` wajib 0 issue (info `prefer_const_constructors` pun fatal); `dart` lokal SELALU `--enable-asserts`.
- Strings baru wajib ID+EN parity (`test/strings_parity_test.dart`).
- Bump Skema A: `pubspec.yaml` + `lib/utils/app_info.dart` identik + entri `assets/changelog_id.md`. Usulan `2.75.0+253`.
- Badge ids final: server = `streak3/streak7/streak14/streak30/streak100/tx100/save1m/clean30`; lokal = `goal1/emsafe/save30` (koleksi 11).
- Threshold: streak milestone `[3,7,14,30,100]`; `save1m` ≥1.000.000; `tx100` ≥100; level floors `[0,200,500,1000,2000,3500,5500]`.
- Jangan commit docs sendirian; jangan push tanpa diminta owner; APK hanya `*-arm64.apk` via pola `-p`.

## Review Focus

- **Streak mundur/edit tx:** user mencatat tx backdate atau menghapus tx → `streak_days` harus dihitung ulang benar (read-time recompute), bukan tersangkut angka lama.
- **Milestone tepat di batas:** streak tepat 3/7/14/30/100 → badge terbuka SEKALI dan notif muncul SEKALI; panggilan `gamification_status` berikutnya `new_badges` kosong.
- **Dua device / dua layar (Beranda+Arcade) dalam satu sesi:** notif pencapaian TIDAK dobel (ack segera setelah tampil).
- **DB lama/offline (RPC belum ada):** klien tak crash, tak blokir — hitung lokal, badge lokal tetap tampil.
- **`clean30` paritas:** kategori sub (`"Makan > Jajan"`) & kategori `null` → hasil server == fallback klien (grup lapis-atas).

---

## File Structure

- `supabase/migration_21_gamification.sql` (BARU): indeks `(created_by,date)`, tabel `user_achievements`, RPC `gamification_status`/`ack_achievements`.
- `supabase/test/run.sh` (UBAH 1 baris): tambah `../migration_21_gamification.sql` ke loop.
- `supabase/test/rls_test.sql` (TAMBAH T35+): streak, unlock idempoten, ack, isolasi, no-client-access, non-member.
- `lib/services/game_badges.dart` (UBAH): pecah server/lokal + `streak3`/`streak14` + `unlockedServerBadges`/`localUnlockedBadges`/`newBadgesIn`.
- `lib/services/calm_streak.dart` (UBAH): `streakMilestones` 3/7/14/30/100.
- `test/gamification_test.dart` (BARU): unit murni badge/streak.
- `lib/services/gamification_service.dart` (BARU): `GamificationStatus` + `fetchGamification`/`ackAchievements`/`syncAchievements`.
- `lib/services/achievement_notify.dart` (BARU): channel `ssr_achievement` + `showNew`.
- `lib/utils/strings.dart` (TAMBAH): `b_streak3_t/d`, `b_streak14_t/d`.
- `lib/screens/lainnya/arcade_screen.dart`, `lib/screens/beranda/beranda_screen.dart` (UBAH): server-dulu + fallback + hook notif.

---

### Task 1: Backend — `migration_21` + run.sh

**Files:**
- Create: `supabase/migration_21_gamification.sql`
- Modify: `supabase/test/run.sh` (1 baris loop)

**Interfaces:**
- Consumes: pola `supabase/migration_20_entitlement.sql` (RPC-only table + security definer + revoke/grant); kolom `transactions(created_by,date,category,type,amount,org_id)`; `budgets(org_id,category,month,limit_amount)`.
- Produces: tabel `user_achievements`; `public.gamification_status(uuid) -> jsonb {streak_days, streak_best, streak_today_done, streak_grace_used, xp, level, badges, new_badges}`; `public.ack_achievements(text[]) -> void`.

- [ ] **Step 1: Tulis migration (idempotent)**
  - `create index if not exists transactions_created_by_date_idx on transactions (created_by, date);`
  - `create table if not exists user_achievements (user_id uuid not null references auth.users(id) on delete cascade, badge_id text not null, unlocked_at timestamptz not null default now(), notified_at timestamptz, primary key (user_id, badge_id));` + `alter table user_achievements enable row level security;` + `create index if not exists user_achievements_user_notified_idx on user_achievements (user_id, notified_at);` (TANPA policy).
  - `gamification_status(p_org_id uuid)`: `NOT_AUTHENTICATED` bila `auth.uid()` null; `NOT_MEMBER` bila bukan member `p_org_id`; hitung streak dari `select distinct date from transactions where created_by = auth.uid() and date <= current_date order by date desc` (loop plpgsql: `streak_days` beruntun berakhir hari ini, grace bila hari ini kosong & kemarin ada; `streak_today_done`; `streak_grace_used`; `streak_best` run terpanjang) — konsisten `dailyStreak` klien; `tx_count`; `saved` (sum `type='out'` dan `lower(category) like '%tabung%' or lower(category) like '%saving%'`); `clean30` untuk org `p_org_id` bulan `to_char(current_date,'YYYY-MM')` (belanja `type='out'` non-tabungan digrup per `nullif(split_part(category,' > ',1),'')` → `'Lainnya'` bila null, dibanding `top_of(budget.category)`; ada budget DAN semua ≤ limit); unlock id yang memenuhi (8 badge) via `insert ... on conflict (user_id,badge_id) do nothing`; `new_badges` = `badge_id where notified_at is null`; `xp := least(tx_count,200)*10 + streak_days*5 + (count baris user_achievements)*50`; `level` dari floors `[0,200,500,1000,2000,3500,5500]`. Return jsonb.
  - `ack_achievements(p_ids text[])`: `NOT_AUTHENTICATED` bila null → `update user_achievements set notified_at = now() where user_id = auth.uid() and badge_id = any(p_ids) and notified_at is null;`.
  - `revoke all ... from public, anon; grant execute ... to authenticated` untuk kedua RPC. File idempotent (IF NOT EXISTS / CREATE OR REPLACE / DROP+CREATE bila perlu) + komentar header (fresh install urutan migration_20 → 21; user jalankan manual).
- [ ] **Step 2: Tambah ke `run.sh` loop**
  Ubah `... ../migration_20_entitlement.sql rls_test.sql` → `... ../migration_20_entitlement.sql ../migration_21_gamification.sql rls_test.sql`.
- [ ] **Step 3: Verifikasi lokal via Postgres (bila ada psql lokal)**
  Run: `SSR_RLS_DB_URL=postgresql://<lokal> bash supabase/test/run.sh`
  Expected: `== SUKSES: suite RLS lulus` (baseline + migration_21 apply bersih; T35+ belum ada). Bila tak ada Postgres lokal → andalkan CI `rls-test.yml`.
- [ ] **Step 4: Commit**
  ```bash
  git add supabase/migration_21_gamification.sql supabase/test/run.sh
  git commit -m "feat: migration_21 gamifikasi server (user_achievements + RPC)"
  ```

### Task 2: RLS T35+

**Files:**
- Modify: `supabase/test/rls_test.sql` (append T35+)
- Test: `supabase/test/run.sh` (dipakai ulang)

**Interfaces:**
- Consumes: Task 1 (tabel + RPC). Fixture existing (transaksi user `1111...` dgn `created_by` terisi) TERPAKAI untuk streak.
- Produces: assert T35+ hijau.

- [ ] **Step 1: Tulis T35+ (gagal-dulu bila RPC salah)**
  - T35a: dari `anon` → `gamification_status(...)` `permission denied` (revoke).
  - T35b: user login non-member `p_org_id` → `NOT_MEMBER`.
  - T35c: streak benar — insert tx `created_by` user pada hari ini, kemarin, 2 hari lalu → `streak_days >= 3` & `streak3` ∈ `badges`.
  - T35d: idempoten — panggil status 2x → `count(*) from user_achievements where user_id=... and badge_id='streak3'` = 1.
  - T35e: `new_badges` memuat id belum-notified → `ack_achievements('{streak3}')` → panggil lagi `new_badges` tak memuat `streak3`.
  - T35f: isolasi — badge user A tak muncul di `badges` status user B.
  - T35g: client `set role authenticated` → `select from user_achievements` / `insert` ditolak (0 baris / permission denied).
  - Assert toleran: hitung delta (fixture bisa sudah meng-unlock sebagian).
- [ ] **Step 2: Jalankan suite**
  Run: `SSR_RLS_DB_URL=postgresql://<lokal> bash supabase/test/run.sh` (atau CI `rls-test.yml`).
  Expected: `== SUKSES: suite RLS lulus` (T lama + T34 + T35+).
- [ ] **Step 3: Commit**
  ```bash
  git add supabase/test/rls_test.sql
  git commit -m "test: RLS T35+ gamifikasi (streak/unlock/ack/isolasi/no-client-access)"
  ```

### Task 3: Pure Dart — badges + streak milestones + unit test

**Files:**
- Modify: `lib/services/game_badges.dart`, `lib/services/calm_streak.dart`
- Test: `test/gamification_test.dart`

**Interfaces:**
- Consumes: `GameStats` existing (fields: `streakDays, totalSaved, txCount, txCapped, cleanMonth, goalsReached, emergencySafe, challengesDone, save30Done`).
- Produces: `const serverBadgeIds` (8, urut streak3/7/14/30/100, tx100, save1m, clean30), `const localBadgeIds` (`goal1,emsafe,save30`), `allBadges` = 11 (server lalu lokal), `List<String> unlockedServerBadges(GameStats)`, `List<String> localUnlockedBadges(GameStats)`, `List<String> newBadgesIn(Set<String> unlocked, Set<String> seen)`, `unlockedBadges(GameStats)` (gabungan, kompat), `newBadges(GameStats,Set)` (kompat); `const streakMilestones = [3,7,14,30,100]`, `nextMilestone`/`isMilestone` pakai list itu.

- [ ] **Step 1: Tulis test gagal**
  ```dart
  test('server & lokal disjoint, union = allBadges', () {
    expect(serverBadgeIds.toSet().intersection(localBadgeIds.toSet()), isEmpty);
    expect({...serverBadgeIds, ...localBadgeIds}, allBadges.map((b) => b.id).toSet());
    expect(allBadges.where((b) => b.id == 'streak3' || b.id == 'streak14').length, 2);
  });
  test('unlockedServerBadges batas', () {
    expect(unlockedServerBadges(const GameStats(streakDays: 3)), contains('streak3'));
    expect(unlockedServerBadges(const GameStats(streakDays: 2)), isEmpty);
    expect(unlockedServerBadges(const GameStats(streakDays: 14)), contains('streak14'));
    expect(unlockedServerBadges(const GameStats(txCount: 100)), contains('tx100'));
    expect(unlockedServerBadges(const GameStats(totalSaved: 1000000)), contains('save1m'));
    expect(unlockedServerBadges(const GameStats(cleanMonth: true)), contains('clean30'));
    expect(localUnlockedBadges(const GameStats(goalsReached: 1)), contains('goal1'));
    expect(localUnlockedBadges(const GameStats(emergencySafe: true)), contains('emsafe'));
    expect(localUnlockedBadges(const GameStats(save30Done: 1)), contains('save30'));
  });
  test('milestone streak 3/7/14/30/100', () {
    expect(streakMilestones, [3, 7, 14, 30, 100]);
    expect(nextMilestone(2), 3);
    expect(nextMilestone(3), 7);
    expect(isMilestone(14), isTrue);
    expect(isMilestone(8), isFalse);
    expect(newBadgesIn({'streak3', 'tx100'}, {'tx100'}), ['streak3']);
  });
  ```
- [ ] **Step 2: Verifikasi gagal**
  Run: CI `flutter test test/gamification_test.dart` (lokal tak ada flutter; `test/` pakai `flutter_test`).
  Expected: FAIL (simbol belum ada).
- [ ] **Step 3: Implement di `game_badges.dart` + `calm_streak.dart`**
  Pisah `_unlocked` → `_serverUnlocked`(streak/tx/save/clean) + `_localUnlocked`(goal/emsafe/save30); tambah `streak3`/`streak14` di `allBadges` (server dulu berurutan streak3,streak7,streak14,streak30,streak100,tx100,save1m,clean30 lalu lokal). Tambah helper baru. `calm_streak`: `streakMilestones` + update `nextMilestone`/`isMilestone`.
- [ ] **Step 4: Verifikasi lolos**
  Run: CI `flutter test test/gamification_test.dart` (atau full `flutter test`).
  Expected: PASS.
- [ ] **Step 5: Commit**
  ```bash
  git add lib/services/game_badges.dart lib/services/calm_streak.dart test/gamification_test.dart
  git commit -m "feat: pecah badge server/lokal + milestone streak 3/14"
  ```

### Task 4: Service gamifikasi + notifikasi + strings

**Files:**
- Create: `lib/services/gamification_service.dart`, `lib/services/achievement_notify.dart`
- Modify: `lib/utils/strings.dart`

**Interfaces:**
- Consumes: RPC `gamification_status`/`ack_achievements` (Task 1); `serverBadgeIds`/`localBadgeIds` (Task 3); pola `SupabaseConfig.client.rpc` + `save30_notify.dart` (channel + ID stabil + fail-silent).
- Produces: `class GamificationStatus { final int streakDays, streakBest, xp, level; final bool streakTodayDone, streakGraceUsed; final Set<String> badges; final List<String> newBadges; final bool stale; }`; `Future<GamificationStatus?> fetchGamification(String orgId)` (null saat error); `Future<void> ackAchievements(List<String> ids)`; `Future<void> syncAchievements(GamificationStatus? s)`; `class AchievementNotify { static const channelId='ssr_achievement'; static Future<void> showNew(List<String> badgeIds); }`.

- [ ] **Step 1: `gamification_service.dart`**
  `fetchGamification`: `SupabaseConfig.client.rpc('gamification_status', params: {'p_org_id': orgId})`, parse defensif (num→int, list→set/list) → `GamificationStatus(stale:false)`; catch → `null` (jangan lempar). Hash yang tak dikenal diabaikan. `ackAchievements`: rpc `ack_achievements` params `{'p_ids': ids}`, catch → `ErrorReporter.capture`. `syncAchievements`: bila `s?.newBadges` non-kosong → `AchievementNotify.showNew(s!.newBadges)` lalu `ackAchievements(s.newBadges)`.
- [ ] **Step 2: `achievement_notify.dart`**
  Channel `ssr_achievement` nama "Pencapaian" (Importance.high), ID stabil base `7400 + indeks`; `showNew(ids)` per id tampilkan judul `tr('b_${id}_t')`, isi `tr('b_${id}_d')`; init sekali; seluruhnya fail-silent (`ErrorReporter.capture`).
- [ ] **Step 3: Strings ID+EN**
  `b_streak3_t` ("3 hari beruntun"), `b_streak3_d`, `b_streak14_t` ("2 minggu beruntun"), `b_streak14_d` — tiap kunci dua bahasa (parity).
- [ ] **Step 4: Verifikasi**
  Run: CI `flutter analyze` (0 issue) + `flutter test test/strings_parity_test.dart`.
  Expected: PASS.
- [ ] **Step 5: Commit**
  ```bash
  git add lib/services/gamification_service.dart lib/services/achievement_notify.dart lib/utils/strings.dart
  git commit -m "feat: service gamifikasi server + notifikasi pencapaian"
  ```

### Task 5: Wiring Arcade + Beranda

**Files:**
- Modify: `lib/screens/lainnya/arcade_screen.dart`, `lib/screens/beranda/beranda_screen.dart`

**Interfaces:**
- Consumes: `fetchGamification`/`syncAchievements` (Task 4); `unlockedServerBadges`/`localUnlockedBadges`/`newBadgesIn` (Task 3).
- Produces: Arcade badge/level/streak dari server (fallback lokal), notif terpicu; Beranda streak dari server (fallback lokal). Perilaku lokal lama tetap ada saat server null.

- [ ] **Step 1: Arcade `_load` server-dulu**
  Setelah blok `st = GameStats(...)` lama (tetap dihitung untuk badge lokal + fallback): `final gs = await fetchGamification(orgId);` bila non-null → `xp = gs.xp; level dari gs.level; unlocked = {...gs.badges, ...localUnlockedBadges(st)}` dan `streak` server untuk badge eval; bila null → `unlocked = unlockedBadges(st).toSet(); xp = calcXp(...)`. `fresh = newBadgesIn(unlocked, seen)`. Setelah setState: `await syncAchievements(gs);`. `_LevelCard` pakai level dari state (bukan `levelFor(xp)` bila server memberi level) — tambah field `level` di state.
- [ ] **Step 2: Beranda streak server-dulu**
  `lib/screens/beranda/beranda_screen.dart:266-272`: `final gs = await fetchGamification(orgId);` bila non-null → `st = DailyStreak(days: gs.streakDays, todayDone: gs.streakTodayDone, graceUsed: gs.streakGraceUsed);` else `st = dailyStreak(await listDates(orgId), now);` (dalam try/catch yang sama). Setelah load: `await syncAchievements(gs);` (jangan gandakan notif — `syncAchievements` ack segera).
- [ ] **Step 3: Verifikasi**
  Run: CI `flutter analyze` + `flutter test` (regresi `gamification_test` + suite lama hijau).
  Expected: PASS.
- [ ] **Step 4: Commit**
  ```bash
  git add lib/screens/lainnya/arcade_screen.dart lib/screens/beranda/beranda_screen.dart
  git commit -m "feat: Arcade & Beranda baca gamifikasi server + fallback lokal"
  ```

### Task 6: Rilis (bump + changelog + CI + APK + docs)

**Files:**
- Modify: `pubspec.yaml`, `lib/utils/app_info.dart`, `assets/changelog_id.md`, `AGENTS.md`, `AUDIT.md`, `HANDOFF.md`

**Interfaces:**
- Consumes: Task 1-5 hijau.

- [ ] **Step 1: Bump + changelog**
  `version: 2.75.0+253` + `AppInfo.version = '2.75.0+253'` identik + seksi `## Yang baru di 2.75.0+253` (gamifikasi server lintas-device + streak 3/14 + notif pencapaian) + `Versi terpasang: 2.75.0+253.`
- [ ] **Step 2: CI hijau penuh**
  Run: push branch `feat/gamification-server` → `gh run watch $(gh run list --limit 1 --json databaseId --jq '.[0].databaseId') --exit-status`.
  Expected: `rls-test` + `apk` hijau (analyze 0 issue + test + build arm64).
- [ ] **Step 3: APK + instruksi migration**
  Run: `gh release download ci-apk -p "SSR-SPACE-2.75.0-253-arm64.apk" -D /sdcard/Download/SSR-SPACE/ --clobber` + instruksi owner: jalankan `supabase/migration_21_gamification.sql` di Dashboard → SQL Editor (sekali, idempotent).
  Expected: file ada, ukuran utuh (bandingkan byte rilis).
- [ ] **Step 4: Docs lokal (jangan commit docs sendirian)**
  Catat status Fase 3 di `AGENTS.md` + changelog `AUDIT.md` §7 + `HANDOFF.md` (fase 3 selesai). Docs ini ikut commit rilis berikutnya.
- [ ] **Step 5: Commit rilis**
  ```bash
  git add pubspec.yaml lib/utils/app_info.dart assets/changelog_id.md
  git commit -m "chore: bump 2.75.0+253 gamifikasi server"
  ```
