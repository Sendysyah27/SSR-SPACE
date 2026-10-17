# Spec Fase 4 — Announcements + Roadmap + Update-log (adaptasi konsep Ollo)

> Tanggal: 2026-10-17 · Status: **APPROVED owner (desain Q&A)** → lanjut writing-plans.
> Repo: `~/SSRSPACE`. Fase 3 (gamifikasi server) selesai di branch
> `feat/gamification-server` (HEAD `ec1b544`, v2.75.0+254) tapi **belum di-merge**;
> main = `1eb2cab` (v2.74.0+252). Owner memutuskan Fase 4 **bertumpuk di atas Fase 3**:
> branch baru dari `feat/gamification-server`, jadi versi lanjut `2.76.0+255`.
> Sesi ini HANYA fase 4 dari kickoff `docs/prompts/2026-10-16-ollo-adapt-kickoff.md`.
> Fase 5 (i18n + multi-currency) non-scope.
> Aturan mengikat: backend SEMUA via Supabase (RLS+RPC); jangan pernah pakai
> `api.olloweb.app`; adaptasi konsep saja (tanpa merek/aset/teks Ollo).

## 1. Tujuan & kriteria sukses

Menambah tiga permukaan informasi produk dengan paritas konsep Ollo (announcement
remote, roadmap produk, changelog), semuanya **gratis** dan **server-authoritative
dengan fallback bawaan jujur**:

- **Pengumuman** — daftar pengumuman aktif (info/promo/update) yang bisa ditulis owner
  tanpa rilis APK; badge belum-dibaca + notifikasi lokal saat ada yang baru.
- **Roadmap** — daftar rencana produk berstatus (Direncanakan / Sedang dikerjakan /
  Selesai) yang bisa diperbarui owner tanpa rilis APK.
- **Update-log** — layar Catatan Perubahan existing (`update_log_screen.dart`)
  ditingkatkan dari satu blok teks jadi kartu per-versi, menandai versi terpasang.
- Sukses = CI hijau (`apk.yml` + `rls-test.yml`), suite RLS T36+ lulus, unit murni
  lulus lokal (`dart --enable-asserts`), APK `SSR-SPACE-2.76.0-255-arm64.apk`
  terunduh, dan owner menjalankan `migration_22` manual.

## 2. Batasan (constraints)

- Dilarang koding sebelum spec+plan. Desain di-approve owner via Q&A 2026-10-17
  (sumber server+fallback, baca per-user server, roadmap server setelah login,
  update-log parse ID-only, semua gratis, badge+notif lokal). Eksekusi setelah plan
  dari skill writing-plans.
- Migration: file BARU `supabase/migration_22_announcements.sql`, jangan edit history.
  Fresh install = `schema.sql` + `migration_squashed.sql` + `migration_20_entitlement.sql`
  + `migration_21_gamification.sql` + `migration_22_announcements.sql`. DB produksi =
  owner jalankan `migration_22` manual di SQL Editor (idempotent). Kode klien yang
  butuh RPC baru WAJIB fallback (lulus CI, dimaklumi sampai owner migrasi).
- Branch baru `feat/announcements-roadmap` dari `feat/gamification-server`
  (bertumpuk; §Status di atas).
- Jangan commit docs sendirian; jangan push tanpa diminta owner.
- Bump versi Skema A: `pubspec.yaml` + `lib/utils/app_info.dart` identik + entri
  `assets/changelog_id.md`. Usulan: `2.76.0+255`.
- Deliverable → `/sdcard/Download/SSR-SPACE/`, hanya `*-arm64.apk`, unduh berpola
  `-p "<nama-file-versi-baru>"`.
- Flutter tidak ada di Termux → verifikasi via CI. Logika murni TDD via
  `dart --enable-asserts` (wajib flag; tanpa itu PASS palsu).
- i18n parity: setiap kunci strings baru wajib ID+EN (`test/strings_parity_test.dart`).
- RLS: tabel baru **RPC-only** (RLS aktif TANPA policy client) pola
  `user_achievements`/`user_entitlements`/`heartbeat`. **Tidak** memakai pola
  public-read (`using (true)`) — repo belum punya, dan tidak diperlukan karena
  baca lewat RPC. RPC `SECURITY DEFINER` + `set search_path=public`;
  `revoke all from public, anon; grant execute to authenticated`.
