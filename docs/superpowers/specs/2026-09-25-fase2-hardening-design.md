# Fase 2 Hardening — Rate limit, Audit log, Error monitoring, Backup

Tanggal: 2026-09-25 · Versi target: **2.3.7+20** · Status: disetujui user (desain) — menunggu review spek.

Lanjutan roadmap scale (AGENTS.md §3.2b) setelah D1 (analyze CI). Menutup backlog AUDIT.md **A3, A4, D5** + item baru **error monitoring** (sebelumnya tidak tercatat).

## 1. Konteks & keputusan

| Keputusan | Pilihan | Alternatif yang ditolak |
|---|---|---|
| A3 rate limit | **Trigger `before insert` di `transactions`** | RPC insert terkontrol (bypass-able via PostgREST langsung); rate limit platform Supabase (per-plan, bukan per-org, di luar migration kita) |
| A4 audit log | **Trigger SECURITY DEFINER** tulis `audit_logs` | Insert dari client (andal, tapi bisa dilewati attacker yang sudah punya sesi) |
| Error monitoring | **In-house tabel `client_errors`** | Sentry SDK (dependency baru, data finansial keluar ke pihak ketiga, butuh DSN secret); log lokal saja (butuh user lapor manual tiap crash) |
| D5 backup | **Manual multi-CSV via share sheet** | pg_cron + Storage (tambahan extension/bucket/policy, size limit plan gratis) |

Prinsip: semua keputusan menutup jalur yang bisa di-bypass client, tanpa dependency baru, tanpa PII yang bocor ke pihak ketiga.

## 2. A3 — Rate limit auto-insert

**File:** `supabase/migration_11_hardening.sql` (bareng A4, satu migration).

Mekanisme: trigger `before insert` pada `transactions`:

- Hitung transaksi **auto** (`source_package is not null`) milik `NEW.org_id` dengan `created_at > now() - interval '60 seconds'`.
- Bila count ≥ **10** → `raise exception 'RATE_LIMITED'` (rollback insert).
- Batas: **10 auto-insert / 60 detik / org**. Cukup longgar untuk penggunaan normal (termasuk scan ulang shade berisi beberapa notif), menahan flood notif berulang.
- Index pendukung: partial index `transactions (org_id, created_at) where source_package is not null`.
- Insert dari **form transaksi** (`source_package is null`) tidak kena limit — batas ini hanya menahan jalur auto-track.

**Client (`notif_track_service.dart`):** di `_onEvent` dan `forceSave`, `PostgrestException` dengan `message` mengandung `RATE_LIMITED` (code `P0001`) → status **"Dibatasi, terlalu banyak. Coba lagi."** (tanpa em dash — aturan copy AUDIT §5). Duplikat (23505) tetap "Sudah pernah dicatat".

**Catatan sadar:** `forceSave` dari recent tetap kirim `source_package` (badge "Otomatis" harus bertahan), jadi selama flood berlangsung tombol "Simpan manual" juga kena limit — trigger tak bisa membedakan pemicu. Notifikasi tetap ada di `NotifTrack.recent` (RAM), user ulangi setelah cooldown.

## 3. A4 — Audit log server

Masih di `migration_11_hardening.sql`.

```sql
create table audit_logs (
  id            uuid primary key default gen_random_uuid(),
  org_id        uuid not null references organizations(id) on delete cascade,
  actor_user_id uuid,
  event         text not null,
  meta          jsonb not null default '{}'::jsonb,
  created_at    timestamptz not null default now()
);
```

**Event yang dicatat (scope sesuai backlog: insert otomatis & join org):**

| Trigger | Event | meta |
|---|---|---|
| `transactions` AFTER INSERT, `source_package is not null` | `tx_auto_insert` | `tx_id`, `amount`, `type`, `source_package`, `date` |
| `org_members` AFTER INSERT | `org_join` | `role` |

- Kedua fungsi trigger `SECURITY DEFINER` → penulisan tak tergantung RLS client.
- **RLS `audit_logs`:** SELECT saja untuk member org (`exists (select from org_members …)` — subquery ke `org_members` dari tabel lain aman, tidak recursive; larangan hanya untuk policy di `org_members` itu sendiri). **Tidak ada policy INSERT/UPDATE/DELETE** → client menulis = ditolak.
- Index: `(org_id, created_at desc)`.
- **Tanpa UI** sesi ini (YAGNI): baca via Supabase Dashboard dulu; UI permintaan lanjutan.
- Retention/cleanup: belum — tercatat di backlog, idealnya pg_cron di Fase 3.

## 4. Error monitoring (in-house)

**File baru:** `lib/core/saas/error_reporter.dart`.

**Init di `main.dart`** (setelah `SupabaseConfig.init()`):

- `FlutterError.onError` → `ErrorReporter.capture`
- `PlatformDispatcher.instance.onError` → `capture` (return true, jangan rethrow)
- `runZonedGuarded` membungkus `runApp`

**Helper publik:** `ErrorReporter.capture(Object error, StackTrace stack, {String? context})` — juga dipanggil di catch point terpilih (pipeline `_onEvent`, load dompet/transaksi, export) dengan `context` label singkat (`'notif_pipeline'`, `'wallet_load'`, dst).

**Tabel `client_errors`:** (ikut di `migration_11`)

```sql
client_errors(
  id uuid pk default gen_random_uuid(),
  user_id uuid,        -- auth.uid() saat error
  org_id uuid,         -- active org saat itu (nullable)
  message text not null,
  stack text,
  context text,
  app_version text not null,
  created_at timestamptz default now()
)
```

