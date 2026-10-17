# Fase 4 — Announcements + Roadmap + Update-log Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Menambah Pengumuman (server+fallback aset, badge belum-dibaca, notifikasi lokal), Roadmap produk, dan meng-upgrade layar Catatan Perubahan jadi kartu per-versi — semua gratis, server-authoritative dengan fallback jujur.

**Architecture:** `migration_22` menambah 3 tabel RPC-only (`announcements`, `roadmap_items`, `announcement_reads`) + 3 RPC SECURITY DEFINER. Klien baca server-dulu, fallback aset JSON bawaan; status baca per-user di server + prefs, dedupe notifikasi device-local.

**Tech Stack:** Flutter (stable) + Supabase Postgres (RLS + RPC) + `flutter_local_notifications` + `flutter_test` + suite RLS (`supabase/test/run.sh`).

**Spec:** `docs/superpowers/specs/2026-10-17-ollo-fase4-announcements-roadmap-design.md`

## Global Constraints

- Backend SEMUA via Supabase (RLS + RPC); JANGAN pernah pakai `api.olloweb.app`.
- Adaptasi konsep saja: tanpa merek/aset/teks Ollo; nama tetap SSR SPACE.
- Migration BARU `supabase/migration_22_announcements.sql`, jangan edit history; owner jalankan manual di SQL Editor; kode klien WAJIB fallback bila RPC belum ada (DB lama/offline).
- Tabel baru RPC-only: RLS aktif TANPA policy client (pola `user_achievements`/`user_entitlements`/`heartbeat`). **Jangan** pakai policy public-read (`using (true)`).
- Semua RPC: `security definer set search_path=public`; `revoke all on function ... from public, anon; grant execute ... to authenticated`; guard `NOT_AUTHENTICATED` bila `auth.uid()` null.
- Tanpa dep baru (pakai `flutter_local_notifications` existing); tanpa FCM; tanpa pg_cron.
- `flutter analyze` wajib 0 issue (info `prefer_const_constructors` pun fatal); `dart` lokal SELALU `--enable-asserts`.
- Strings baru wajib ID+EN parity (`test/strings_parity_test.dart`).
- Bump Skema A: `pubspec.yaml` + `lib/utils/app_info.dart` identik + entri `assets/changelog_id.md`. Usulan `2.76.0+255`.
- Branch `feat/announcements-roadmap` dari `feat/gamification-server` (bertumpuk); base versi `2.75.0+254`.
- Jangan commit docs sendirian; jangan push tanpa diminta owner; APK hanya `*-arm64.apk`, unduh dengan pola `-p "<nama-file-versi-baru>"`.
- Basis notif id terpakai: 7002, 71000/72000, 7300, 7400 → pengumuman **7500**.

## Review Focus

- **RPC belum dimigrasi / offline:** klien harus pakai fallback aset bawaan, tidak crash, tidak layar kosong diam.
- **RPC sukses tapi array kosong:** tampilkan empty-state jujur — BUKAN fallback aset basi (jangan menampilkan pengumuman lama palsu).
- **Pengumuman non-aktif:** `published_at` di masa depan atau `expires_at` lampau TIDAK muncul di `list_announcements`.
- **Notifikasi sekali per id per device & tidak menandai dibaca:** notif hanya untuk id baru (∉ `ann_seen_notif_ids`); badge belum-dibaca tetap sampai user membuka (notif ≠ dibaca).
- **Parser toleran:** `changelog_id.md` cacat / payload announcement rusak → entri dilewati, tidak crash.

---

## File Structure

- `supabase/migration_22_announcements.sql` (BARU): 3 tabel + 3 RPC + seed.
- `supabase/test/run.sh` (UBAH): tambah migration_22 ke loop.
- `supabase/test/rls_test.sql` (TAMBAH T36+).
- `lib/services/announcement_parse.dart` (BARU, murni): model + parser + `parseFallbackAnnouncements` + `unreadCount`.
- `lib/services/changelog_parse.dart` (BARU, murni): `ChangelogVersion` + parser + `isInstalledVersion`.
- `test/announcement_parse_test.dart`, `test/changelog_parse_test.dart` (BARU).
- `lib/services/announcement_service.dart` (BARU): fetch/ack/refresh badge.
- `lib/services/announcement_notify.dart` (BARU): channel `ssr_announcement`.
- `assets/announcements_id.json`, `assets/roadmap_id.json` (BARU) + `pubspec.yaml` assets.
- `lib/utils/strings.dart` (UBAH): kunci `an_*`, `rm_*`.
- `lib/screens/lainnya/announcements_screen.dart`, `roadmap_screen.dart` (BARU).
- `lib/screens/lainnya/update_log_screen.dart` (UBAH): parse per-versi.
- `lib/screens/lainnya/other_screen.dart`, `settings_search.dart` (UBAH): wiring.
- `lib/screens/shell/main_shell.dart` (UBAH): hook `AnnouncementNotify.checkAndNotify()` init+resume (auth-gated; `main.dart` jalan pra-login → TIDAK dipakai).
- `pubspec.yaml`, `lib/utils/app_info.dart`, `assets/changelog_id.md`, `AGENTS.md`, `AUDIT.md`, `HANDOFF.md` (UBAH rilis).

