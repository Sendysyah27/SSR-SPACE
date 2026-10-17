# Spec Fase 3 — Gamifikasi server (adaptasi konsep Ollo)

> Tanggal: 2026-10-17 · Status: **APPROVED owner (desain Q&A)** → lanjut writing-plans.
> Repo: `~/SSRSPACE`, main = `1eb2cab` (fase 2 widget sudah merge, v2.74.0+252).
> Sesi ini HANYA fase 3 dari kickoff `docs/prompts/2026-10-16-ollo-adapt-kickoff.md`.
> Fase 4 (announcements/roadmap/update-log) & fase 5 (i18n + multi-currency) non-scope.
> Aturan mengikat: backend SEMUA via Supabase (RLS+RPC); jangan pernah pakai
> `api.olloweb.app`; adaptasi konsep saja (tanpa merek/aset/teks Ollo).

## 1. Tujuan & kriteria sukses

Menjadikan gamifikasi **server-authoritative & lintas-device** (paritas konsep Ollo:
streak 3/7/14/30/100 + achievement + notifikasi), dengan model yang dipilih owner:
**Ollo-core global** — server otoritatif untuk streak, XP/level, dan badge yang
bisa diturunkan server; badge bersinyal-lokal tetap lokal.

- Server jadi sumber kebenaran tunggal untuk: streak harian (global lintas
  workspace user), XP/level, dan 8 badge server-derivable.
- Badge/сигnal lokal (Goals `goal1`, darurat `emsafe`, tantangan `save30`) tetap
  dihitung klien dari prefs — dijujurkan di UI/spec, bukan klaim server-enforced.
- Notifikasi pencapaian (termasuk milestone streak 3/7/14/30/100) via notifikasi
  lokal; dedupe lintas-device lewat `notified_at` server.
- Fallback jujur: bila RPC belum ada (DB belum dimigrasi) atau offline, klien
  hitung lokal seperti sekarang (`server-dulu-lokal-fallback`) — tidak blokir buta.
- Sukses = CI hijau (`apk.yml` + `rls-test.yml`), suite RLS T35+ lulus, unit murni
  lulus lokal (`dart --enable-asserts`), APK arm64 terunduh, user menjalankan
  `migration_21` manual.

## 2. Batasan (constraints)

- Dilarang koding sebelum spec+plan (memenuhi: desain di-approve owner via Q&A
  2026-10-17, opsi **A** read-time RPC + catat-saat-unlock). Eksekusi setelah plan
  dari skill writing-plans.
- Migration: file BARU `supabase/migration_21_gamification.sql`, jangan edit
  history. Fresh install = `schema.sql` + `migration_squashed.sql` +
  `migration_20_entitlement.sql` + `migration_21_gamification.sql`. DB produksi =
  user jalankan `migration_21` manual di SQL Editor. Kode klien yang butuh RPC
  baru WAJIB fallback (lulus CI, dimaklumi sampai user migrasi).
- Jangan commit docs sendirian; jangan push tanpa diminta owner.
- Bump versi Skema A: `pubspec.yaml` + `lib/utils/app_info.dart` identik + entri
  `assets/changelog_id.md`. Usulan: `2.75.0+253`.
- Deliverable → `/sdcard/Download/SSR-SPACE/`, hanya `*-arm64.apk`, unduh berpola
  `-p "<nama-file-versi-baru>"`.
- Flutter tidak ada di Termux → verifikasi via CI. Logika murni TDD via
  `dart --enable-asserts` (wajib flag; tanpa itu PASS palsu).
- i18n parity: setiap kunci strings baru wajib ID+EN (`test/strings_parity_test.dart`).
- RLS: tabel baru **RPC-only** (RLS aktif TANPA policy client) pola
  `user_entitlements`/`vip_codes`/`ai_usage`/`heartbeat`; RPC `SECURITY DEFINER`
  + `set search_path=public`; `revoke all from public, anon; grant execute to authenticated`.

## 3. Konteks existing (extend, jangan duplikasi)

- `lib/services/calm_streak.dart` — `dailyStreak(dates, now)` (grace 1 hari),
  `nextMilestone`/`isMilestone` = **7/30/100** saat ini → perpanjang ke 3/7/14/30/100.
- `lib/services/game_badges.dart` — `GameStats` + `allBadges` (9): streak7/30/100,
  save1m, clean30, goal1, tx100, emsafe, save30. `unlockedBadges`/`newBadges`.
  → pecah jadi `serverBadgeIds` (streak3/7/14/30/100, tx100, save1m, clean30) vs
  `localBadgeIds` (goal1, emsafe, save30); tambah `streak3`,`streak14` (koleksi 11).
