# Fase 2 Hardening (A3+A4+Monitoring+Backup) Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Menutup backlog Fase 2 AUDIT.md — rate limit auto-insert (A3), audit log server (A4), error monitoring in-house, dan backup manual multi-CSV (D5) — dalam satu rilis `2.3.7+20`.

**Architecture:** Satu migration SQL (`migration_11`) berisi trigger rate-limit + trigger audit + tabel `client_errors`. Client: `ErrorReporter` (global handler + throttle Dart tanpa PII), mapping error `RATE_LIMITED` di pipeline auto-track, dan tile "Cadangkan data" yang me-render 3 CSV lalu dibagikan via share sheet. Tanpa dependency baru.

**Tech Stack:** Flutter stable (CI-only build), Supabase Postgres (trigger SECURITY DEFINER + RLS), `csv` + `share_plus` + `path_provider` (sudah ada), `flutter_test`.

**Spec:** `docs/superpowers/specs/2026-09-25-fase2-hardening-design.md`

## Global Constraints

- **Flutter tidak terpasang di Termux** → `flutter analyze` / `flutter test` hanya di CI. Urutan TDD tetap: tulis test dulu (wajib fail secara logika), tulis implementasi, verifikasi akhir = CI hijau di Task 5.
- **Tanpa dependency baru** di `pubspec.yaml` — hanya bump `version: 2.3.7+20`.
- **`flutter analyze` wajib 0 issue** (CI blocking sebelum test, Fase 2 D1).
- **Copy UI Indonesia, tanpa em dash (`—`)** — AUDIT §5 larangan keras. Status rate limit persis: `Dibatasi, terlalu banyak. Coba lagi.`
- **Aturan RLS AGENTS.md:** policy SELECT `org_members` TIDAK BOLEH subquery ke `org_members`; cek member/org lain pakai `exists (select from org_members …)` dari **tabel lain** itu aman.
- **Monitoring tanpa PII:** nominal, note, kategori, isi notifikasi tidak boleh masuk `message`/`meta` error.
- **Gate `_onEvent` tidak berubah** — hanya blok `catch` yang disentuh.
- **Commit per task lokal** (pesan conventional: `feat:`/`fix:`/`test:`/`docs:`); push ke `main` di Task 5 (CI = satu-satunya verifier, batching push menghindari antrean CI merah beruntun). Dosis push sesuai alur AGENTS §3.3: push → watch → APK → doc.
- **User instruction:** semua file deliverable final ke `/sdcard/Download/SSR-SPACE/`; update AGENTS.md + AUDIT.md wajib sebelum dibilang selesai.

---

### Task 1: migration_11_hardening.sql (A3 rate limit + A4 audit log + client_errors)

**Files:**
- Create: `supabase/migration_11_hardening.sql`

**Interfaces:**
- Produces (SQL, dikonsumsi Task 3/4 lewat error `RATE_LIMITED` dan tabel `client_errors`): trigger `trg_rate_limit_auto_tx`, trigger `trg_audit_auto_tx`, trigger `trg_audit_org_join`, tabel `audit_logs`, tabel `client_errors`.
- Aturan baca client: rate limit → `raise exception 'RATE_LIMITED'` (Postgres default SQLSTATE `P0001`, message `RATE_LIMITED`).

- [ ] **Step 1: Tulis migration lengkap**

Isi file `supabase/migration_11_hardening.sql`:

```sql
-- SSR SPACE migration 11: rate limit auto-insert + audit log + client error log
-- Jalankan di Supabase Dashboard → SQL Editor SETELAH migration_10.
-- Menutup backlog A3 (rate limit), A4 (audit log), dan error monitoring in-house.

-- ============================================================
-- A3: rate limit auto-insert — 10 insert auto / 60 detik / org
-- Insert dari form (source_package is null) tidak kena.
-- ============================================================
create index if not exists transactions_auto_org_created_idx
  on transactions (org_id, created_at)
  where source_package is not null;

create or replace function public.enforce_auto_tx_rate_limit()
returns trigger
language plpgsql
security definer
set search_path = public
as $$
declare
  v_count int;
begin
  if new.source_package is null then
    return new;
  end if;

  select count(*) into v_count
  from transactions
  where org_id = new.org_id
    and source_package is not null
    and created_at > now() - interval '60 seconds';

  if v_count >= 10 then
    raise exception 'RATE_LIMITED';
  end if;

  return new;
end $$;

drop trigger if exists trg_rate_limit_auto_tx on transactions;
create trigger trg_rate_limit_auto_tx
  before insert on transactions
  for each row
  execute function public.enforce_auto_tx_rate_limit();

-- ============================================================
-- A4: audit log server — insert otomatis + join org
-- Client TANPA policy INSERT/UPDATE/DELETE (deny total); SELECT member saja.
-- ============================================================
create table if not exists audit_logs (
  id            uuid primary key default gen_random_uuid(),
  org_id        uuid not null references organizations(id) on delete cascade,
  actor_user_id uuid,
  event         text not null,
  meta          jsonb not null default '{}'::jsonb,
  created_at    timestamptz not null default now()
);

alter table audit_logs enable row level security;

-- Subquery ke org_members dari tabel LAIN aman (bukan policy di org_members).
drop policy if exists "member read audit_logs" on audit_logs;
create policy "member read audit_logs" on audit_logs
  for select using (
    exists (
      select 1 from org_members m
      where m.org_id = audit_logs.org_id and m.user_id = auth.uid()
    )
  );

create index if not exists audit_logs_org_created_idx
  on audit_logs (org_id, created_at desc);

create or replace function public.log_auto_tx_insert()
returns trigger
language plpgsql
security definer
set search_path = public
as $$
begin
  if new.source_package is null then
    return new;
  end if;
  insert into audit_logs (org_id, actor_user_id, event, meta)
  values (
    new.org_id,
    auth.uid(),
    'tx_auto_insert',
    jsonb_build_object(
      'tx_id', new.id,
      'amount', new.amount,
      'type', new.type,
      'source_package', new.source_package,
      'date', new.date
    )
  );
  return new;
end $$;

drop trigger if exists trg_audit_auto_tx on transactions;
create trigger trg_audit_auto_tx
  after insert on transactions
  for each row
  execute function public.log_auto_tx_insert();

create or replace function public.log_org_join()
returns trigger
language plpgsql
security definer
set search_path = public
as $$
begin
  insert into audit_logs (org_id, actor_user_id, event, meta)
  values (new.org_id, new.user_id, 'org_join', jsonb_build_object('role', new.role));
  return new;
end $$;

drop trigger if exists trg_audit_org_join on org_members;
create trigger trg_audit_org_join
  after insert on org_members
  for each row
  execute function public.log_org_join();

-- ============================================================
-- Error monitoring in-house: client_errors (ditulis client Task 2)
-- ============================================================
create table if not exists client_errors (
  id          uuid primary key default gen_random_uuid(),
  user_id     uuid,
  org_id      uuid,
  message     text not null,
  stack       text,
  context     text,
  app_version text not null,
  created_at  timestamptz not null default now()
);

alter table client_errors enable row level security;

drop policy if exists "own client_errors insert" on client_errors;
create policy "own client_errors insert" on client_errors
  for insert with check (user_id = auth.uid());

drop policy if exists "own client_errors read" on client_errors;
create policy "own client_errors read" on client_errors
  for select using (user_id = auth.uid());

create index if not exists client_errors_user_created_idx
  on client_errors (user_id, created_at desc);
```

- [ ] **Step 2: Self-check aturan keras (baca ulang file)**

Checklist wajib terpenuhi di file:
1. Tidak ada policy apa pun di `org_members` yang menambah subquery `org_members` (hanya trigger INSERT baru, policy tidak disentuh).
2. Semua fungsi trigger `security definer` + `set search_path = public`.
3. `audit_logs` dan `client_errors` `enable row level security`; tidak ada policy INSERT/UPDATE/DELETE di `audit_logs`.
4. Rate limit hanya saat `source_package is not null`.
5. Tidak ada em dash / komentar placeholder `TBD`/`TODO`.

- [ ] **Step 3: Commit**

```bash
git add supabase/migration_11_hardening.sql
git commit -m "feat: migration_11 rate limit auto-insert + audit_logs + client_errors (A3/A4)"
```

Catatan: verifikasi SQL live (jalankan di Dashboard + uji flood) = checklist manual Task 6, karena tidak ada Supabase local stack.

---

### Task 2: AppInfo + ErrorReporter (TDD)

**Files:**
- Create: `lib/core/app_info.dart`
- Create: `lib/core/saas/error_reporter.dart`
- Test: `test/error_reporter_test.dart`

**Interfaces:**
- Consumes: tabel `client_errors` (Task 1), `SupabaseConfig.client` (`lib/core/saas/supabase_config.dart`).
- Produces (dipakai Task 3 + backup di Task 4):
  - `class AppInfo { static const String version; }`
  - `ErrorReporter.init()` → wire global handler
  - `static Future<void> ErrorReporter.capture(Object error, StackTrace stack, {String? context})`
  - Test-only: `ErrorReporter.reset()`, `ErrorReporter.admit(String signature, DateTime now)`, `ErrorReporter.payload({required String message, String? stack, String? context})`

- [ ] **Step 1: Tulis test dulu `test/error_reporter_test.dart`**