---

### Task 1: Backend — `migration_22` + run.sh + seed

**Files:**
- Create: `supabase/migration_22_announcements.sql`
- Modify: `supabase/test/run.sh` (1 baris loop)

**Interfaces:**
- Consumes: pola `supabase/migration_21_gamification.sql` (RPC-only table + security definer + revoke/grant); `auth.uid()`.
- Produces: tabel `announcements(id text pk, title, body, kind, pinned, published_at, expires_at, created_at)`, `roadmap_items(id text pk, title, description, status, sort_order, updated_at, created_at)`, `announcement_reads(user_id uuid, announcement_id text, read_at, pk(user_id,announcement_id))`; RPC `public.list_announcements() -> jsonb`, `public.ack_announcements(text[]) -> void`, `public.list_roadmap() -> jsonb`.

- [ ] **Step 1: Tulis migration (idempotent)**

  Tiga `create table if not exists` (kolom persis seperti Interface di atas; `announcements.kind` & `roadmap_items.status` diberi `check`), tiap tabel `alter table ... enable row level security;` TANPA `create policy`; index `announcements_published_idx (published_at desc)`, `roadmap_items_sort_idx (sort_order)`, `announcement_reads_user_idx (user_id)`.
  - `list_announcements()`: guard `NOT_AUTHENTICATED`; balikan `jsonb` array `{id,title,body,kind,pinned,published_at,read}` difilter aktif (`published_at <= now()` dan (`expires_at is null` atau `expires_at > now()`)), `read` = `exists(select 1 from announcement_reads r where r.user_id=auth.uid() and r.announcement_id=a.id)`, urut `pinned desc, published_at desc`.
  - `ack_announcements(p_ids text[])`: guard `NOT_AUTHENTICATED`; `insert into announcement_reads (user_id, announcement_id) select auth.uid(), unnest(p_ids) on conflict (user_id, announcement_id) do nothing;`.
  - `list_roadmap()`: guard `NOT_AUTHENTICATED`; balikan `jsonb` array `{id,title,description,status,sort_order,updated_at}` urut `sort_order asc, updated_at desc`.
  - `revoke all on function ... from public, anon; grant execute ... to authenticated;` untuk ketiga RPC.
  - **Seed** (semua `on conflict (id) do nothing`): 1 pengumuman `2026-10-17-selamat-datang` (kind `info`, `pinned true`, body singkat memperkenalkan Pengumuman/Roadmap); 5 `roadmap_items` contoh (`rm-*` slug) status campur, `sort_order` 10/20/30/40/50.
  - Header komentar: idempotent; fresh install urutan `schema` → `squashed` → `migration_20` → `migration_21` → `migration_22`; owner jalankan manual.
- [ ] **Step 2: Tambah ke `run.sh` loop**
  Ubah `... ../migration_21_gamification.sql rls_test.sql` → `... ../migration_21_gamification.sql ../migration_22_announcements.sql rls_test.sql`.
- [ ] **Step 3: Verifikasi lokal via Postgres**
  Run: `SSR_RLS_DB_URL=postgresql://<lokal> bash supabase/test/run.sh`
  Expected: `== SUKSES: suite RLS lulus` (baseline + migration_22 apply bersih; T36+ belum ada). Jalankan apply 2-3x untuk membuktikan idempotent.
- [ ] **Step 4: Commit**
  ```bash
  git add supabase/migration_22_announcements.sql supabase/test/run.sh
  git commit -m "feat: migration_22 announcements + roadmap + read state"
  ```

### Task 2: RLS T36+

**Files:**
- Modify: `supabase/test/rls_test.sql` (append T36+)
- Test: `supabase/test/run.sh` (dipakai ulang)

