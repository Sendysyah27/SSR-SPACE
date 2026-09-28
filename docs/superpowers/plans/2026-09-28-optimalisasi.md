# Optimalisasi 2.5.0 Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Rilis 2.5.0+47 berisi sheet catat ringan, nav 4 tab + Profil, notif tersimpan murni tanpa overlay, pengingat mingguan.

**Architecture:** Hapus rantai koreksi instan (overlay bus, pending, pinNotice) sampai ke akar termasuk dep dan inject CI; notif tersimpan menjadi info murni dengan tap ke detail read-only; cache dompet + debounce untuk sheet; jalur mingguan sejajar harian. Tanpa migration, tanpa dep baru.

**Tech Stack:** Flutter stable, Supabase, flutter_local_notifications ^22.3.1, timezone, shared_preferences. CI: analyze (0 issue termasuk info) → test → APK.

**Spec:** `docs/superpowers/specs/2026-09-28-optimalisasi-design.md`

## Global Constraints

- Bahasa UI Indonesia, copy baru lewat `lib/utils/strings.dart` ID+EN, tanpa em dash, tanpa klaim palsu.
- Nominal lewat `amt()`; tanggal lewat helper `lib/utils/datetime.dart`.
- `flutter analyze` 0 issue (info pun fatal di CI); pelajaran lama: `dart` lokal WAJIB `--enable-asserts`, `const` hanya di call-site full-const.
- Version Skema A: `pubspec.yaml` + `lib/utils/app_info.dart` identik; tiap bump tambah entri `assets/changelog_id.md` paling atas + sesuaikan "Versi terpasang".
- Deliverable hanya varian `*-arm64.apk` ke `/sdcard/Download/SSR-SPACE/`.
- Bila CI merah: fix dengan commit baru, JANGAN amend commit gagal.
- Catat lokal `AGENTS.md` + `AUDIT.md` §7, gabung push ini (bukan commit docs sendirian).

---

### Task 1: Pengingat mingguan, logika + service + settings state

**Files:**
- Modify: `lib/services/reminder_schedule.dart` (tambah `nextWeekly`)
- Modify: `test/reminder_test.dart` (tambah 5 case)
- Modify: `lib/services/reminder_service.dart` (tambah `scheduleWeekly` + `cancelWeekly`, import schedule)
- Modify: `lib/services/app_settings.dart` (4 kunci + 4 notifier + load + 3 setter)

**Interfaces:**
- Consumes: `nextDaily`, `reminderKeyFor`, `tr`, pola `scheduleDaily`/`cancel` yang sudah ada.
- Produces: `nextWeekly(int,int,int,DateTime)->DateTime`, `ReminderService.scheduleWeekly(weekday,hour,minute)`, `cancelWeekly()`, notifier `weeklyEnabled/weeklyWeekday/weeklyHour/weeklyMinute`, setter `setWeeklyEnabled/setWeeklyDay/setWeeklyTime`.

- [ ] **Step 1: Tambah `nextWeekly` ke reminder_schedule.dart**

```dart
/// Jadwal mingguan berikutnya untuk hari [weekday] (1 Senin .. 7 Minggu)
/// pukul jam:menit. Hari ini bila jam masih di depan, kalau tidak minggu
/// depan hari yang sama. Jepit aman, tak pernah throw.
DateTime nextWeekly(int weekday, int hour, int minute, DateTime now) {
  final wd = weekday.clamp(1, 7);
  final h = hour.clamp(0, 23);
  final m = minute.clamp(0, 59);
  var candidate = DateTime(now.year, now.month, now.day, h, m);
  final delta = (wd - candidate.weekday) % 7;
  candidate = candidate.add(Duration(days: delta));
  if (!candidate.isAfter(now)) {
    candidate = candidate.add(const Duration(days: 7));
  }
  return candidate;
}
```

- [ ] **Step 2: Tambah 5 test ke test/reminder_test.dart (TDD RED)**

```dart
test('mingguan: hari sama jam masih di depan = hari ini', () {
  final now = DateTime(2026, 9, 28, 10, 0); // Senin
  expect(nextWeekly(1, 12, 0, now), DateTime(2026, 9, 28, 12, 0));
});
test('mingguan: hari sama jam lewat = minggu depan', () {
  final now = DateTime(2026, 9, 28, 10, 0); // Senin
  expect(nextWeekly(1, 7, 0, now), DateTime(2026, 10, 5, 7, 0));
});
test('mingguan: beda hari = hari itu minggu ini', () {
  final now = DateTime(2026, 9, 28, 10, 0); // Senin
  expect(nextWeekly(7, 20, 0, now), DateTime(2026, 10, 4, 20, 0));
});
test('mingguan: tepat sama dengan sekarang = minggu depan', () {
  final now = DateTime(2026, 9, 28, 20, 0);
  expect(nextWeekly(1, 20, 0, now), DateTime(2026, 10, 5, 20, 0));
});
test('mingguan: di luar rentang dijepit, tidak throw', () {
  final now = DateTime(2026, 9, 28, 10, 0); // Senin
  expect(nextWeekly(0, 99, -5, now), DateTime(2026, 9, 28, 23, 0));
});
```