```dart
import 'package:flutter_test/flutter_test.dart';
import 'package:ssr_space/core/saas/error_reporter.dart';

void main() {
  setUp(ErrorReporter.reset);

  test('signature sama dalam 60 menit ditolak, lewat itu boleh lagi', () {
    final t0 = DateTime.now();
    expect(ErrorReporter.admit('notif|boom', t0), isTrue);
    expect(
      ErrorReporter.admit('notif|boom', t0.add(const Duration(minutes: 59))),
      isFalse,
    );
    expect(
      ErrorReporter.admit('notif|boom', t0.add(const Duration(minutes: 61))),
      isTrue,
    );
  });

  test('signature berbeda tidak saling menahan', () {
    final t0 = DateTime.now();
    expect(ErrorReporter.admit('a|boom', t0), isTrue);
    expect(ErrorReporter.admit('b|boom', t0), isTrue);
  });

  test('maks 20 event per jam, reset di jam berikutnya', () {
    final t0 = DateTime.now();
    for (var i = 0; i < ErrorReporter.maxPerHour; i++) {
      expect(ErrorReporter.admit('sig$i', t0), isTrue);
    }
    expect(ErrorReporter.admit('sig-lewat', t0), isFalse);
    expect(
      ErrorReporter.admit('sig-aku-jam-2', t0.add(const Duration(hours: 1))),
      isTrue,
    );
  });

  test('payload terpotong, kunci persis, tanpa field terlarang', () {
    final p = ErrorReporter.payload(
      message: 'x' * 600,
      stack: 'y' * 5000,
      context: 'notif_pipeline',
    );
    expect((p['message'] as String).length, 500);
    expect((p['stack'] as String).length, 4000);
    expect(p['context'], 'notif_pipeline');
    expect(p['app_version'], isNotEmpty);
    expect(
      p.keys.toSet(),
      {'message', 'stack', 'context', 'app_version'},
      reason: 'payload monitoring tidak boleh membawa kolom lain',
    );
  });

  test('payload stack null tetap valid', () {
    final p = ErrorReporter.payload(message: 'boom');
    expect(p['stack'], isNull);
    expect(p['context'], isNull);
  });
}
```

- [ ] **Step 2: Jalankan test (lokal tidak bisa) → pastikan gagal karena class belum ada**

```bash
flutter test test/error_reporter_test.dart
```

Catatan eksekutor: perintah ini **tidak jalan di Termux** (flutter tak terpasang). Lanjut Step 3; kegagalan "class tidak ada" diverifikasi otomatis oleh CI di Task 5.

- [ ] **Step 3: Tulis `lib/core/app_info.dart`**

```dart
/// Versi app — ikut di-bump bersama pubspec.yaml (tanpa package_info_plus).
class AppInfo {
  static const String version = '2.3.7+20';
}
```

- [ ] **Step 4: Tulis `lib/core/saas/error_reporter.dart`**

```dart
import 'dart:ui';

import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:ssr_space/core/app_info.dart';
import 'package:ssr_space/core/saas/supabase_config.dart';

/// Monitoring error in-house (Fase 2). Hanya kirim message/stack/context
/// + versi — nominal, note, dan isi notifikasi TIDAK PERNAH ikut (tanpa PII).
/// Gagal upload = drop senyap; monitoring tidak boleh memicu error baru.
class ErrorReporter {
  static const int maxPerHour = 20;
  static const Duration dedupeWindow = Duration(minutes: 60);
  static const int maxMessage = 500;
  static const int maxStack = 4000;

  static final Map<String, DateTime> _seen = {};
  static int _sentThisHour = 0;
  static DateTime _hourStart = DateTime.now();

  /// Pasang global handler. Dipanggil sekali di main().
  static void init() {
    FlutterError.onError = (details) {
      capture(
        details.exception,
        details.stack ?? StackTrace.empty,
        context: 'flutter_framework',
      );
    };
    PlatformDispatcher.instance.onError = (error, stack) {
      capture(error, stack, context: 'uncaught');
      return true; // sudah ditangani, jangan rethrow ke platform
    };
  }

  /// Catat satu event. Aman dipanggil dari mana pun; semua kegagalan ditelan.
  static Future<void> capture(
    Object error,
    StackTrace stack, {
    String? context,
  }) async {
    try {
      final now = DateTime.now();
      final message = error.toString();
      if (!admit('${context ?? '-'}|$message', now)) return;
      final prefs = await SharedPreferences.getInstance();
      final client = SupabaseConfig.client;
      await client.from('client_errors').insert({
        ...payload(
          message: message,
          stack: stack.toString(),
          context: context,
        ),
        'user_id': client.auth.currentUser?.id,
        'org_id': prefs.getString('active_org_id'),
      });
    } catch (_) {
      // drop senyap
    }
  }

  /// Gerbang anti-flood: dedupe per signature/jam + cap per jam.
  @visibleForTesting
  static bool admit(String signature, DateTime now) {
    final last = _seen[signature];
    if (last != null && now.difference(last) < dedupeWindow) return false;
    if (now.difference(_hourStart) >= const Duration(hours: 1)) {
      _hourStart = now;
      _sentThisHour = 0;
    }
    if (_sentThisHour >= maxPerHour) return false;
    _seen[signature] = now;
    _sentThisHour++;
    return true;
  }

  /// Body insert `client_errors` (tanpa user/org, diisi capture).
  @visibleForTesting
  static Map<String, dynamic> payload({
    required String message,
    String? stack,
    String? context,
  }) {
    return {
      'message': _clip(message, maxMessage),
      'stack': stack == null ? null : _clip(stack, maxStack),
      'context': context,
      'app_version': AppInfo.version,
    };
  }

  static String _clip(String s, int max) =>
      s.length <= max ? s : s.substring(0, max);

  @visibleForTesting
  static void reset() {
    _seen.clear();
    _sentThisHour = 0;
    _hourStart = DateTime.now();
  }
}
```