**Interfaces:**
- Consumes: Task 1 (3 tabel + 3 RPC) + fixture existing (`setup.sql` stub `auth.uid()` via GUC `test.user_id`; user `1111…`/`2222…`/`7777…`).
- Produces: assert T36a–T36f hijau.

- [ ] **Step 1: Tulis T36+ (gagal-dulu bila RPC salah)**
  - T36a: dari `anon` → `list_announcements()`/`list_roadmap()` → `permission denied` (revoke).
  - T36b: authenticated → return memuat field kunci; pengumuman `published_at` masa depan & `expires_at` lampau TIDAK muncul (insert fixture id khusus lalu assert absen).
  - T36c: `ack_announcements('{id}')` 2x → `count(*) from announcement_reads where user_id=... and announcement_id=id` = 1; `read=true` untuk id itu; id lain `read=false`.
  - T36d: isolasi — user A ack → `list_announcements()` user B tetap `read=false` untuk id sama.
  - T36e: `set role authenticated` → `select`/`insert` `announcements`/`roadmap_items`/`announcement_reads` ditolak (0 baris / permission denied).
  - T36f: `list_roadmap()` urut `sort_order` (assert monoton naik) & `status` apa adanya.
  - Assert toleran: berhitung delta / id spesifik (seed migration_22 ada).
- [ ] **Step 2: Jalankan suite**
  Run: `SSR_RLS_DB_URL=postgresql://<lokal> bash supabase/test/run.sh`
  Expected: `== SUKSES: suite RLS lulus` (T lama + T36+).
  TDD evidence: tampilkan satu assert yang sempat GAGAL (mis. `read=false` salah) lalu hijau setelah fixture/assert dibetulkan.
- [ ] **Step 3: Commit**
  ```bash
  git add supabase/test/rls_test.sql
  git commit -m "test: RLS T36+ announcements/roadmap/read"
  ```

### Task 3: Pure Dart — parse announcement + changelog

**Files:**
- Create: `lib/services/announcement_parse.dart`, `lib/services/changelog_parse.dart`
- Test: `test/announcement_parse_test.dart`, `test/changelog_parse_test.dart`

**Interfaces:**
- Consumes: — (murni; tanpa Supabase/prefs).
- Produces: `class Announcement { final String id, title, body, kind; final bool pinned, read; final DateTime? publishedAt; }`; `class RoadmapItem { final String id, title, description, status; final int sortOrder; }`; `List<Announcement> parseAnnouncements(Object? raw)`; `List<RoadmapItem> parseRoadmap(Object? raw)`; `List<Announcement> parseFallbackAnnouncements(String json)` (decode aset → `parseAnnouncements`); `int unreadCount(List<Announcement>)`; `class ChangelogVersion { final String version; final List<String> items; }`; `List<ChangelogVersion> parseChangelog(String markdown)`; `bool isInstalledVersion(ChangelogVersion v, String installed)`.
- Catatan: `unreadCount` sengaja murni di file ini (bukan service) agar bisa diuji `dart --enable-asserts` — spec §5 menaruhnya di service, tapi spec §6 menuntutnya teruji; file murni = satu-satunya jalan.

- [ ] **Step 1: Tulis test gagal (announcement)**
  ```dart
  test('parseAnnouncements toleran + unreadCount', () {
    final raw = [
      {'id':'a1','title':'Halo','body':'Isi','kind':'promo','pinned':true,
       'published_at':'2026-10-17T00:00:00Z','read':false},
      {'id':'','title':'kosong'},
      {'id':'a2','kind':'aneh','published_at':'bukan-tanggal'},
      42,
    ];
    final list = parseAnnouncements(raw);
    expect(list.length, 2);
    expect(list[0].kind, 'promo');
    expect(list[0].pinned, isTrue);
    expect(list[1].kind, 'info');
    expect(list[1].publishedAt, isNull);
    expect(unreadCount(list), 2);
    expect(unreadCount(parseAnnouncements([{'id':'b','read':true}])), 0);
    expect(parseAnnouncements(null), isEmpty);
  });

  test('parseRoadmap toleran', () {
    final list = parseRoadmap([
      {'id':'r1','title':'X','status':'done','sort_order':20},
      {'id':'r2','status':'aneh','sort_order':'x'},
    ]);
    expect(list.length, 2);
    expect(list[0].status, 'done');
    expect(list[1].status, 'planned');
    expect(list[1].sortOrder, 0);
  });
  ```