- `lib/services/game_level.dart` — `calcXp`, `levelFloors=[0,200,500,1000,2000,3500,5500]`,
  `levelFor`, `levelProgress`, `xpToNext` (murni, dipakai ulang server-side).
- `lib/services/game_challenge.dart` — 3 tantangan mingguan, **tetap lokal**.
- `lib/services/game_store.dart` — prefs `game_seen_badges` (chip "Baru", device-local),
  `game_challenges`. Tetap.
- `lib/screens/lainnya/arcade_screen.dart` — `_load()` hitung GameStats lokal
  (streak via `TransactionService().listDates(orgId)`, saved, txCount, cleanMonth,
  goals/emsafe, tantangan) + render level/badge/tantangan. Sumber streak/XP/level
  jadi server (fallback lokal).
- `lib/screens/beranda/beranda_screen.dart:266-272` — kartu streak pakai
  `dailyStreak(listDates(orgId))` (org-scoped) → jadi global server (fallback lokal).
- `lib/services/save30_notify.dart` — pola notif lokal: channel + ID stabil +
  prefs lacak + fail-silent + `ErrorReporter.capture`. Contoh untuk `achievement_notify.dart`.
- `lib/utils/strings.dart` — kunci `b_<id>_t`/`b_<id>_d` (badge), `game_*`, `lvl_*`,
  `ch_*`. Kunci baru wajib parity ID+EN.
- `lib/services/transaction_service.dart:339` — `add()` auto-isi
  `created_by = auth.currentUser?.id` → streak "milik user" = `created_by = auth.uid()`.
  `listDates(orgId,{limit})` untuk fallback lokal.
- `saving.dart:8` — `isSavingCategory` = `category` mengandung `tabung`/`saving`
  (case-insensitive; berlaku juga pada `"Tabungan > X"`) → direplikasi di SQL:
  `lower(category) like '%tabung%' or lower(category) like '%saving%'`.
- Server existing `supabase/migration_20_entitlement.sql` — pola RPC/RPC-only
  table/revoke-grant/`NOT_MEMBER`/`NOT_AUTHENTICATED` yang WAJIB ditiru.
- RLS harness `supabase/test/run.sh` loop: `setup.sql` → `schema.sql` →
  `migration_squashed.sql` → `migration_20_entitlement.sql` → `rls_test.sql`.
  **Wajib tambah `../migration_21_gamification.sql`** sebelum `rls_test.sql`.
- Suite RLS terakhir = T34j (`supabase/test/rls_test.sql`) → lanjut T35+.

## 4. Desain backend — `supabase/migration_21_gamification.sql` (idempotent)

1. Indeks pendukung streak global:
   `create index if not exists transactions_created_by_date_idx on transactions (created_by, date);`
2. Tabel **`user_achievements`** (RPC-only, tanpa policy client):
   - `user_id uuid not null references auth.users(id) on delete cascade`
   - `badge_id text not null`
   - `unlocked_at timestamptz not null default now()`
   - `notified_at timestamptz` (null = belum dinotifikasi; dedupe lintas-device)
   - `primary key (user_id, badge_id)`
   - index `(user_id, notified_at)`
   - `alter table ... enable row level security;` (TANPA policy → client ditolak).