- [ ] **Step 5: Verifikasi logika test secara manual (baca kembali vs test)**

Trace cepat: (a) dedupe 59m false / 61m true; (b) 20 admit true ke-21 false, +1h reset; (c) keys payload persis 4; (d) clip 600→500. Bila tidak cocok, perbaiki kode sebelum commit.

- [ ] **Step 6: Commit**

```bash
git add lib/core/app_info.dart lib/core/saas/error_reporter.dart test/error_reporter_test.dart
git commit -m "feat: ErrorReporter in-house (throttle dedupe + cap/jam, tanpa PII) + AppInfo"
```

---

### Task 3: Mapping RATE_LIMITED + wiring capture di pipeline (TDD)

**Files:**
- Modify: `lib/core/saas/notif_track_service.dart` (tambah top-level `saveErrorStatus`; pakai di 2 catch; tambah `capture` di catch)
- Modify: `lib/main.dart:9-15` (init handler + `runZonedGuarded`)
- Test: `test/notif_track_test.dart` (tambah test)

**Interfaces:**
- Consumes: `ErrorReporter.capture` (Task 2), error `RATE_LIMITED` dari trigger (Task 1).
- Produces: `String saveErrorStatus(PostgrestException err)` — top-level di `notif_track_service.dart` (sudah ada pola top-level `scanErrorStatus`/`eventTime` di file yang sama).

- [ ] **Step 1: Tambah test di `test/notif_track_test.dart`**

Tambah import di puncak file (gabung dengan import yang sudah ada):

```dart
import 'package:supabase_flutter/supabase_flutter.dart';
```

Tambah di dalam `main()`:

```dart
  test('saveErrorStatus: RATE_LIMITED → Dibatasi', () {
    final err = PostgrestException(message: 'RATE_LIMITED', code: 'P0001');
    expect(saveErrorStatus(err), 'Dibatasi, terlalu banyak. Coba lagi.');
  });

  test('saveErrorStatus: duplikat 23505 → Sudah pernah dicatat', () {
    final err = PostgrestException(
      message: 'duplicate key value violates unique constraint',
      code: '23505',
    );
    expect(saveErrorStatus(err), 'Sudah pernah dicatat');
  });

  test('saveErrorStatus: error lain → Gagal simpan: <code>', () {
    final err = PostgrestException(message: 'boom', code: '42501');
    expect(saveErrorStatus(err), 'Gagal simpan: 42501');
  });
```

Catatan eksekutor: konstruktor `PostgrestException` dari `supabase_flutter 2.x` — `message` wajib, `code` named optional. Bila CI melaporkan signature berbeda, sesuaikan pemanggilan test (param lain `details`/`hint` diikutkan), JANGAN ubah production code demi test.

- [ ] **Step 2: Verifikasi test gagal (lokal tidak bisa) → lanjut, CI yang konfirmasi**

`flutter test` tidak tersedia di Termux; kegagalan "undefined_function saveErrorStatus" otomatis terbukti di CI Task 5.

- [ ] **Step 3: Tambah helper + mapping di `notif_track_service.dart`**

3a. Tambah fungsi top-level setelah blok `connectionLabel` (sekitar baris 55), gaya sama dengan `scanErrorStatus`:

```dart
/// Status baris recent saat insert transaksi ditolak server.
/// RATE_LIMITED = trigger rate limit auto-insert (migration_11).
String saveErrorStatus(PostgrestException err) {
  if (err.message.contains('RATE_LIMITED')) {
    return 'Dibatasi, terlalu banyak. Coba lagi.';
  }
  if (err.code == '23505') return 'Sudah pernah dicatat';
  return 'Gagal simpan: ${err.code}';
}
```

3b. Di `_onEvent`, ganti blok catch (sekitar baris 349-352):

```dart
      } on PostgrestException catch (err) {
        ErrorReporter.capture(
          err,
          StackTrace.current,
          context: 'notif_pipeline',
        );
        n.status = saveErrorStatus(err);
      }
```

3c. Di `forceSave`, ganti blok catch `PostgrestException` (sekitar baris 391-396):

```dart
    } on PostgrestException catch (err) {
      ErrorReporter.capture(err, StackTrace.current, context: 'notif_force');
      final msg = saveErrorStatus(err);
      n.status = msg;
      return msg;
    } catch (err, st) {
      ErrorReporter.capture(err, st, context: 'notif_force');
      return 'Gagal simpan. Coba lagi.';
    }
```

3d. Di `_onEvent`, catch-all paling luar (sekitar baris 354-356) ganti menjadi:

```dart
    } catch (err, st) {
      ErrorReporter.capture(err, st, context: 'notif_pipeline');
      debugPrint('track: $err');
    }
```

3e. Tambah import di puncak file:

```dart
import 'package:ssr_space/core/saas/error_reporter.dart';
```

- [ ] **Step 4: Wiring `main.dart`**

Ganti isi `lib/main.dart` menjadi:

```dart
import 'dart:async';

import 'package:flutter/material.dart';
import 'package:ssr_space/core/saas/error_reporter.dart';
import 'package:ssr_space/core/saas/foreground_track.dart';
import 'package:ssr_space/core/saas/supabase_config.dart';
import 'package:ssr_space/core/session/session_service.dart';
import 'package:ssr_space/core/theme/app_theme.dart';
import 'package:ssr_space/screens/splash_screen.dart';
import 'package:shared_preferences/shared_preferences.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  ErrorReporter.init();
  await SupabaseConfig.init();
  ForegroundTrack.initOnce();
  final prefs = await SharedPreferences.getInstance();
  final app = SsrSpaceApp(session: SessionService(prefs));
  runZonedGuarded(
    () => runApp(app),
    (err, stack) => ErrorReporter.capture(err, stack, context: 'zone'),
  );
}

class SsrSpaceApp extends StatelessWidget {
  final SessionService session;
  const SsrSpaceApp({super.key, required this.session});
  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'SSR SPACE',
      theme: SsrTheme.light(),
      home: SplashScreen(session: session),
      debugShowCheckedModeBanner: false,
    );
  }
}
```

- [ ] **Step 5: Baca ulang gate `_onEvent` — pastikan urutan filter TIDAK berubah**

Perubahan yang diizinkan hanya di dalam blok `catch`. Urutan gate 1-10 di AUDIT §3 wajib identik.

- [ ] **Step 6: Commit**

```bash
git add lib/core/saas/notif_track_service.dart lib/main.dart test/notif_track_test.dart
git commit -m "feat: map RATE_LIMITED ke status Dibatasi + wiring ErrorReporter ke main dan pipeline notif"
```

---

### Task 4: Backup multi-CSV (TDD) + tile di Lainnya

**Files:**
- Create: `lib/core/saas/backup_export.dart`
- Test: `test/backup_export_test.dart`
- Modify: `lib/screens/other_screen.dart` (state `backingUp`, metode `_backup()`, tile baru)

**Interfaces:**
- Consumes: `ErrorReporter.capture` (Task 2), `SupabaseConfig.client`, paket `csv`/`share_plus`/`path_provider` (sudah ada).
- Produces (dipakai `other_screen.dart`):
  - `List<String> backupFileNames()`
  - `String walletsCsv(List<Map<String, dynamic>> rows)`
  - `String transactionsCsv(List<Map<String, dynamic>> rows)`
  - `String budgetsCsv(List<Map<String, dynamic>> rows)`

- [ ] **Step 1: Tulis test dulu `test/backup_export_test.dart`**