- [ ] **Step 2: Tulis test gagal (changelog)**
  ```dart
  test('parseChangelog blok per-versi + isInstalledVersion', () {
    const md = '''
# Catatan Perubahan SSR SPACE
Versi terpasang: 2.76.0+255.
## Yang baru di 2.76.0+255
- Pengumuman
- Roadmap
## Yang baru di 2.75.0+254
1. Perbaikan notifikasi
''';
    final vs = parseChangelog(md);
    expect(vs.length, 2);
    expect(vs[0].version, '2.76.0+255');
    expect(vs[0].items, ['Pengumuman', 'Roadmap']);
    expect(vs[1].items, ['Perbaikan notifikasi']);
    expect(isInstalledVersion(vs[0], '2.76.0+255'), isTrue);
    expect(isInstalledVersion(vs[1], '2.76.0+255'), isFalse);
    expect(parseChangelog(''), isEmpty);
  });
  ```
- [ ] **Step 3: Verifikasi gagal (lokal)**
  Run: `dart --enable-asserts test/announcement_parse_test.dart` (harness assert sendiri) atau `dart analyze` + eksekusi via scratch harness.
  Expected: simbol belum ada → FAIL. (Harness `flutter_test` dijalankan CI; untuk lokal pakai scratch `dart --enable-asserts` yang meng-`assert` nilai yang sama — WAJIB `--enable-asserts`.)
- [ ] **Step 4: Implement parser**
  `parseAnnouncements`/`parseRoadmap`: terima `List`/`Iterable`; tiap elemen harus `Map`; `id` wajib non-kosong (String) else skip; `kind` ∉ {info,promo,update} → `info`; `status` ∉ {planned,in_progress,done} → `planned`; `sort_order`/`pinned`/`read` non-tipe → default; tanggal ISO rusak → `null`; tak pernah throw. `unreadCount` = jumlah `!read`. `parseChangelog`: baris `## Yang baru di <ver>` jadi blok; item dari `- ` / `1. `; abaikan header/`Versi terpasang`; blok tanpa item tetap dimasukkan; toleran baris aneh.
- [ ] **Step 5: Verifikasi lolos (lokal `dart --enable-asserts`)**
  Expected: semua assert lolos. CI menjalankan `flutter test` untuk kedua file.
- [ ] **Step 6: Commit**
  ```bash
  git add lib/services/announcement_parse.dart lib/services/changelog_parse.dart test/announcement_parse_test.dart test/changelog_parse_test.dart
  git commit -m "feat: parser murni announcements + changelog"
  ```

### Task 4: Service + notifikasi + aset fallback + strings

**Files:**
- Create: `lib/services/announcement_service.dart`, `lib/services/announcement_notify.dart`, `assets/announcements_id.json`, `assets/roadmap_id.json`
- Modify: `lib/utils/strings.dart`, `pubspec.yaml`

**Interfaces:**
- Consumes: Task 1 RPC (`list_announcements`/`ack_announcements`/`list_roadmap`); Task 3 parser/model; pola `lib/services/achievement_notify.dart` (channel + `_idFor` + init-once + fail-silent), `lib/services/game_store.dart` (prefs `jsonEncode`/`jsonDecode` cap), `SupabaseConfig.client.rpc`, `ErrorReporter`.
- Produces: `Future<List<Announcement>> fetchAnnouncements()`; `Future<List<RoadmapItem>> fetchRoadmap()`; `Future<void> ackAnnouncements(List<String> ids)`; `Future<int> refreshUnreadBadge()`; `class AnnouncementNotify { static const channelId='ssr_announcement'; static Future<void> checkAndNotify(); }`.

- [ ] **Step 1: Aset fallback**
  Tulis `assets/announcements_id.json` (array 1–2 entri `{id,title,body,kind,pinned,published_at}`) + `assets/roadmap_id.json` (array 4–5 `{id,title,description,status,sort_order}`), isi ID sama dengan seed Task 1. Tambahkan kedua path ke `assets:` di `pubspec.yaml` (ikut gaya entri existing).
- [ ] **Step 2: `announcement_service.dart`**
  `fetchAnnouncements()`: `SupabaseConfig.client.rpc('list_announcements')` → `parseAnnouncements(res)`; pada Exception → `rootBundle.loadString('assets/announcements_id.json')` → `parseFallbackAnnouncements(json)` **lalu** terapkan `read` dari prefs `ann_read_ids` (map id→`read`). (RPC sukses + array kosong = kembalikan kosong, TIDAK fallback.) `fetchRoadmap()` analog dengan `assets/roadmap_id.json` (tanpa prefs). `ackAnnouncements(ids)`: `rpc('ack_announcements', params:{'p_ids':ids})` + tambah ke prefs `ann_read_ids`; catch → `ErrorReporter.capture`, tak throw. `refreshUnreadBadge()`: `unreadCount(await fetchAnnouncements())` → simpan int prefs `ann_unread_count` → return.