Kalender check: 2026-09-28 = Senin (hari env), 2026-10-04 = Minggu, 2026-10-05 = Senin. Case terakhir: wd dijepit 1, jam 23:00 hari ini masih di depan 10:00 = hari ini.

- [ ] **Step 3: Verifikasi RED lalu GREEN via CI** — `flutter` tak ada lokal; file murni boleh dicek logika manual via `dart --enable-asserts` bila memungkinkan, kepastian final = CI `flutter test`.
- [ ] **Step 4: Tambah scheduleWeekly + cancelWeekly ke reminder_service.dart**

```dart
static const int weeklyNotifId = 7002;

static Future<void> scheduleWeekly(int weekday, int hour, int minute) async {
  await init();
  final android = _plugin
      .resolvePlatformSpecificImplementation<
        AndroidFlutterLocalNotificationsPlugin
      >();
  try {
    await android?.requestNotificationsPermission();
  } catch (e) {
    debugPrint('reminder izin gagal: $e');
  }
  try {
    await android?.requestExactAlarmsPermission();
  } catch (e) {
    debugPrint('reminder alarm tepat gagal: $e');
  }
  final wd = weekday.clamp(1, 7);
  final h = hour.clamp(0, 23);
  final m = minute.clamp(0, 59);
  final next = nextWeekly(wd, h, m, DateTime.now());
  final scheduled = tz.TZDateTime(
    tz.local, next.year, next.month, next.day, next.hour, next.minute,
  );
  const details = NotificationDetails(
    android: AndroidNotificationDetails(
      channelId, channelName, channelDescription: channelDesc,
    ),
  );
  final body = tr(reminderKeyFor(next, h));
  try {
    await _plugin.zonedSchedule(
      id: weeklyNotifId,
      scheduledDate: scheduled,
      notificationDetails: details,
      androidScheduleMode: AndroidScheduleMode.exactAllowWhileIdle,
      title: tr('st_weekly_on'),
      body: body,
      matchDateTimeComponents: DateTimeComponents.dayOfWeekAndTime,
    );
  } catch (e) {
    debugPrint('reminder tepat gagal, coba longgar: $e');
    await _plugin.zonedSchedule(
      id: weeklyNotifId,
      scheduledDate: scheduled,
      notificationDetails: details,
      androidScheduleMode: AndroidScheduleMode.inexactAllowWhileIdle,
      title: tr('st_weekly_on'),
      body: body,
      matchDateTimeComponents: DateTimeComponents.dayOfWeekAndTime,
    );
  }
}

static Future<void> cancelWeekly() => _plugin.cancel(id: weeklyNotifId);
```

Tambah import `reminder_schedule.dart` (untuk `nextWeekly`; `nextDaily` sudah dipakai file ini).

- [ ] **Step 5: Tambah state mingguan ke app_settings.dart**

Kunci (dekat `_kReminderMinute`):
```dart
const _kWeeklyEnabled = 'weekly_enabled';
const _kWeeklyWeekday = 'weekly_weekday';
const _kWeeklyHour = 'weekly_hour';
const _kWeeklyMinute = 'weekly_minute';
```
Notifier (dekat reminderMinute):
```dart
final weeklyEnabled = ValueNotifier<bool>(false);
final weeklyWeekday = ValueNotifier<int>(7);
final weeklyHour = ValueNotifier<int>(20);
final weeklyMinute = ValueNotifier<int>(0);
```
Load (setelah reminderMinute):
```dart
weeklyEnabled.value = prefs.getBool(_kWeeklyEnabled) ?? false;
weeklyWeekday.value = (prefs.getInt(_kWeeklyWeekday) ?? 7).clamp(1, 7);
weeklyHour.value = (prefs.getInt(_kWeeklyHour) ?? 20).clamp(0, 23);
weeklyMinute.value = (prefs.getInt(_kWeeklyMinute) ?? 0).clamp(0, 59);
```
Setter (setelah setReminderTime):
```dart
Future<void> setWeeklyEnabled(bool v) async {
  weeklyEnabled.value = v;
  final prefs = await SharedPreferences.getInstance();
  await prefs.setBool(_kWeeklyEnabled, v);
}

Future<void> setWeeklyDay(int weekday) async {
  weeklyWeekday.value = weekday.clamp(1, 7);
  final prefs = await SharedPreferences.getInstance();
  await prefs.setInt(_kWeeklyWeekday, weeklyWeekday.value);
}

Future<void> setWeeklyTime(int hour, int minute) async {
  weeklyHour.value = hour.clamp(0, 23);
  weeklyMinute.value = minute.clamp(0, 59);
  final prefs = await SharedPreferences.getInstance();
  await prefs.setInt(_kWeeklyHour, weeklyHour.value);
  await prefs.setInt(_kWeeklyMinute, weeklyMinute.value);
}
```

---