```dart
import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:ssr_space/core/saas/backup_export.dart';

void main() {
  test('nama file backup', () {
    expect(backupFileNames(), [
      'dompet-ssr-space.csv',
      'transaksi-ssr-space.csv',
      'budget-ssr-space.csv',
    ]);
  });

  test('dompet CSV: header + baris', () {
    final csv = walletsCsv([
      {'id': 'w1', 'name': 'DANA', 'type': 'ewallet'},
    ]);
    final lines = LineSplitter().split(csv).toList();
    expect(lines[0], 'id,nama,tipe');
    expect(lines[1], 'w1,DANA,ewallet');
    expect(lines.length, 2);
  });

  test('transaksi CSV: header lengkap + escaping koma/kutip', () {
    final csv = transactionsCsv([
      {
        'id': 't1',
        'code': 'TX-000001',
        'date': '2026-09-25',
        'type': 'out',
        'amount': 15000,
        'category': 'Makan',
        'note': 'Nasi, "komplit"',
        'wallet_id': 'w1',
        'to_wallet_id': null,
        'source_package': 'id.dana',
      },
    ]);
    final lines = LineSplitter().split(csv).toList();
    expect(
      lines[0],
      'id,kode,tanggal,jenis,nominal,kategori,catatan,dompet_id,ke_dompet_id,sumber_aplikasi',
    );
    expect(lines[1], contains('"Nasi, ""komplit"""'));
    expect(lines[1], contains('15000'));
    expect(lines[1], contains('id.dana'));
  });

  test('budget CSV: header + limit', () {
    final csv = budgetsCsv([
      {'category': 'Makan', 'month': '2026-09', 'limit_amount': 800000},
    ]);
    final lines = LineSplitter().split(csv).toList();
    expect(lines[0], 'kategori,bulan,limit');
    expect(lines[1], 'Makan,2026-09,800000');
  });

  test('baris kosong = hanya header', () {
    expect(
      LineSplitter().split(walletsCsv(const [])).toList(),
      ['id,nama,tipe'],
    );
  });
}
```

- [ ] **Step 2: Verifikasi gagal (lokal tak bisa) → lanjut**

Import `backup_export` belum ada → CI Task 5 yang konfirmasi urutan TDD ini.

- [ ] **Step 3: Tulis `lib/core/saas/backup_export.dart`**

```dart
import 'package:csv/csv.dart';

/// Nama file cadangan, urutan = [dompet, transaksi, budget].
List<String> backupFileNames() => const [
      'dompet-ssr-space.csv',
      'transaksi-ssr-space.csv',
      'budget-ssr-space.csv',
    ];

String walletsCsv(List<Map<String, dynamic>> rows) {
  final data = <List<dynamic>>[
    ['id', 'nama', 'tipe'],
    for (final r in rows)
      [
        (r['id'] ?? '').toString(),
        (r['name'] ?? '').toString(),
        (r['type'] ?? '').toString(),
      ],
  ];
  return const ListToCsvConverter().convert(data);
}

String transactionsCsv(List<Map<String, dynamic>> rows) {
  final data = <List<dynamic>>[
    [
      'id',
      'kode',
      'tanggal',
      'jenis',
      'nominal',
      'kategori',
      'catatan',
      'dompet_id',
      'ke_dompet_id',
      'sumber_aplikasi',
    ],
    for (final r in rows)
      [
        (r['id'] ?? '').toString(),
        (r['code'] ?? '').toString(),
        (r['date'] ?? '').toString(),
        (r['type'] ?? '').toString(),
        (r['amount'] ?? '').toString(),
        (r['category'] ?? '').toString(),
        (r['note'] ?? '').toString(),
        (r['wallet_id'] ?? '').toString(),
        (r['to_wallet_id'] ?? '').toString(),
        (r['source_package'] ?? '').toString(),
      ],
  ];
  return const ListToCsvConverter().convert(data);
}

String budgetsCsv(List<Map<String, dynamic>> rows) {
  final data = <List<dynamic>>[
    ['kategori', 'bulan', 'limit'],
    for (final r in rows)
      [
        (r['category'] ?? '').toString(),
        (r['month'] ?? '').toString(),
        (r['limit_amount'] ?? '').toString(),
      ],
  ];
  return const ListToCsvConverter().convert(data);
}
```

- [ ] **Step 4: Baca ulang test vs implementasi**

Khusus: `ListToCsvConverter` me-render kutip dengan ganda (`""`) dan meng-escape koma — `'"Nasi, ""komplit"""'` harus persis ada di baris hasil. Bila key `limit_amount`/`source_package` tidak cocok dengan kolom Supabase (dicek dari `migration_03`/`migration_06`), perbaiki sekarang.

- [ ] **Step 5: Wire tile di `other_screen.dart`**

5a. Tambah import:

```dart
import 'dart:io';

import 'package:share_plus/share_plus.dart';
import 'package:path_provider/path_provider.dart';
import 'package:ssr_space/core/saas/backup_export.dart';
import 'package:ssr_space/core/saas/error_reporter.dart';
```

5b. Di `_OtherScreenState`, tambah field + metode (taruh sebelum `build`):