3. RPC `gamification_status(p_org_id uuid) returns jsonb` (SECURITY DEFINER,
   `set search_path=public`; `NOT_AUTHENTICATED` bila `auth.uid()` null;
   `NOT_MEMBER` bila bukan member `p_org_id`):
   - **Streak (global user):** ambil `distinct date` dari `transactions`
     `where created_by = auth.uid()` and `date <= current_date`, urut menurun →
     plpgsql hitung `streak_days` (beruntun berakhir hari ini, grace: kalau hari ini
     kosong tapi kemarin ada → anchor kemarin, konsisten `dailyStreak`), dan
     `streak_best` (run terpanjang dari seluruh tanggal).
   - **txCount** = `count(*) from transactions where created_by = auth.uid()`.
   - **saved** = `sum(amount)` `where created_by = auth.uid() and type='out'`
     `and (lower(category) like '%tabung%' or lower(category) like '%saving%')`.
   - **clean30** = org `p_org_id` bulan berjalan: ada budget DAN setiap budget
     `(spend ≤ limit)`, belanja `type='out'`, kategori tabungan diabaikan, kategori
     `null`→"Lainnya". Konteks org karena budget memang per-org — dijujurkan di UI/spec.
     **Paritas wajib:** belanja dikelompokkan per kategori lapis-atas
     (`split_part(category,' > ',1)`, sama `topOf` klien) dan dibandingkan ke
     `top_of(budget.category)`; implementasi WAJIB menyamakan jalur fallback klien
     agar server↔lokal tak flip-flop (perbaiki `arcade_screen` bila perlu).
   - **badge server-derivable** (8): `streak3` (streak≥3), `streak7` (≥7),
     `streak14` (≥14), `streak30` (≥30), `streak100` (≥100), `tx100` (txCount≥100),
     `save1m` (saved≥1.000.000), `clean30` (true).
   - Unlock: untuk id yang memenuhi dan belum ada → `insert into user_achievements
     (user_id, badge_id) values (auth.uid(), id) on conflict (user_id, badge_id) do nothing;`
   - `new_badges` = `badge_id from user_achievements where user_id=auth.uid()
     and notified_at is null`.
   - **xp** = `least(txCount,200)*10 + streak_days*5 + (jumlah badge di
     user_achievements)*50`; level via ambang `[0,200,500,1000,2000,3500,5500]`
     (server hitung, atau klien hitung ulang dengan `levelFor` — sama hasil).
   - Return: `{streak_days, streak_best, streak_today_done, streak_grace_used,
     xp, level, badges:[{id,unlocked_at}], new_badges:[id...]}`.
     (`streak_today_done`/`streak_grace_used` disertakan agar kartu Beranda yang
     pakai `DailyStreak` tetap utuh tanpa sumber kedua.)
4. RPC `ack_achievements(p_ids text[]) returns void` (SECURITY DEFINER; auth wajib):
   `update user_achievements set notified_at = now()
    where user_id = auth.uid() and badge_id = any(p_ids) and notified_at is null;`
5. Grant: `revoke all on function ... from public, anon; grant execute ... to authenticated;`
   untuk `gamification_status` + `ack_achievements`. Tidak ada trigger/kolom baru di
   tabel existing (index saja). Tidak ada pg_cron.

**Definisi global vs org (dijujurkan):** streak/tx100/save1m dihitung dari transaksi
yang `created_by = auth.uid()` lintas SEMUA workspace (paritas Ollo single-user);
`clean30` memakai konteks `p_org_id` karena budget per-org.

## 5. Desain klien

- `lib/services/gamification_service.dart` (baru):
  - `class ServerBadge { final String id; final DateTime? unlockedAt; }`
  - `class GamificationStatus { final int streakDays, streakBest, xp, level;
    final Set<String> badges; final List<String> newBadges; final bool stale; }`
  - `Future<GamificationStatus?> fetchGamification(String orgId)` — RPC
    `gamification_status`; **return null** saat error (pemanggil fallback lokal).
    Jangan lempar.
  - `Future<void> ackAchievements(List<String> ids)` — RPC `ack_achievements`,
    fail-silent (`ErrorReporter.capture`).
  - `Future<void> syncAchievements(GamificationStatus? s)` — **satu-satunya** hook
    notif: bila `s?.newBadges` tak kosong → `AchievementNotify.showNew` lalu
    `ackAchievements` (ack segera → pemanggilan berikutnya kosong, cegah
    double-notif Beranda+Arcade di sesi sama). Dipanggil dari Beranda & Arcade.
- `lib/services/game_badges.dart`:
  - `const serverBadgeIds = ['streak3','streak7','streak14','streak30','streak100','tx100','save1m','clean30'];`
  - `const localBadgeIds = ['goal1','emsafe','save30'];`
  - `allBadges` = gabungan (server dulu, lalu lokal) → koleksi 11 badge.
  - `unlockedServerBadges(GameStats)` (evaluator server-derivable, untuk fallback
    lokal & unit test) + `localUnlockedBadges(GameStats)` (goal1/emsafe/save30).
  - `unlockedBadges` tetap (gabungan) untuk kompat.
- `lib/services/calm_streak.dart`:
  - `nextMilestone` + `isMilestone` → `[3,7,14,30,100]`. (Konstanta `streakMilestones`
    dipakai server/strings bila perlu.)
- `lib/screens/lainnya/arcade_screen.dart`:
  - `_load()`: coba `fetchGamification(orgId)`; bila non-null → streak/xp/level dari
    server, badge server dari status; bila null → jalur lokal existing (tetap ada).
  - Merge badge: `unlocked = serverBadges ∪ localUnlockedBadges(stats)`.
  - Chip "Baru" pakai `game_seen_badges` (device-local, semua badge) — perilaku lama.
  - Setelah load: `syncAchievements(status)` (hook notif terpusat, §5 service).