- Tanpa dep baru (pakai `flutter_local_notifications` yang sudah ada) dan tanpa FCM.

## 3. Konteks existing (extend, jangan duplikasi)

- `lib/screens/lainnya/update_log_screen.dart` — `UpdateLogScreen` sekarang memuat
  `rootBundle.loadString('assets/changelog_id.md')` (`:23`) dan merender satu `Text`
  panjang (`:78-89`). **Ini satu-satunya titik existing** yang ditingkatkan (parse
  per-versi). Dibuka dari hub (§`other_screen`) + search (`settings_search`).
- `assets/changelog_id.md` — format: `# Catatan Perubahan SSR SPACE`, baris
  `Versi terpasang: X.Y.Z+build.`, lalu blok `## Yang baru di <version>` + list
  bernomor. Tetap ID-only (tidak ada `changelog_en.md`; keputusan owner).
- `lib/screens/lainnya/other_screen.dart` — dispatcher rute `switch (key)` (`:319-358`),
  `_push` (`:149`), `_openSearch` (`:293-318`), section Tentang `_AboutSection`
  (`:1231-1316`, sudah punya callback `onChangelog`/`onHelp`). Titik tambah tile +
  case rute.
- `lib/screens/lainnya/settings_search.dart` — `SettingsSearchEntry{titleKey,en,sectionKey,route,focus?}`
  (`:8-22`) + `kSettingsSearchEntries` (`:25-368`, entri changelog `:277-282`).
- `lib/services/game_store.dart` — pola prefs "seen": `loadSeenBadges()`/`saveSeenBadges(Set)`
  via `jsonDecode`/`jsonEncode` + fail-safe `{}`. Ditiru untuk status baca & dedupe notif.
- `lib/services/achievement_notify.dart` — pola channel notif: `ssr_achievement`,
  `_idFor(id)` stabil via indeks, init-once, fail-silent (`ErrorReporter.capture`).
  **Basis id terpakai:** 7002 (reminder), 71000/72000 (due), 7300 (save30), 7400
  (achievement) → **7500 bebas** untuk pengumuman.
- `lib/main.dart:79-114` — hook registrasi/reschedule notif fail-silent
  (`DueNotify.reschedule()`, `Save30Notify.reschedule()`); pola hook untuk cek
  pengumuman baru saat start/resume.
- `lib/services/plan_limits.dart` + `requirePro` — **tidak disentuh** (semua gratis).
- `lib/utils/strings.dart:5` `_t` map + `:2598` `tr()` + `:2601` `stringTable`;
  `lib/services/app_settings.dart:35` `localeCode` (default `id`). Bilingual penuh.
- Server existing `supabase/migration_20_entitlement.sql` + `migration_21_gamification.sql`
  — pola RPC-only table / security-definer / revoke-grant / guard `NOT_AUTHENTICATED`
  yang WAJIB ditiru.
- RLS harness `supabase/test/run.sh:19` loop; suite terakhir = **T35g**
  (`supabase/test/rls_test.sql`) → lanjut **T36+**.
- `docs/reference/ollo-screenshots/` — 12 screenshot Ollo (referensi pola flow/hierarki
  saja, bukan visual/merek). `LAPORAN-ollo.md`/`fitur.json`: Ollo announcements =
  remote + fallback gist; roadmap = layar statis; update-log = changelog bundled.

## 4. Desain backend — `supabase/migration_22_announcements.sql` (idempotent)

Semua tabel RLS aktif TANPA policy client; semua RPC `SECURITY DEFINER` +
`set search_path=public`, guard `NOT_AUTHENTICATED` bila `auth.uid()` null,
`revoke all … from public, anon; grant execute … to authenticated`.