```dart
  bool backingUp = false;

  Future<void> _backup() async {
    if (backingUp) return;
    setState(() => backingUp = true);
    try {
      final p = await SharedPreferences.getInstance();
      final orgId = p.getString('active_org_id') ?? '';
      if (orgId.isEmpty) throw StateError('org kosong');
      final c = SupabaseConfig.client;
      final List<Map<String, dynamic>> wallets = await c
          .from('wallets')
          .select()
          .eq('org_id', orgId)
          .order('created_at');
      final List<Map<String, dynamic>> txs = await c
          .from('transactions')
          .select()
          .eq('org_id', orgId)
          .order('date')
          .limit(10000);
      final List<Map<String, dynamic>> budgets = await c
          .from('budgets')
          .select()
          .eq('org_id', orgId)
          .order('month');
      final contents = [
        walletsCsv(wallets),
        transactionsCsv(txs),
        budgetsCsv(budgets),
      ];
      final dir = await getTemporaryDirectory();
      final files = <XFile>[];
      for (var i = 0; i < contents.length; i++) {
        final f = File('${dir.path}/${backupFileNames()[i]}');
        await f.writeAsString(contents[i]);
        files.add(XFile(f.path));
      }
      await Share.shareXFiles(files, text: 'Cadangan data SSR SPACE (CSV)');
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('File cadangan siap dibagikan.')),
      );
    } catch (err, st) {
      ErrorReporter.capture(err, st, context: 'backup');
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Gagal membuat cadangan. Coba lagi.')),
      );
    } finally {
      if (mounted) setState(() => backingUp = false);
    }
  }
```

5c. Tambah `SectionCard` baru **setelah** SectionCard "Pelacakan" (sebelum SectionCard terakhir "Lainnya"/billing — sisipkan card sendiri, jangan menumpuk di dalam card lain):

```dart
              SectionCard(
                margin: const EdgeInsets.only(bottom: SsrSpace.md),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Data',
                      style: Theme.of(context).textTheme.bodySmall,
                    ),
                    const SizedBox(height: SsrSpace.xs),
                    _navTile(
                      icon: Icons.save_alt_outlined,
                      title: 'Cadangkan data',
                      subtitle: 'Ekspor seluruh workspace ke CSV',
                      onTap: backingUp ? null : _backup,
                    ),
                  ],
                ),
              ),
```

5d. `ListTile.onTap` menerima `null` untuk disabled — kalau analyzer menolak tipe `VoidCallback?` tidak masalah (`onTap` memang nullable di Flutter). Saat `backingUp`, tampilkan progress: ganti `_iconTile` trailing bila perlu — **cukup** tambahkan di `subtitle` tidak usah; kesederhanaan: selama `backingUp == true` onTap null sudah menandakan sibuk. Verifikasi tidak ada overflow.

- [ ] **Step 6: Commit**

```bash
git add lib/core/saas/backup_export.dart test/backup_export_test.dart lib/screens/other_screen.dart
git commit -m "feat: backup manual multi-CSV (dompet/transaksi/budget) + tile Cadangkan data"
```

---

### Task 5: Version bump + push + CI hijau + APK ke Download

**Files:**
- Modify: `pubspec.yaml:4`

**Interfaces:**
- Consumes: seluruh Task 1-4.
- Produces: APK artifact `ssr-space-apk`, tag versi `2.3.7+20`.

- [ ] **Step 1: Bump versi**

`pubspec.yaml` baris `version:` → `2.3.7+20`. Sinkron dengan `AppInfo.version` ('2.3.7+20') di `lib/core/app_info.dart` — kalau tidak sama, perbaiki.

- [ ] **Step 2: Push ke main**

```bash
git add pubspec.yaml
git commit -m "chore: bump versi 2.3.7+20 (Fase 2 hardening)"
git push origin main
```

- [ ] **Step 3: Watch CI sampai selesai**

```bash
gh run watch $(gh run list --limit 1 --json databaseId --jq '.[0].databaseId') --exit-status
```

- [ ] **Step 4: Bila merah — perbaiki, commit, push, ulang Step 3**

Mode gagal yang mungkin & cara tangani:
- `flutter analyze` issue (unused import, type) → hapus/perbaiki baris, commit `fix: ...`, push ulang.
- Test gagal → baca pesan, perbaiki **production code** (kecuali signature `PostgrestException` di test — boleh sesuaikan test, Task 3 catatan).
- `flutter build apk` gagal → API Flutter stable berbeda; cek pemakaian widget/import.

Ulangi sampai **hijau penuh** (analyze → test → APK).

- [ ] **Step 5: Download APK ke Download user**

```bash
gh run download $(gh run list --limit 1 --json databaseId --jq '.[0].databaseId') -n ssr-space-apk -D /sdcard/Download/SSR-SPACE/
```