- [ ] **Step 3: `announcement_notify.dart`**
  Channel `ssr_announcement` nama "Pengumuman" (`Importance.high`), init-once (pola `achievement_notify`). `_idFor(id)` = `7500 + (id.hashCode.abs() % 900)`. `checkAndNotify()`: `fetchAnnouncements()` → id aktif yang **belum** ada di prefs `ann_seen_notif_ids` (cap) → `show` per id (judul `an_notif_title`, body `an_notif_body`) → tandai di prefs. **Tidak** memanggil `ackAnnouncements`. Semua di `try/catch` fail-silent (`ErrorReporter.capture`).
- [ ] **Step 4: Strings ID+EN**
  Tambah ke `_t`: `an_title`, `an_new`, `an_empty`, `an_kind_info`, `an_kind_promo`, `an_kind_update`, `an_fallback_note`, `an_notif_title`, `an_notif_body`, `rm_title`, `rm_planned`, `rm_progress`, `rm_done`, `rm_empty`. Tiap kunci dua bahasa; pastikan `test/strings_parity_test.dart` tetap lolos.
- [ ] **Step 5: Verifikasi**
  Run: CI `flutter analyze` (0 issue) + `flutter test test/strings_parity_test.dart`; lokal `dart analyze` file baru.
  Expected: PASS.
- [ ] **Step 6: Commit**
  ```bash
  git add lib/services/announcement_service.dart lib/services/announcement_notify.dart assets/announcements_id.json assets/roadmap_id.json lib/utils/strings.dart pubspec.yaml
  git commit -m "feat: service + notifikasi + aset fallback announcements/roadmap"
  ```

### Task 5: Layar + wiring hub/search + badge + update-log

**Files:**
- Create: `lib/screens/lainnya/announcements_screen.dart`, `lib/screens/lainnya/roadmap_screen.dart`
- Modify: `lib/screens/lainnya/update_log_screen.dart`, `lib/screens/lainnya/other_screen.dart`, `lib/screens/lainnya/settings_search.dart`, `lib/screens/shell/main_shell.dart`

**Interfaces:**
- Consumes: Task 4 service + notify; Task 3 `changelog_parse`; `AppInfo.version`. Pola hub: `other_screen.dart` switch `:319`, `_AboutSection`; `settings_search.dart` `kSettingsSearchEntries`.
- Produces: dua layar, update-log ter-parse, 2 tile + 2 case rute + 2 entri search, hook notif di start.

- [ ] **Step 1: `announcements_screen.dart`**
  Load via `fetchAnnouncements()`; kartu per item (judul, isi, chip `an_kind_*` sadar-tema lewat `Theme.of(context).colorScheme`, tanggal, pinned di atas, chip `an_new` bila `!read`); ketuk kartu → `ackAnnouncements([id])` → update state lokal (tandai read) → `refreshUnreadBadge()`. Caption `an_fallback_note` bila memakai fallback; empty-state `an_empty` berilustrasi. Semua `build()` <50 baris (pecah ke widget privat). `mounted` dijaga setelah await.
- [ ] **Step 2: `roadmap_screen.dart`**
  Load via `fetchRoadmap()`; baris item + badge status (`rm_planned`/`rm_progress`/`rm_done`, warna sadar-tema) urut `sortOrder`; empty-state `rm_empty`. Server-dulu + fallback.
- [ ] **Step 3: `update_log_screen.dart`**
  Ganti render satu `Text` jadi: `parseChangelog(await rootBundle.loadString('assets/changelog_id.md'))` → kartu per versi (judul versi + `ListView`/`Column` poin); kartu yang `isInstalledVersion(v, AppInfo.version)` diberi aksen + label versi terpasang. Tetap judul `ab_changelog`.