1. Tabel **`announcements`**:
   - `id text primary key` (slug buatan owner, mis. `2026-10-17-selamat-datang`;
     bikin id notifikasi stabil & enak ditulis di SQL Editor)
   - `title text not null`
   - `body text not null`
   - `kind text not null default 'info'` (dipakai UI: `info|promo|update`)
   - `pinned boolean not null default false`
   - `published_at timestamptz not null default now()`
   - `expires_at timestamptz` (nullable = tanpa kedaluwarsa)
   - `created_at timestamptz not null default now()`
   - index `announcements_published_idx (published_at desc)`
2. Tabel **`roadmap_items`**:
   - `id text primary key` (slug), `title text not null`, `description text`
   - `status text not null default 'planned'` (UI: `planned|in_progress|done`)
   - `sort_order int not null default 0`
   - `updated_at timestamptz not null default now()`, `created_at timestamptz not null default now()`
   - index `roadmap_items_sort_idx (sort_order)`
3. Tabel **`announcement_reads`**:
   - `user_id uuid not null references auth.users(id) on delete cascade`
   - `announcement_id text not null references announcements(id) on delete cascade`
   - `read_at timestamptz not null default now()`
   - `primary key (user_id, announcement_id)`, index `(user_id)`
4. RPC `list_announcements() returns jsonb`:
   - Ambil pengumuman **aktif**: `published_at <= now()` dan
     (`expires_at is null` atau `expires_at > now()`).
   - `read` = ada baris `announcement_reads` untuk `(auth.uid(), id)`.
   - Urut `pinned desc, published_at desc`.
   - Return array `{id,title,body,kind,pinned,published_at,read}`.
5. RPC `ack_announcements(p_ids text[]) returns void`:
   - `insert into announcement_reads (user_id, announcement_id)
      select auth.uid(), unnest(p_ids) on conflict (user_id, announcement_id) do nothing;`
   - Menandai **dibaca** (bukan "sudah dinotifikasi" — dedupe notif device-local, §5).
6. RPC `list_roadmap() returns jsonb`:
   - Return array `{id,title,description,status,sort_order,updated_at}`
     urut `sort_order asc, updated_at desc`.
7. **Seed idempotent** (`on conflict (id) do nothing`):
   - 1 pengumuman `2026-10-17-selamat-datang` (info, pinned) memperkenalkan fitur.
   - 4–5 `roadmap_items` contoh (campur `planned/in_progress/done`, `sort_order` rapi).
   - Seed = isi awal; owner bebas edit/hapus lewat SQL Editor.
8. Tidak ada trigger/kolom baru di tabel existing; tidak ada pg_cron (retensi
   pengumuman diabaikan — volume sangat kecil; owner hapus manual bila perlu).

## 5. Desain klien

- `lib/services/announcement_service.dart` (baru):
  - Model `class Announcement { final String id, title, body, kind;
    final bool pinned, read; final DateTime? publishedAt; }`
  - Model `class RoadmapItem { final String id, title, description, status;
    final int sortOrder; }`
  - `Future<List<Announcement>> fetchAnnouncements()` — RPC `list_announcements`.
    **Gagal RPC** (fungsi belum ada / offline) → fallback aset bawaan
    (`assets/announcements_id.json`) dengan status baca dari prefs. **RPC sukses tapi
    array kosong = benar-benar kosong** (empty-state), bukan fallback.
  - `Future<List<RoadmapItem>> fetchRoadmap()` — RPC `list_roadmap`, fallback aset
    `assets/roadmap_id.json` saat RPC gagal.
  - `Future<void> ackAnnouncements(List<String> ids)` — RPC `ack_announcements`
    **dan** tulis prefs `ann_read_ids` (konsisten saat offline/fallback); gagal →
    `ErrorReporter.capture`, tak pernah throw.
  - `int unreadCount(List<Announcement>)` (murni).
  - `Future<int> refreshUnreadBadge()` — fetch + hitung + simpan `ann_unread_count`
    (dipakai hub agar badge tak perlu network saat render).