- RLS: user hanya bisa INSERT `user_id = auth.uid()` dan SELECT miliknya sendiri. Tidak ada UPDATE/DELETE client.
- Index `(user_id, created_at desc)`.

**Anti-flood (murni-Dart, testable):**

- Dedupe: signature `context|message` yang sama tidak dikirim ulang dalam 60 menit.
- Maks **20 event/jam** per sesi app; lewat itu drop senyap.
- Insert gagal / offline → drop senyap (monitoring tidak boleh memicu error baru / crash loop).
- Throttle state di memori saja (reset saat app restart — cukup, tanpa persistence).

**Tanpa PII:** hanya `message`, `stack`, `context`, `app_version`, `user_id`, `org_id`. Nominal transaksi, note, isi notifikasi, dan payload insert **tidak pernah** masuk pesan error; `capture` memotong message ke 500 char dan stack ke 4000 char.

**Versi app:** const `AppInfo.version` di file sendiri (`lib/core/app_info.dart`), ikut di-bump bersama pubspec (tanpa dependency `package_info_plus`).

## 5. D5 — Backup manual (multi-CSV)

**File baru:** `lib/core/saas/backup_export.dart` — fungsi murni, testable:

- `walletsCsv(rows)`, `transactionsCsv(rows)`, `budgetsCsv(rows)` → `String` CSV (pola sama dengan `reports_screen`).
- `backupFileNames()` → `['dompet-ssr-space.csv', 'transaksi-ssr-space.csv', 'budget-ssr-space.csv']`.

**Flow:** `other_screen` → tile **"Cadangkan data"** (subtitle: "Ekspor seluruh workspace ke CSV") → ambil semua row org aktif (tanpa limit 100/200 yang dipakai list — pakai limit aman besar, mis. 10.000 per tabel) → tulis file ke `path_provider` temp dir → `Share.shareXFiles([3 file])`.

- Loading state memakai pola `exporting` di `reports_screen`.
- Gagal → SnackBar pesan jelas, state balik normal.
- Tanpa infra server, tanpa dependency baru.

## 6. Test

| File | Menutup |
|---|---|
| `test/error_reporter_test.dart` | dedupe per signature, cap 20/jam, payload tanpa field terlarang, pemotongan message/stack |
| `test/backup_export_test.dart` | header + escaping CSV per tabel, jumlah baris, nama file |

- **Tanpa test otomatis** untuk trigger SQL (rate limit/audit) — infra test RLS belum ada (AUDIT §6); ditutup checklist manual §7 di bawah.
- Test pipeline `_onEvent` dengan mock Supabase tetap backlog B7 — di luar scope sesi ini.

## 7. Checklist verifikasi manual (device + Supabase)

- [ ] Jalankan `migration_11_hardening.sql` di Supabase Dashboard (urutan: setelah migration_10).
- [ ] Auto-track normal (1–2 notif) → "Tersimpan", baris muncul, **`audit_logs` dapat row `tx_auto_insert`**.
- [ ] User join workspace (manual & via invite) → row `org_join` di `audit_logs`.
- [ ] Client biasa: `insert into audit_logs` → ditolak RLS; `select` hanya row org sendiri.
- [ ] Flood ≥11 notif cepat (uji: tombol scan berulang / notif uji) → status **"Dibatasi, terlalu banyak. Coba lagi."** (tanpa em dash — aturan copy AUDIT §5); setelah >60 detik bisa lagi.
- [ ] Baca `client_errors` di Dashboard setelah memicu error uji → row masuk dengan `app_version` benar; tidak ada nominal/note di kolom apa pun.
- [ ] Lainnya → Cadangkan data → share sheet terbuka berisi 3 CSV; buka di Sheets → kolom lengkap, angka benar.
- [ ] CI hijau: analyze → test → APK; download artifact ke `/sdcard/Download/SSR-SPACE/`.

## 8. Dampak file (ringkasan)

**Baru:** `supabase/migration_11_hardening.sql`, `lib/core/saas/error_reporter.dart`, `lib/core/saas/backup_export.dart`, `lib/core/app_info.dart`, `test/error_reporter_test.dart`, `test/backup_export_test.dart`.

**Diubah:** `lib/main.dart` (init handler), `lib/core/saas/notif_track_service.dart` (mapping RATE_LIMITED + capture), `lib/screens/other_screen.dart` (tile backup), `lib/screens/wallets_screen.dart`/`transactions` load catch (capture — opsional sesuai titik yang sudah ada), `pubspec.yaml` (version `2.3.7+20`), `AGENTS.md`, `AUDIT.md`.

**Tidak diubah:** gate `_onEvent` (urutan filter identik), RLS existing, CI workflow.

## 9. Urutan eksekusi

1. `migration_11_hardening.sql` (A3 trigger + A4 audit_logs + client_errors + RLS + index).
2. `error_reporter.dart` + wiring `main.dart` + mapping RATE_LIMITED di notif pipeline.
3. `backup_export.dart` + tile di `other_screen`.
4. Test dua file baru → bump versi.
5. Push → pantau CI hijau → download APK → `/sdcard/Download/SSR-SPACE/`.
6. Update AGENTS.md (status Fase 2) + AUDIT.md (§4 backlog ✅, §5 checklist, §7 changelog) — wajib, jangan diakhiri sebelum doc diupdate.
7. Ingatkan user jalankan `migration_11_hardening.sql` di Supabase.