- [ ] **Step 4: Wiring hub + search**
  `other_screen.dart` (parent = `_OtherScreenState`, punya `initState` `:84`): tambah field `int _annUnread = 0;`, muat di `initState` + resume lewat `refreshUnreadBadge()` fail-silent (`setState` bila `mounted`); `_AboutSection` (`:611` dipanggil, kelas `:1233`) — tambah param `final int unreadCount; final VoidCallback onAnnouncements, onRoadmap;` + dua `NavTile` (Pengumuman: subtitle/`badge` angka bila `>0`, `tr('an_title')`; Roadmap: `tr('rm_title')`) di daftar, ikut gaya `Divider(height:1)` existing. Wire `onAnnouncements: () => _open('announcements')`, `onRoadmap: () => _open('roadmap')`, `unreadCount: _annUnread`. Tambah `case 'announcements':` → `_push(const AnnouncementsScreen())` + `case 'roadmap':` → `_push(const RoadmapScreen())` di switch `:319`. `settings_search.dart`: tambah 2 `SettingsSearchEntry` (`an_title`/`rm_title`, `sectionKey: 'pf_about'`, `route: 'announcements'`/`'roadmap'`).
- [ ] **Step 5: Hook notifikasi init+resume**
  `lib/screens/shell/main_shell.dart`: tambah `Future<void> _checkAnnouncements()` (pola `_checkBudgetAlerts` `:112`; `try/catch` fail-silent: `await AnnouncementNotify.checkAndNotify(); await refreshUnreadBadge();`). Panggil di `didChangeAppLifecycleState` cabang `resumed` (`:132`, sebaris `unawaited(_checkAnnouncements())`) **dan** sekali saat init shell (dekat pemanggilan `_checkBudgetAlerts`/`_ensureRealtime` pertama). **Jangan** taruh di `main.dart` (pra-login, `list_announcements` butuh `auth.uid`).
- [ ] **Step 6: Verifikasi**
  Run: CI `flutter analyze` (0 issue; waspada `use_build_context_synchronously` → guard `mounted`) + `flutter test` (regresi suite lama hijau).
  Expected: PASS.
- [ ] **Step 7: Commit**
  ```bash
  git add lib/screens/lainnya/announcements_screen.dart lib/screens/lainnya/roadmap_screen.dart lib/screens/lainnya/update_log_screen.dart lib/screens/lainnya/other_screen.dart lib/screens/lainnya/settings_search.dart lib/screens/shell/main_shell.dart
  git commit -m "feat: layar announcements/roadmap + update-log per-versi + wiring hub"
  ```

### Task 6: Rilis (bump + changelog + CI + APK + docs)

**Files:**
- Modify: `pubspec.yaml`, `lib/utils/app_info.dart`, `assets/changelog_id.md`, `AGENTS.md`, `AUDIT.md`, `HANDOFF.md`

**Interfaces:**
- Consumes: Task 1-5 hijau.

- [ ] **Step 1: Bump + changelog**
  `version: 2.76.0+255` + `AppInfo.version = '2.76.0+255'` identik + seksi `## Yang baru di 2.76.0+255` di `assets/changelog_id.md` (Pengumuman + Roadmap + Catatan Perubahan per-versi) + baris "Versi terpasang" → `2.76.0+255`.
- [ ] **Step 2: Docs lokal**
  Catat status Fase 4 di `AGENTS.md`, `AUDIT.md` §7, `HANDOFF.md` (commit bersama bump — jangan docs sendirian).
- [ ] **Step 3: Commit rilis (satu commit)**
  ```bash
  git add pubspec.yaml lib/utils/app_info.dart assets/changelog_id.md AGENTS.md AUDIT.md HANDOFF.md docs/superpowers/specs/2026-10-17-ollo-fase4-announcements-roadmap-design.md docs/superpowers/plans/2026-10-17-ollo-fase4-announcements-roadmap.md
  git commit -m "chore: bump 2.76.0+255 announcements/roadmap"
  ```
- [ ] **Step 4: CI hijau penuh**
  Run: `git push origin feat/announcements-roadmap` → `gh run watch $(gh run list --branch feat/announcements-roadmap --limit 1 --json databaseId --jq '.[0].databaseId') --exit-status`
  Expected: `rls-test` + `apk` hijau (analyze 0 issue + test + build arm64). Bila merah → perbaiki akar, push ulang.
- [ ] **Step 5: APK + instruksi migration**
  Run: `gh release download ci-apk -p "SSR-SPACE-2.76.0-255-arm64.apk" -D /sdcard/Download/SSR-SPACE/ --clobber` → verifikasi ukuran byte utuh.
  Instruksi owner: jalankan `supabase/migration_22_announcements.sql` sekali di Dashboard → SQL Editor (idempotent).