- `lib/services/announcement_parse.dart` (murni, baru):
  - `List<Announcement> parseAnnouncements(Object? raw)` — defensif: `kind` tak dikenal
    → `info`, tanggal rusak → null, entri cacat/slug kosong dilewati, tak pernah crash.
  - `List<RoadmapItem> parseRoadmap(Object? raw)` — sama; `status` tak dikenal →
    `planned`, `sort_order` non-int → 0.
  - `List<Announcement> parseFallbackAnnouncements(String json)` (aset) + merge `read`
    dari prefs.
- `lib/services/changelog_parse.dart` (murni, baru):
  - `class ChangelogVersion { final String version; final List<String> items; }`
  - `List<ChangelogVersion> parseChangelog(String markdown)` — parse `## Yang baru di
    <version>` + list `-`/`1.`; abaikan header/`Versi terpasang`.
  - `bool isInstalledVersion(ChangelogVersion, String installed)`.
- `lib/services/announcement_notify.dart` (baru): channel `ssr_announcement` nama
  "Pengumuman" (`Importance.high`), basis id `7500`, `_idFor(id)` stabil =
  `7500 + (id.hashCode.abs() % 900)` (deterministik per slug, pola `due_notify`),
  init-once, fail-silent.
  `Future<void> checkAndNotify()` — ambil pengumuman aktif, tampilkan notif HANYA id
  yang belum ada di prefs `ann_seen_notif_ids` (cap, pola `game_store`), lalu tandai.
  **Tidak** memanggil `ackAnnouncements` (badge tetap sampai user membuka).
- Prefs (fail-safe + cap): `ann_read_ids` (status baca fallback), `ann_seen_notif_ids`
  (dedupe notif), `ann_unread_count` (badge hub, int).
- Layar baru:
  - `lib/screens/lainnya/announcements_screen.dart` — kartu per pengumuman (judul,
    isi, chip jenis sadar-tema, tanggal, pinned di atas, tanda `an_new` bila `!read`);
    ketuk → `ackAnnouncements([id])` + tandai baca lokal lalu refresh; caption jujur
    bila memakai fallback/offline; empty-state berilustrasi (pola layar existing);
    skema warna dari `Theme.of(context).colorScheme` (tanpa hex hardcode).
  - `lib/screens/lainnya/roadmap_screen.dart` — daftar item + badge status
    (`rm_planned`/`rm_progress`/`rm_done`) urut `sort_order`; server-dulu + fallback;
    empty-state.
- `update_log_screen.dart` (ditingkatkan) — pakai `parseChangelog`, render kartu
  per-versi (judul versi + daftar poin) + tanda "Versi terpasang" dari `AppInfo.version`
  (kartu versi terpasang diberi aksen). Ganti blok teks panjang.
- Wiring `other_screen.dart`: seksi Tentang → NavTile **Pengumuman** (badge jumlah
  belum-dibaca dari prefs `ann_unread_count`, di-`refreshUnreadBadge()` saat hub load)
  + **Roadmap**; tambah `case 'announcements'` / `case 'roadmap'` di switch rute.
  `settings_search.dart` += 2 entri (`announcements`, `roadmap`) → bisa dicari.
- Strings baru (ID+EN parity): `an_*` (judul layar, chip `an_kind_info/promo/update`,
  `an_new`, `an_empty`, caption fallback, notif `an_notif_title`), `rm_*`
  (`rm_title`, `rm_planned/progress/done`, `rm_empty`), `ul_*` bila perlu
  (update-log pakai `ab_changelog` existing + label versi terpasang).
- Rilis: bump `2.76.0+255` + entri `assets/changelog_id.md`.

### Data flow notifikasi & badge

```
app start/resume (main.dart / MainShell resume)
  → AnnouncementNotify.checkAndNotify()
      → fetchAnnouncements()
      → id baru (∉ ann_seen_notif_ids) → notif lokal per id → simpan ann_seen_notif_ids
      → refreshUnreadBadge() → simpan ann_unread_count
hub load
  → baca ann_unread_count (prefs) → badge NavTile (tanpa network)
layar Pengumuman dibuka → fetch → render; ketuk kartu → ackAnnouncements([id])
  → ann_read_ids bertambah → unread berkurang → refreshUnreadBadge()
```

## 6. Testing