### Task 2: Pengingat mingguan UI + strings + reschedule start

**Files:**
- Modify: `lib/utils/strings.dart` (kunci weekly + nama hari, dekat `st_reminder_time`)
- Modify: `lib/screens/lainnya/settings_screen.dart` (`_ReminderCard`: seksi mingguan)
- Modify: `lib/main.dart` (jadwalkan ulang mingguan saat start)
- Check: `lib/screens/lainnya/settings_search.dart` (tambah entri weekly HANYA bila struktur entrinya mendukung aksi fokus seperti entri daily; bila tidak, lewati dan catat)

**Interfaces:**
- Consumes: Task 1 (`scheduleWeekly`, `cancelWeekly`, notifier + setter weekly).
- Produces: UI toggle + hari + jam mingguan yang menjadwalkan id 7002.

- [ ] **Step 1: Tambah strings (ID+EN, tanpa em dash)**

```dart
'st_weekly_on': {'id': 'Pengingat mingguan', 'en': 'Weekly reminder'},
'st_weekly_time': {'id': 'Waktu pengingat mingguan', 'en': 'Weekly reminder time'},
'st_weekly_day': {'id': 'Hari', 'en': 'Day'},
'wd_1': {'id': 'Senin', 'en': 'Monday'},
'wd_2': {'id': 'Selasa', 'en': 'Tuesday'},
'wd_3': {'id': 'Rabu', 'en': 'Wednesday'},
'wd_4': {'id': 'Kamis', 'en': 'Thursday'},
'wd_5': {'id': 'Jumat', 'en': 'Friday'},
'wd_6': {'id': 'Sabtu', 'en': 'Saturday'},
'wd_7': {'id': 'Minggu', 'en': 'Sunday'},
```

- [ ] **Step 2: Seksi mingguan di `_ReminderCard`** — setelah Column harian, tambah `Divider` + `SwitchListTile` (title `tr('st_weekly_on')`, value `weeklyEnabled`) + Row (DropdownButton<int> value weekday items `wd_1..wd_7`, teks jam `HH:MM`, IconButton jam). Handler:
```dart
Future<void> _toggleWeekly(bool v) async {
  await setWeeklyEnabled(v);
  try {
    if (v) {
      await ReminderService.scheduleWeekly(
        weeklyWeekday.value, weeklyHour.value, weeklyMinute.value);
    } else {
      await ReminderService.cancelWeekly();
    }
  } catch (e) {
    debugPrint('pengingat mingguan gagal: $e');
  }
}
```
Bungkus builder mingguan dengan `ValueListenableBuilder` berlapis seperti pola harian (enabled → weekday → hour → minute). Perubahan hari/jam saat enabled = `setWeeklyDay/Time` lalu `scheduleWeekly` ulang.
- [ ] **Step 3: main.dart reschedule** — setelah blok daily:
```dart
try {
  if (weeklyEnabled.value) {
    await ReminderService.scheduleWeekly(
      weeklyWeekday.value.clamp(1, 7),
      weeklyHour.value.clamp(0, 23),
      weeklyMinute.value.clamp(0, 59),
    );
  }
} catch (e) {
  debugPrint('jadwal ulang mingguan gagal: $e');
}
```
`ReminderService.init()` sudah dipanggil blok daily bila daily aktif; bila daily mati tapi weekly aktif, `scheduleWeekly` memanggil `init()` sendiri (aman, `_inited` guard).
- [ ] **Step 4: settings_search** — baca entri `st_reminder_on`/`st_reminder_time`, mirror untuk `st_weekly_on` dengan aksi fokus yang sama. Bila tak sepadan, lewati.

---

### Task 3: Sheet catat ringan (cache + konkurensi + debounce)

**Files:**
- Modify: `lib/services/wallet_service.dart` (tambah `WalletCache` + `CachedWallets`)
- Modify: `lib/widgets/tx_input_sheet.dart` (`openTxInputSheet` + debounce `_applyQuick`)
- Test: `test/wallet_cache_test.dart` (baru, 4 case deterministik)

**Interfaces:**
- Consumes: `Wallet`, `WalletBalance`, `WalletService().list/balances`.
- Produces: `WalletCache.peek/store/invalidate`, `CachedWallets`.

- [ ] **Step 1: Test dulu (TDD RED), `test/wallet_cache_test.dart`**

```dart
import 'package:flutter_test/flutter_test.dart';
import 'package:ssr_space/models/wallet.dart';
import 'package:ssr_space/services/wallet_service.dart';

Wallet _w(String id, String name) =>
    Wallet(id: id, orgId: 'o1', name: name, type: 'cash');

void main() {
  test('peek kosong sebelum store', () {
    WalletCache.invalidate();
    expect(WalletCache.peek('o1'), null);
  });
  test('store lalu peek kena', () {
    WalletCache.invalidate();
    WalletCache.store('o1', [_w('a', 'Kas')], {});
    final c = WalletCache.peek('o1');
    expect(c, isNotNull);
    expect(c!.wallets.map((w) => w.id), ['a']);
  });
  test('org beda tidak kena', () {
    WalletCache.invalidate();
    WalletCache.store('o1', [_w('a', 'Kas')], {});
    expect(WalletCache.peek('o2'), null);
  });
  test('invalidate menghapus', () {
    WalletCache.invalidate();
    WalletCache.store('o1', [_w('a', 'Kas')], {});
    WalletCache.invalidate();
    expect(WalletCache.peek('o1'), null);
  });
}
```