- `lib/screens/beranda/beranda_screen.dart`:
  - Kartu streak: coba `fetchGamification(orgId)?.streakDays`; null → `dailyStreak`
    lokal. Copy milestone mengikuti `calm_streak` baru (3/7/14/30/100).
  - Hook `syncAchievements(status)` usai fetch (notif pencapaian; tanpa polling).
- `lib/services/achievement_notify.dart` (baru): channel `ssr_achievement`
  ("Pencapaian"), ID stabil (mis. base `7400` + indeks), pola `save30_notify`
  (init sekali, fail-silent). `showNew(List<String> ids)`: tampilkan judul
  `b_<id>_t` + isi `b_<id>_d` per badge baru (termasuk milestone streak).
- Strings baru (ID+EN, parity): `b_streak3_t`/`b_streak3_d`,
  `b_streak14_t`/`b_streak14_d`, `ach_notif_title` (opsional), dan kunci status bila
  perlu (`ach_synced`/`ach_local` bila menandai fallback). Minimal 4 kunci badge baru.
- Rilis: bump `2.75.0+253` + entri `assets/changelog_id.md`.

## 6. Testing

- Unit murni (lokal `dart --enable-asserts`):
  - `test/gamification_test.dart`: `serverBadgeIds`/`localBadgeIds` disjoint +
    union == `allBadges`; `unlockedServerBadges` (streak/tx/save/clean batas);
    `calm_streak` milestone baru (3/7/14/30/100, `isMilestone`).
- `supabase/test/rls_test.sql` += T35+:
  - T35a: `gamification_status` dari `anon` → `permission denied` (revoke).
  - T35b: user login non-member `p_org_id` → `NOT_MEMBER`.
  - T35c: streak dihitung benar (fixture 3 hari beruntun → `streak_days=3`,
    `streak3` muncul di `badges`).
  - T35d: unlock **idempoten** (panggil 2x → 1 baris `user_achievements`,
    `unlocked_at` tetap).
  - T35e: `new_badges` berisi id belum-notified; `ack_achievements([...])` →
    `new_badges` berikutnya kosong (`notified_at` terisi).
  - T35f: isolasi antar-user (badge user A tak muncul di status user B).
  - T35g: client TAK bisa `select`/`insert` `user_achievements` langsung
    (permission denied / 0 baris).
  - Fixture existing tak boleh pecah (transaksi fixture bisa memicu unlock — assert
    harus toleran/hitung delta, bukan menganggap tabel kosong).
- `supabase/test/run.sh`: tambah `../migration_21_gamification.sql` ke loop baseline.
- CI: `rls-test.yml` + `apk.yml` (analyze 0 issue — info `prefer_const_constructors`
  pun fatal; `flutter test`; build arm64).
- Verifikasi device (owner): catat tx beberapa hari → streak naik, milestone 3 hari
  → notif pencapaian muncul, install device-2 → streak/badge sama (lintas-device),
  badge lokal (goal/save30) tetap tampil, offline → fallback lokal tanpa crash.

## 7. Non-goals (fase lain / jangan campur)

- Announcements/Roadmap/Update-log (fase 4); i18n & multi-currency baru (fase 5).
- Push server (FCM) — notifikasi tetap lokal (belum ada FCM di proyek).
- Migrasi tantangan mingguan (`game_challenge`) & save30 ke server — tetap lokal.
- Gating berbayar gamifikasi (gamifikasi gratis untuk semua, paritas Ollo).
- Widget/quick-entry (fase 2, sudah selesai) — tak disentuh.

## 8. Risiko & catatan jujur

- **Read-time compute:** tiap `gamification_status` men-scan transaksi user
  (≤2000, indeks `(created_by,date)` baru). Aman untuk skala sekarang; bila volume
  naik → materialisasi state (opsi B) jadi follow-up.
- **XP berubah arti:** badge lokal (goal1/emsafe/save30) tidak lagi menyumbang XP
  (level server-derivable). Badge lokal tetap tampil; motivasi lewat koleksi, bukan
  XP. Dijujurkan di spec/UI.
- **`clean30` org-scoped** (budget memang per-org) walau streak global — campuran
  scope yang disengaja & didokumentasikan.
- **Fallback lokal bisa beda** dari server (feat baru belum dimigrasi / offline):
  klien tandai status `stale` bila perlu; tak blokir. Cross-device baru aktif
  setelah user menjalankan `migration_21`.
- **Dedupe notif lintas-device** bergantung `notified_at`; bila panggilan
  `ack_achievements` gagal, badge bisa dinotifikasi ulang (device/jadwal lain) —
  fail-open yang dimaklumi (lebih baik dobel daripada hilang).