- Unit murni (lokal `dart --enable-asserts`):
  - `test/announcement_parse_test.dart` — parse server jsonb (kind tak dikenal→info,
    tanggal rusak→null, entri cacat dilewati), parse aset fallback, `unreadCount`.
  - `test/changelog_parse_test.dart` — parse `changelog_id.md` nyata (blok per-versi,
    list bullet/nomor), `isInstalledVersion` benar untuk versi terpasang vs bukan.
- `supabase/test/rls_test.sql` += **T36+**:
  - T36a: `anon` → `list_announcements()`/`list_roadmap()` `permission denied` (revoke).
  - T36b: authenticated → bentuk return benar (field kunci ada; filter aktif:
    `published_at` masa depan / `expires_at` lampau TIDAK muncul).
  - T36c: `ack_announcements` idempoten (panggil 2x → 1 baris `announcement_reads`);
    `read=true` untuk id yang di-ack, `false` untuk yang tidak.
  - T36d: isolasi antar-user — ack user A tak membuat `read=true` di `list_announcements`
    user B (`announcement_reads` per `auth.uid()`).
  - T36e: client TAK bisa `select`/`insert` `announcements`/`roadmap_items`/
    `announcement_reads` langsung (permission denied / 0 baris).
  - T36f: `list_roadmap()` urut `sort_order`; `status` apa adanya.
  - Fixture: seed dari migration_22 bisa memengaruhi assert → hitung delta/target id
    spesifik, jangan asumsi tabel kosong.
- `supabase/test/run.sh`: tambah `../migration_22_announcements.sql` ke loop baseline
  (setelah migration_21).
- CI: `rls-test.yml` + `apk.yml` (analyze 0 issue — info `prefer_const_constructors`
  pun fatal; `flutter test`; build arm64).
- Verifikasi device (owner): buka hub → badge pengumuman; buka Pengumuman → kartu
  tampil + tanda Baru; buka satu → badge berkurang; notifikasi "Pengumuman" muncul saat
  ada yang baru (sekali, tak mengulang); Roadmap tampil berstatus; update-log jadi
  kartu per-versi dengan "Versi terpasang"; mode pesawat → fallback aset tanpa crash.

## 7. Non-goals (fase lain / jangan campur)

- i18n multi-bahasa + multi-currency/exchange-rate (fase 5).
- Push server (FCM) — notifikasi tetap lokal.
- Gating berbayar untuk ketiga fitur (semua gratis, paritas Ollo).
- Editor pengumuman in-app (owner menulis via Supabase SQL Editor) — non-goal.
- `changelog_en.md` (update-log tetap ID-only).
- Fase 1/2/3 (entitlement, widget, gamifikasi) — tak disentuh selain base branch.

## 8. Risiko & catatan jujur

- **Status baca butuh login:** `list_announcements` butuh `auth.uid()` →
  `announcement_reads` tak bermakna pra-login. Layar hanya dibuka setelah login (hub
  Tentang), jadi konsisten; kalau nanti ditampilkan pra-login → status baca jadi
  device-local (follow-up).
- **Dedupe notif device-local:** `ann_seen_notif_ids` per device. Pasang di HP-2 →
  notif bisa muncul sekali lagi di device itu (server `ack` tak dipakai untuk notif).
  Diterima: notif ≠ dibaca; badge lintas-device tetap benar karena `read` server-side.
- **Fallback aset bisa basi:** bila RPC belum dijalankan (DB belum migrasi) atau
  offline, klien menampilkan aset bawaan (isi saat rilis), bukan pengumuman terbaru.
  Caption jujur di UI; hilang setelah owner menjalankan `migration_22` dan online.
- **`expires_at` zona waktu:** perbandingan dilakukan server (`now()` server) — tak
  ada drift klien.
- **`id text` slug owner-authored:** salah tulis slug = baris ganda/aneh; seed &
  dokumentasi memberi contoh jelas. Notif id stabil dari hash slug.
- **Update-log parse `changelog_id.md`:** format file ditulis tangan; parser dibuat
  toleran (blok tak lengkap dilewati) + unit test memakai berkas nyata. Bila format
  berubah drastis, kartu bisa kosong — diuji di CI.