- [ ] **Step 6: Sebut nama file hasil di jawaban akhir**

Catat nama file APK persis hasil `ls /sdcard/Download/SSR-SPACE/`.

---

### Task 6: Docs (AGENTS + AUDIT) + push final + reminder migration

**Files:**
- Modify: `AGENTS.md` (§3.2b tabel Fase 2, §4 daftar fitur, versi)
- Modify: `AUDIT.md` (header update, §4 backlog ✅ A3/A4/D5 + monitoring, §5 checklist manual, §6 test, §7 changelog)

**Interfaces:**
- Consumes: hasil Task 1-5 (nama run CI, commit hash, nama APK).

- [ ] **Step 1: Update AGENTS.md**

- §1 tabel versi → `2.3.7+20`.
- §3.2b baris **Fase 2** → `✅ done 2.3.7+20` dengan rincian: D1 analyze CI, A3 rate limit trigger, A4 audit_logs, error monitoring `client_errors`, D5 backup manual multi-CSV; catatan migration_11 dijalankan manual user.
- §4 tambah sub-bagian singkat "Fase 2 hardening" yang mendeskripsikan 4 fitur + lokasi file (`supabase/migration_11_hardening.sql`, `lib/core/saas/error_reporter.dart`, `lib/core/saas/backup_export.dart`).
- §3.4 daftar urutan migration → tambah `migration_11_hardening.sql` setelah `_10`.

- [ ] **Step 2: Update AUDIT.md**

- Header "Update 2026-09-25": tambah baris Fase 2 hardening selesai (run CI hijau, nama APK).
- §4 Sprint A: **A3** ✅ (detail: trigger 10/60s/org, status "Dibatasi, terlalu banyak. Coba lagi."); **A4** ✅ (`audit_logs`, trigger `tx_auto_insert`/`org_join`, deny client write).
- §4 Sprint D: **D5** ✅ (manual multi-CSV, tile Lainnya → Cadangkan data; terjadwal pg_cron = backlog Fase 3).
- Tambah item backlog baru bila perlu: **error monitoring retention/cleanup `client_errors`** (pg_cron Fase 3) + **UI baca `audit_logs`** (opsional).
- §5 checklist: tambah 7 item verifikasi manual dari spec §7 (migration_11, audit row, RLS deny, flood "Dibatasi", client_errors tanpa PII, share 3 CSV, APK baru).
- §6 tabel test: tambah `error_reporter_test.dart` + `backup_export_test.dart` + `saveErrorStatus` (di `notif_track_test.dart`).
- §7 changelog: baris commit baru (`feat: migration_11 …`, `feat: ErrorReporter …`, `feat: map RATE_LIMITED …`, `feat: backup …`, `chore: bump …`).

- [ ] **Step 3: Commit + push docs**

```bash
git add AGENTS.md AUDIT.md
git commit -m "docs: catat Fase 2 hardening (A3/A4/monitoring/D5) di AGENTS + AUDIT"
git push origin main
```

- [ ] **Step 4: Akhiri dengan pengingat wajib ke user**

Jawaban akhir HARUS memuat:
1. Nama file/folder APK di `/sdcard/Download/SSR-SPACE/`.
2. **Reminder: jalankan `supabase/migration_11_hardening.sql` di Supabase Dashboard → SQL Editor** (setelah migration_10) — tanpa ini rate limit/audit/client_errors belum aktif.
3. Checklist verifikasi manual device (dari spec §7) untuk dijalankan user.

---

## Self-Review (plan vs spec)

1. **Spec coverage:**
   - Spec §2 A3 → Task 1 (trigger) + Task 3 (mapping status) ✅
   - Spec §3 A4 → Task 1 ✅ (event, RLS, index, tanpa UI sesuai spec)
   - Spec §4 monitoring → Task 2 (handler+throttle+payload) + Task 3 (wiring main/pipeline) + tabel di Task 1 ✅
   - Spec §5 backup → Task 4 ✅
   - Spec §6 test → test di Task 2/3/4, 2 file baru ✅
   - Spec §7 checklist → Task 6 Step 2 ✅
   - Spec §8 dampak file → semua file terpetakan ✅ (opsional "load catch capture" spec tidak diwajibkan; backup & pipeline sudah dicover)
   - Spec §9 urutan eksekusi → Task 1→6 sesuai ✅
2. **Placeholder scan:** tidak ada TBD/TODO; semua step berisi kode/perintah konkret ✅
3. **Type consistency:** `ErrorReporter.admit(String, DateTime)` / `payload({message, stack, context})` konsisten test↔impl; `saveErrorStatus(PostgrestException)` konsisten; `backupFileNames()`/`*Csv(rows)` konsisten ✅