Butuh konstruktor `Wallet` — baca `lib/models/wallet.dart` saat eksekusi, sesuaikan field (contoh di atas asumsi; samakan dengan `fromMap`/konstruktor nyata).

- [ ] **Step 2: Implementasi `WalletCache` di wallet_service.dart**

```dart
class CachedWallets {
  final List<Wallet> wallets;
  final Map<String, double> balances;
  const CachedWallets(this.wallets, this.balances);
}

class WalletCache {
  static CachedWallets? _cached;
  static String? _orgId;
  static DateTime? _at;
  static const ttl = Duration(seconds: 60);

  static CachedWallets? peek(String orgId) {
    if (_orgId != orgId || _cached == null || _at == null) return null;
    if (DateTime.now().difference(_at!) > ttl) return null;
    return _cached;
  }

  static void store(String orgId, List<Wallet> wallets, Map<String, double> balances) {
    _orgId = orgId;
    _cached = CachedWallets(List.of(wallets), Map.of(balances));
    _at = DateTime.now();
  }

  static void invalidate() {
    _cached = null;
    _at = null;
  }
}
```

- [ ] **Step 3: `openTxInputSheet` buka cepat** — ganti blok try/list/balances berurutan menjadi:
```dart
final cached = WalletCache.peek(orgId);
late final List<Wallet> wallets;
Map<String, double> balances = {};
if (cached != null) {
  wallets = cached.wallets;
  balances = cached.balances;
  // Segarkan diam-diam untuk buka berikutnya; sheet ini pakai snapshot.
  unawaited(_refreshWalletCache(orgId));
} else {
  try {
    final results = await Future.wait([
      WalletService().list(orgId),
      WalletService().balances(orgId).catchError((_) => <WalletBalance>[]),
    ]);
    wallets = (results[0] as List<Wallet>);
    balances = {for (final b in (results[1] as List<WalletBalance>)) b.walletId: b.balance};
    WalletCache.store(orgId, wallets, balances);
  } catch (_) {
    if (!context.mounted) return false;
    ScaffoldMessenger.of(context)
        .showSnackBar(SnackBar(content: Text(tr('conn_error'))));
    return false;
  }
}
```
Helper file-private di bawah `openTxInputSheet`:
```dart
Future<void> _refreshWalletCache(String orgId) async {
  try {
    final wallets = await WalletService().list(orgId);
    Map<String, double> balances = {};
    try {
      final bals = await WalletService().balances(orgId);
      balances = {for (final b in bals) b.walletId: b.balance};
    } catch (_) {}
    WalletCache.store(orgId, wallets, balances);
  } catch (_) {}
}
```
Import yang dibutuhkan: `dart:async` (unawaited), `models/wallet_balance.dart` (tipenya; cek import eksisting, tambah bila belum ada).
- [ ] **Step 4: Debounce ketik cepat** — di `_TxInputSheetState` tambah `Timer? _quickDeb;`, ubah `_QuickSection(... onChanged: _applyQuick)` menjadi callback debounce:
```dart
void _onQuickChanged(String v) {
  _quickDeb?.cancel();
  _quickDeb = Timer(const Duration(milliseconds: 300), () {
    if (mounted) _applyQuick(v);
  });
}
```
`dispose()` tambah `_quickDeb?.cancel();`. Import `dart:async`.

---

### Task 4: Navigasi 4 tab + Profil

**Files:**
- Modify: `lib/screens/shell/main_shell.dart` (4 destinasi, stack tanpa OtherScreen, `openProfil`)
- Modify: `lib/screens/lainnya/other_screen.dart` (judul AppBar → `nav_profil`)
- Modify: `lib/utils/strings.dart` (tambah `nav_profil`; hapus `nav_lainnya` HANYA bila grep nol rujukan)

**Interfaces:**
- Consumes: `OtherScreen(session:)`, `onProfil` yang sudah ada di Beranda.
- Produces: bottom nav 4 tab; Profil sebagai pushed route.

