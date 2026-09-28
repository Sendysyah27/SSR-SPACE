# Spec: We Space — ruang bersama (mode Bebas/Bendahara, aktivitas, badge pencatat)

Tanggal: 2026-09-28 · Versi dasar: 2.5.0+47 · Target rilis: 2.6.0+48
Status: DISETUJUI user 2026-09-28, dieksekusi via `docs/superpowers/plans/2026-09-28-we-space.md`.

Keputusan user yang mengunci (sesi brainstorm 2026-09-28):
1. Use case = keduanya: mode Bebas (semua anggota catat) dan mode Bendahara (hanya owner/admin catat, member lihat).
2. Notifikasi antar-anggota = in-app saja (tanpa FCM/dep/server baru).
3. Mode diatur per workspace. Pendekatan B (Sedang): RLS tulis + layar Aktivitas Space + badge pencatat + kuota tegak.

Aturan repo yang berlaku: migration baru `migration_15_we_space.sql` (user jalankan manual di Dashboard → SQL Editor setelah migration_14); tanpa dep baru; anti-recursion org_members (cek peran hanya via helper SECURITY DEFINER); bump version Skema A + entri `changelog_id.md`; 1 commit + CI hijau + APK arm64 ke `/sdcard/Download/SSR-SPACE/`; catat lokal AGENTS.md + AUDIT.md §7.

Non-tujuan (sengaja di luar scope): push FCM antar-HP, alur persetujuan (member ajukan → admin setujui), presence/typing, tampilkan nama/email anggota (privasi: ID pendek + "Kamu" saja, ikut pola `list_org_members` migration_14).

---

## S1. Data & RLS (`supabase/migration_15_we_space.sql`, idempoten)

1. Kolom baru: `organizations.space_mode text NOT NULL DEFAULT 'bebas'` dengan check `in ('bebas','bendahara')`. Default bebas = perilaku lama bila client basi.
2. Helper SECURITY DEFINER `can_write_space(p_org_id uuid) returns boolean`: return true bila pemanggil member dan (mode bebas ATAU role pemanggil in owner/admin). Satu-satunya pembaca `org_members` di jalur tulis — policy RLS tidak subquery `org_members` langsung.
3. Pecah policy tulis (SELECT tetap semua member):
   - Drop `member wallets` / `member tx` (FOR ALL), ganti: SELECT policy member-read (isi sama seperti USING lama) + INSERT/UPDATE/DELETE policy `WITH CHECK`/USING `can_write_space(org_id)`.
   - SELECT `organizations` (`member read org`) tidak berubah. Tidak ada policy UPDATE langsung ke `organizations` — mode hanya via RPC di bawah.
4. RPC `set_space_mode(p_org_id uuid, p_mode text) returns void` (SECURITY DEFINER): tolak bila pemanggil bukan owner/admin (`NOT_ADMIN`); tolak mode selain dua nilai (`BAD_MODE`); update kolom + insert `audit_logs` event `space_mode_change` (meta: mode baru + actor). Revoke public/anon, grant authenticated (pola migration_10/14).
5. Audit via trigger + RPC (semua SECURITY DEFINER, client tetap tanpa tulis ke `audit_logs`):
   - Trigger `log_manual_tx_insert` after insert on transactions when `source_package IS NULL` → event `tx_manual_insert` (meta: tx_id, amount, type, category; actor = `auth.uid()`).
   - `tx_auto_insert` + `org_join` lama tidak berubah.
   - `kick_member` (migration_14) ditambah insert `member_kick` (meta: target + actor) di dalam function; `delete_workspace` ditambah `workspace_delete`.
6. RLS test (`supabase/test/rls_test.sql`, suite lokal + CI): T16 bebas-member insert tx OK; T17 bendahara-member insert tx DITOLAK; T18 bendahara-admin insert OK; T19 select member tetap OK di kedua mode; T20 `set_space_mode` oleh member DITOLAK + oleh admin OK. `migration_15` ikut harness (tanpa pg_cron, jadi tidak dilewati seperti 13).

File: `supabase/migration_15_we_space.sql`, `supabase/test/rls_test.sql` (tambah T16–T20).
Uji: suite RLS lokal hijau via `bash supabase/test/run.sh` + CI `rls-test.yml` hijau.

## S2. Client & UI