- [ ] **Step 1: main_shell.dart** — hapus import `other_screen.dart` (diganti import untuk push? push butuh import juga — PERTAHANKAN import, dipakai `openProfil`). Hapus `OtherScreen(session: widget.session)` dari children IndexedStack. Hapus destination ke-5 (`nav_lainnya`). Ubah `onProfil: () => _select(4)` menjadi `onProfil: _openProfil` dengan:
```dart
Future<void> _openProfil() async {
  await Navigator.of(context).push(
    MaterialPagePageRoute... // MaterialPageRoute(builder: (_) => OtherScreen(session: widget.session)),
  );
  if (mounted) _reloadTab(index);
}
```
Gunakan `MaterialPageRoute` (bukan PagePageRoute, itu typo contoh). Setelah kembali dari Profil, reload tab aktif (profil bisa mengubah settings). `_reloadTab` tetap 0-3. (Import overlay/correct di file ini dikerjakan Task 6.)
- [ ] **Step 2: other_screen `_appBar`** — `title: Text(tr('nav_lainnya'))` → `Text(tr('nav_profil'))`.
- [ ] **Step 3: strings** — tambah `'nav_profil': {'id': 'Profil', 'en': 'Profile'}` setelah `nav_lainnya`. Grep `nav_lainnya` di `lib/` + `test/`; bila nol rujukan, hapus barisnya.
- [ ] **Step 4: Cek tap target avatar** — `beranda_screen.dart` leading sudah `InkWell` + `CircleAvatar`; pastikan area sentuh ≥44px (CircleAvatar default 40 — bungkus padding sudah `EdgeInsets.only(left: 12)`; bila kurang, tambah `padding: EdgeInsets.all(4)` di InkWell child atau `constrained`. Verifikasi via baca kode, tanpa mengubah visual.

---

### Task 5: Hapus koreksi instan, notif murni di pipeline

**Files:**
- Delete: `lib/services/instant_correct.dart`, `lib/widgets/correct_sheet.dart`, `lib/widgets/correct_overlay.dart`, `lib/services/overlay_bus.dart`, `test/instant_correct_test.dart`
- Modify: `pubspec.yaml` (hapus baris `flutter_overlay_window: ^0.5.0`)
- Modify: `.github/workflows/apk.yml` (hapus blok `- run:` overlay SYSTEM_ALERT_WINDOW/OverlayService, baris 172-194)
- Modify: `lib/services/foreground_track.dart` (hapus `pinNotice` + `clearNotice` + doc di atasnya)
- Modify: `lib/main.dart` (hapus `overlayMain` + import `correct_overlay.dart`)
- Modify: `lib/services/auto_saved_notify.dart` (tambah `savedBody`, `showSaved`, tap handler)
- Modify: `lib/services/notif_track_service.dart` (lepas import instant_correct, ganti 3 panggilan `offer` → `showSaved`)
- Test: `test/auto_saved_notify_test.dart` (baru: `savedBody` 4 case + `autoSavedId` stabil)

**Interfaces:**
- Consumes: `tr`, `amt`, `matchWatchedApp`, `TransferPair` (pair.outTx/inTx sourcePackage).
- Produces: `savedBody({type,amount,app,appTo})->String`, `AutoSavedNotify.showSaved({txId,type,amount,app,appTo})`.

- [ ] **Step 1: Hapus file** — `rm lib/services/instant_correct.dart lib/widgets/correct_sheet.dart lib/widgets/correct_overlay.dart lib/services/overlay_bus.dart test/instant_correct_test.dart`. Grep ulang `InstantCorrect|OverlayBus|showCorrectSheet|CorrectOverlay|overlayMain|correct_sheet|correct_overlay|overlay_bus|flutter_overlay_window` di seluruh repo (termasuk `docs/superpowers/specs` lama? spec lama BOLEH tetap menyebut historis — jangan ubah docs historis; hanya kode + test + workflow + pubspec harus nol).
- [ ] **Step 2: pubspec + apk.yml** — hapus baris dep; hapus seluruh blok `- run: |` overlay (dari `      - run: |` sebelum `python3 - <<'EOF'` SYSTEM_ALERT sampai `EOF` penutupnya, persis baris 172-194). Blok foreground (154-171) dan POST_NOTIFICATIONS (195+) JANGAN tersentuh.
- [ ] **Step 3: foreground_track + main** — hapus `pinNotice`/`clearNotice` (baris 122-149 incl doc). main.dart: hapus import `correct_overlay.dart` + fungsi `overlayMain` (baris 17, 20-30).
- [ ] **Step 4: auto_saved_notify.dart** — tambah import `shared_preferences`, `utils/strings.dart`, `utils/mask.dart` (amt), `flutter/foundation.dart`? (tak perlu). Tulis:
```dart
/// Baris isi notif tersimpan, murni. Transfer menyebut asal ke tujuan.
String savedBody({
  required String type,
  required double amount,
  required String app,
  String? appTo,
}) {
  final dir = type == 'in'
      ? tr('tx_in')
      : type == 'transfer'
          ? tr('tx_transfer')
          : tr('tx_out');
  if (type == 'transfer' && appTo != null && appTo.isNotEmpty && appTo != app) {
    return '$dir ${amt(amount)} • $app → $appTo';
  }
  return '$dir ${amt(amount)} • $app';
}
```
`_init` tambah handler tap:
```dart
await _plugin.initialize(
  settings,
  onDidReceiveNotificationResponse: (resp) async {
    final p = resp.payload ?? '';
    if (p.startsWith('open_detail:')) {
      try {
        final prefs = await SharedPreferences.getInstance();
        await prefs.setString('last_detail_tx', p.substring('open_detail:'.length));
      } catch (_) {}
    }
  },
);
```
Tambah:
```dart
static Future<void> showSaved({
  required String txId,
  required String type,
  required double amount,
  required String app,
  String? appTo,
}) async {
  try {
    await _init();
    try {
      await _plugin
          .resolvePlatformSpecificImplementation<
            AndroidFlutterLocalNotificationsPlugin
          >()
          ?.requestNotificationsPermission();
    } catch (_) {}
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('last_detail_tx', txId);
    final details = NotificationDetails(
      android: AndroidNotificationDetails(
        channelId, channelName,
        channelDescription: channelDesc,
        importance: Importance.high,
        priority: Priority.high,
        styleInformation: BigTextStyleInformation(
          savedBody(type: type, amount: amount, app: app, appTo: appTo)),
      ),
    );
    await _plugin.show(
      id: autoSavedId(txId),
      title: tr('nt_saved_title'),
      body: savedBody(type: type, amount: amount, app: app, appTo: appTo),
      notificationDetails: details,
      payload: 'open_detail:$txId',
    );
  } catch (err, st) {
    ErrorReporter.capture(err, st, context: 'auto_saved_notify');
  }
}
```
Fungsi `show()` lama DIHAPUS (tak ada pemanggil lain — verifikasi grep `AutoSavedNotify.show(` sebelum hapus; pemanggilnya hanya `instant_correct.offer`, jadi hapus).
- [ ] **Step 5: Test `test/auto_saved_notify_test.dart`** (TDD, perlu `tr()` → butuh locale? `tr` baca `localeCode` notifier + tabel, tanpa flutter binding? `tr` dari strings.dart memakai app_settings notifier (flutter foundation) — test paket flutter_test bisa pakai. `amt` memakai maskAmounts notifier. Tulis test dengan `maskAmounts.value = false` di setUp agar deterministik:
```dart
import 'package:flutter_test/flutter_test.dart';
import 'package:ssr_space/services/auto_saved_notify.dart';
import 'package:ssr_space/utils/mask.dart';

void main() {
  setUp(() => maskAmounts.value = false);
  test('masuk', () {
    expect(savedBody(type: 'in', amount: 50000, app: 'DANA'),
        'Masuk Rp50.000 • DANA');
  });
  test('keluar', () {
    expect(savedBody(type: 'out', amount: 10800, app: 'BRI'),
        'Keluar Rp10.800 • BRI');
  });
  test('transfer menyebut asal ke tujuan', () {
    expect(
      savedBody(type: 'transfer', amount: 17000, app: 'ISAKU', appTo: 'GoPay'),
      'Transfer Rp17.000 • ISAKU → GoPay');
  });
  test('transfer tanpa tujuan = satu baris biasa', () {
    expect(savedBody(type: 'transfer', amount: 17000, app: 'ISAKU'),
        'Transfer Rp17.000 • ISAKU');
  });
  test('id stabil per tx', () {
    expect(autoSavedId('abc'), autoSavedId('abc'));
  });
}
```
Format `rp` pastikan: cek `money.dart` (50.000 pakai titik). Sesuaikan ekspektasi dengan `rp()` nyata saat eksekusi.
- [ ] **Step 6: notif_track_service.dart** — hapus `import instant_correct.dart`. Blok merge (baris 431-452) ganti:
```dart
n.status = tr('st_saved');
if (txId != null) {
  final pair = await _tryAutoMerge(orgId, txId);
  if (pair != null) {
    final outLabel =
        matchWatchedApp(pair.outTx.sourcePackage ?? '') ?? n.appLabel ?? pkg;
    final inLabel =
        matchWatchedApp(pair.inTx.sourcePackage ?? '');
    await AutoSavedNotify.showSaved(
      txId: pair.outTx.id,
      type: 'transfer',
      amount: pair.amount,
      app: outLabel,
      appTo: inLabel,
    );
  } else {
    await AutoSavedNotify.showSaved(
      txId: txId,
      type: n.type!,
      amount: n.amount!,
      app: n.appLabel ?? pkg,
    );
  }
}
```
`forceSave` (baris 498-505) ganti:
```dart
if (txId != null) {
  await AutoSavedNotify.showSaved(
    txId: txId,
    type: type,
    amount: n.amount!,
    app: label,
  );
}
```
Tambah import `auto_saved_notify.dart`. Cek `pair.amount` eksis (dipakai baris 442 `amount: pair.amount` — ya).

---

### Task 6: UI sisa P3 + bersih string + detail read-only

**Files:**
- Create: `lib/widgets/tx_detail_sheet.dart`
- Modify: `lib/screens/shell/main_shell.dart` (lepas overlay/correct, `_checkPending` → `_checkDetail`)
- Modify: `lib/screens/lainnya/notif_settings_screen.dart` (hapus `_CorrectCard` + state + handler)
- Modify: `lib/screens/lainnya/other_screen.dart` (hapus toggle popup: `_OtherMeta.popup`, `_TrackingSection popup/onPopupChanged`, SwitchListTile ic_popup, import instant_correct bila ada)
- Modify: `lib/screens/lainnya/settings_search.dart` (hapus entri `ic_popup`)
- Modify: `lib/utils/strings.dart` (hapus kunci `ic_*`/`fg_correct` nol-rujukan; tambah `nt_saved_title`, `td_*`)

**Interfaces:**
- Consumes: `TransactionService().getById`, `SaasTransaction`, `WalletService().list` (nama dompet), `txWhenLabel`, `amt`.
- Produces: `showTxDetailSheet(context, tx, orgId)->Future<bool?>` (true = user pilih Lihat di Transaksi).

- [ ] **Step 1: `lib/widgets/tx_detail_sheet.dart`** (baru, ikuti gaya `_SheetHeader`/`LabeledSectionCard`, radius 28 seperti input sheet):
```dart
import 'package:flutter/material.dart';
import 'package:ssr_space/models/transaction.dart';
import 'package:ssr_space/services/wallet_service.dart';
import 'package:ssr_space/theme/app_theme.dart';
import 'package:ssr_space/utils/datetime.dart';
import 'package:ssr_space/utils/mask.dart';
import 'package:ssr_space/utils/strings.dart';

/// Detail transaksi read-only dari ketuk notif tersimpan.
/// Kembalikan true bila user pilih Lihat di Transaksi.
Future<bool?> showTxDetailSheet(
    BuildContext context, SaasTransaction tx, String orgId) {
  return showModalBottomSheet<bool>(
    context: context,
    useSafeArea: true,
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
    ),
    builder: (_) => _TxDetailSheet(tx: tx, orgId: orgId),
  );
}

class _TxDetailSheet extends StatelessWidget {
  final SaasTransaction tx;
  final String orgId;
  const _TxDetailSheet({required this.tx, required this.orgId});

  Future<Map<String, String>> _names() async {
    try {
      final ws = await WalletService().list(orgId);
      return {for (final w in ws) w.id: w.name};
    } catch (_) {
      return {};
    }
  }

  @override
  Widget build(BuildContext context) {
    final dir = tx.type == 'in'
        ? tr('tx_in')
        : tx.type == 'transfer'
            ? tr('tx_transfer')
            : tr('tx_out');
    return SafeArea(
      child: FutureBuilder<Map<String, String>>(
        future: _names(),
        builder: (context, snap) {
          final names = snap.data ?? {};
          final wallet = names[tx.walletId] ?? '…';
          final toWallet = tx.toWalletId == null
              ? null
              : (names[tx.toWalletId] ?? '…');
          return SingleChildScrollView(
            padding: const EdgeInsets.fromLTRB(
                SsrSpace.lg, SsrSpace.sm, SsrSpace.lg, SsrSpace.xl),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Text(tr('td_title'),
                    style: Theme.of(context).textTheme.titleMedium),
                const SizedBox(height: SsrSpace.sm),
                Text('$dir ${amt(tx.amount)}',
                    style: AppTheme.moneyLarge),
                const SizedBox(height: SsrSpace.md),
                _row(context, tr('td_wallet'), wallet),
                if (toWallet != null)
                  _row(context, tr('td_towallet'), toWallet),
                _row(context, tr('tx_f_cat'), (tx.category?.isEmpty ?? true)
                    ? '-' : tx.category!),
                _row(context, tr('tx_f_note'), (tx.note?.isEmpty ?? true)
                    ? '-' : tx.note!),
                _row(context, tr('tx_f_date'),
                    txWhenLabel(tx.date, tx.createdAt)),
                if (tx.code != null && tx.code!.isNotEmpty)
                  _row(context, 'TX', tx.code!),
                const SizedBox(height: SsrSpace.md),
                FilledButton(
                  onPressed: () => Navigator.pop(context, true),
                  child: Text(tr('td_view')),
                ),
                const SizedBox(height: SsrSpace.sm),
                TextButton(
                  onPressed: () => Navigator.pop(context, false),
                  child: Text(tr('td_close')),
                ),
              ],
            ),
          );
        },
      ),
    );
  }

  Widget _row(BuildContext context, String label, String value) {
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 110,
            child: Text(label, style: theme.textTheme.bodySmall),
          ),
          Expanded(child: Text(value, style: theme.textTheme.bodyMedium)),
        ],
      ),
    );
  }
}
```
Cek saat eksekusi: `AppTheme.moneyLarge` eksis (dipakai tx_input_sheet — ya). `SsrSpace.lg/sm/xl` eksis. Kunci `tx_f_cat/tx_f_note/tx_f_date` eksis (dipakai sheet — ya).
- [ ] **Step 2: main_shell.dart** — hapus import `instant_correct.dart`, `overlay_bus.dart`, `correct_sheet.dart`, `dart:io` (cek sisa pakai `Platform` — setelah hapus blok overlay tak ada lagi → hapus), tambah import `shared_preferences.dart` + `widgets/tx_detail_sheet.dart`. Hapus blok `if (Platform.isAndroid) OverlayBus...` (baris 48-52) + `OverlayBus.remove` di dispose. Ganti `_sheetOpen` → `_detailOpen`, `_checkPending` → `_checkDetail`:
```dart
Future<void> _checkDetail() async {
  if (_detailOpen || !_resumed || !mounted) return;
  try {
    final prefs = await SharedPreferences.getInstance();
    final txId = prefs.getString('last_detail_tx');
    if (txId == null || txId.isEmpty || !mounted) return;
    final orgId = await activeOrgId();
    if (orgId.isEmpty || !mounted) return;
    final tx = await TransactionService().getById(orgId, txId);
    await prefs.remove('last_detail_tx');
    if (!mounted) return;
    if (tx == null) return;
    _detailOpen = true;
    final go = await showTxDetailSheet(context, tx, orgId);
    _detailOpen = false;
    if (go == true && mounted) _select(1);
  } catch (_) {
    _detailOpen = false;
  }
}
```
Ganti 2 pemanggil `_checkPending` (postFrame + resume) → `_checkDetail`. `activeOrgId` + `TransactionService` import sudah ada (baris 11, 13 — ya).
- [ ] **Step 3: notif_settings_screen.dart** — hapus import overlay + instant_correct; field `correctPopup`, `overlayGranted`; blok `og` di `_load` (baris 63-67) + 2 baris setState (73-74); `_setCorrectPopup`, `_requestOverlay`, `_testOverlay`; widget `_CorrectCard` di build (baris 224-230); class `_CorrectCard` utuh (±baris 356-420, baca tepat saat eksekusi).
- [ ] **Step 4: other_screen.dart** — grep `popup|InstantCorrect|correct_popup|ic_popup` di file; hapus: field `_OtherMeta.popup`, isi `popup:` di `_meta()`, param `popup`/`onPopupChanged` di `_TrackingSection` + SwitchListTile (baris 708-714) + argumen di call-site + import instant_correct bila ada. Fungsi `_refreshMeta` tetap.
- [ ] **Step 5: settings_search.dart** — hapus entri `titleKey: 'ic_popup'` (baris ±62) + bila ada route/focus khusus koreksi.
- [ ] **Step 6: strings.dart** — tambah:
```dart
'nt_saved_title': {'id': 'Transaksi tercatat', 'en': 'Transaction saved'},
'td_title': {'id': 'Detail transaksi', 'en': 'Transaction details'},
'td_wallet': {'id': 'Dompet', 'en': 'Wallet'},
'td_towallet': {'id': 'Dompet tujuan', 'en': 'Destination wallet'},
'td_view': {'id': 'Lihat di Transaksi', 'en': 'View in Transactions'},
'td_close': {'id': 'Tutup', 'en': 'Close'},
```
Hapus kunci yang grep-nol-rujukan di `lib/`+`test/`: seluruh `ic_*` (termasuk `ic_overlay_t`), `fg_correct`. Nilai lama `ic_overlay_t` = 'Transaksi tercatat' diteruskan oleh `nt_saved_title` (judul sama, kunci baru yang jujur).

---

### Task 7: Rilis 2.5.0+47

**Files:**
- Modify: `pubspec.yaml` (`2.4.12+46` → `2.5.0+47`), `lib/utils/app_info.dart` ( samakan), `assets/changelog_id.md`, `AGENTS.md` + `AUDIT.md` §7 (lokal).

- [ ] **Step 1: Bump + changelog** — entri baru paling atas:
```markdown
## Yang baru di 2.5.0

1. Form catat terbuka lebih cepat (data dompet dari cache) dan ketik cepat tak lagi lag.
2. Navigasi bawah tinggal 4 tab; Profil dibuka lewat avatar kiri atas Beranda.
3. Tiap transaksi tersimpan memunculkan notifikasi sistem biasa (tanpa popup koreksi); ketuk untuk lihat detail, koreksi tetap lewat ketuk baris Transaksi.
4. Pengingat mingguan baru (default Minggu 20:00) di samping pengingat harian.
```
Sesuaikan `Versi terpasang: 2.5.0+47.`
- [ ] **Step 2: Commit + push + pantau**
```bash
git add -A && git commit -m "feat: optimalisasi 2.5.0 (sheet cepat, nav profil, notif murni, pengingat mingguan)" && git push origin main
gh run watch $(gh run list --limit 1 --json databaseId --jq '.[0].databaseId') --exit-status
```
- [ ] **Step 3: Bila hijau, unduh + rapikan**
```bash
gh run download <run-id> -n ssr-space-apk -D /sdcard/Download/SSR-SPACE/
```
Pilih varian `*-arm64.apk`, rename jelas `SSR-SPACE-2.5.0-47-optimalisasi-arm64.apk`, universal di-skip.
- [ ] **Step 4: Catat lokal AGENTS.md + AUDIT.md §7**, sebut nama file APK di jawaban akhir. Bila ubah SQL: tidak ada (tanpa migration).