1. `lib/services/space_service.dart` baru: `getMode(orgId)` (baca `organizations.space_mode`, fail-open `bebas` bila query gagal), `setMode(orgId, mode)` (RPC + map error `NOT_ADMIN`/`BAD_MODE` ke string lokal), `activity(orgId, limit)` (baca `audit_logs` order created desc, limit 100), `seenKey(orgId)` = `space_seen_<orgId>`, `unseenCount(logs, seenIso)` murni, `markSeen(orgId)` tulis prefs ISO now.
2. Detail workspace (`workspace_detail_screen` + `workspace_service`): seksi Mode Space — SegmentedButton Bebas/Bendahara + deskripsi 1 baris; hanya owner/admin bisa ubah (member lihat read-only + hint kuota Gratis 3 anggota); ganti mode wajib PIN (`verifyPin`) lalu RPC; gagal tulis → snackbar jujur + mode tampilan tidak berubah.
3. Layar baru Aktivitas Space (`lib/screens/workspace/space_activity_screen.dart`): dibuka dari hub Profil → Workspace → Aktivitas; list audit (ikon per event, baris "siapa–apa–kapan": actor "Kamu" bila `actor_user_id == me` else "Anggota •xxxx" 4 char, nominal via `amt()` sehingga ikut privacy-mask, waktu via `txWhenLabel`-pola); empty state jujur; buka layar → `markSeen`. Badge "baru" di pintu hub = `unseenCount` (tanpa angka bila 0).
4. `TxRow` (`lib/widgets/tx_row.dart`): badge pencatat kecil di bawah chips bila `created_by` ada: "Kamu" (me) / "Anggota •xxxx". Tanpa `created_by` → tanpa badge (riwayat lama). Tidak tampilkan nama/email (batas privasi sadar).
5. `transaction_service` + `wallet_service`: insert tetap isi `created_by` (tx sudah ada — pertahankan; wallet tanpa kolom, andalkan audit actor). Tangkap `PostgrestException 42501` saat mode bendahara + pemanggil member → lempar pesan `sp_only_treasurer` ("Hanya bendahara yang bisa catat di Space ini"); konteks lain tetap pesan lama. Auto-track (`notif_track_service`) di Space bendahara milik member: tulis ditolak RLS → status recent jujur "mode bendahara" (bukan "coba lagi"), tanpa retry.
6. Invite: peran `member`/`admin` tetap; di mode bendahara, UI invite menampilkan hint "anggota baru hanya bisa lihat". Kuota `canInvite` (3 anggota Gratis) sudah tegak — pertahankan, tambah test bila belum.
7. Strings baru ID+EN (`lib/utils/strings.dart`): `sp_mode`, `sp_mode_desc`, `sp_bebas`, `sp_bendahara`, `sp_bendahara_hint`, `sp_activity`, `sp_new`, `sp_only_treasurer`, `sp_by_you`, `sp_by_member`, `sp_mode_need_pin`. Semua copy Indonesia baku, tanpa klaim push.

File: `space_service.dart` + test `test/space_test.dart` (parse mode fail-open, label pencatat, unseenCount 5 case — lokal `dart --enable-asserts` sebelum push); sentuh: `workspace_detail`, `workspace_service`, `space_activity_screen` (baru), `other_screen` (pintu + badge), `settings_search` (route aktivitas), `tx_row`, `transaction_service`, `wallet_service`, `notif_track_service` (status), `strings.dart`.
Uji: `flutter analyze` 0 issue, test hijau, cek manual: member bendahara tekan Simpan → ditolak jujur; admin tetap bisa; badge Aktivitas hilang setelah dibuka.

## S3. Rilis & batas

Tanpa dep/migration selain migration_15; tanpa FCM. Fail-open baca (mode gagal dimuat = bebas, agar data tetap terlihat); fail-closed tulis (ditolak RLS = snackbar, bukan retry diam). Privasi: tanpa nama/email anggota di manapun. Rollback: migration idempoten; bila migration_15 belum dijalankan user, client tetap jalan (mode baca gagal → bebas; tulis tetap aturan lama).
Rilis: bump `2.6.0+48` (pubspec + AppInfo identik) + entri changelog "Yang baru di 2.6.0" + "Versi terpasang"; 1 commit `feat:` + push + `gh run watch` hijau; unduh APK arm64 → `/sdcard/Download/SSR-SPACE/`; catat AGENTS.md + AUDIT.md §7 lokal (gabung commit ini, bukan docs sendirian).

---

## Self-review spec (2026-09-28)

1. Placeholder: tidak ada TBD/TODO — semua nilai konkret (nama file, kunci prefs, nama RPC/event, nomor test).
2. Konsistensi: S1 (RPC-only mode) ↔ S2 (tanpa update langsung organizations) cocok; badge pakai `created_by` yang memang sudah diisi `transaction_service:189`; audit tulis tetap server-side (konsisten A4 migration_11); anti-recursion dijaga via helper (aturan AGENTS.md §3.4).
3. Scope: satu plan implementasi (1 migration + ~10 file client + 2 test). FCM/persetujuan/presence eksplisit non-tujuan.
4. Ambiguitas: "Anggota •xxxx" didefinisikan (4 char awal user_id); `unseenCount` murni (bandingkan ISO string, tak perlu jam device); `setMode` PIN-gate di client + `NOT_ADMIN` di server (dua lapis).
