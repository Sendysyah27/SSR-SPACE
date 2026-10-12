import 'package:flutter/foundation.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:ssr_space/services/debt_store.dart';
import 'package:ssr_space/services/due_reminder.dart';
import 'package:ssr_space/services/error_reporter.dart';
import 'package:ssr_space/services/recurring_bills.dart';
import 'package:ssr_space/services/reminder_schedule.dart';
import 'package:ssr_space/utils/mask.dart';
import 'package:ssr_space/utils/strings.dart';
import 'package:timezone/data/latest_all.dart' as tzdata;
import 'package:timezone/timezone.dart' as tz;

// Pengingat jatuh tempo: utang/piutang H-3 & H-1 + tagihan aktif H-3 & H-1.
// Dijadwalkan ulang tiap app-start (pola reminder) + tiap simpan/bayar/
// hapus utang & tagihan. ID stabil per catatan (batalkan yang basi via
// prefs). Silent, tanpa izin baru (izin notif ikut toggle pengingat;
// exact alarm ikut pola reminder). Tak melempar.
class DueNotify {
  static const String channelId = 'ssr_due';
  static const String channelName = 'Jatuh tempo';
  static const String channelDesc =
      'Pengingat H-3 dan H-1 utang, piutang, dan tagihan.';

  static const int _debtBase = 71000;
  static const int _billBase = 72000;
  static const int _slotSpan = 1000;
  static const String _kIds = 'due_notif_ids';
  static const int _hour = 9;

  static final FlutterLocalNotificationsPlugin _plugin =
      FlutterLocalNotificationsPlugin();
  static bool _inited = false;

  static Future<void> _init() async {
    if (_inited) return;
    tzdata.initializeTimeZones();
    try {
      tz.setLocalLocation(
        tz.getLocation(
          zoneForOffsetHours(DateTime.now().timeZoneOffset.inHours),
        ),
      );
    } catch (e) {
      debugPrint('due zona gagal: $e');
    }
    const android = AndroidInitializationSettings('@mipmap/ic_launcher');
    const settings = InitializationSettings(android: android);
    await _plugin.initialize(settings: settings);
    const channel = AndroidNotificationChannel(
      channelId,
      channelName,
      description: channelDesc,
      importance: Importance.high,
    );
    await _plugin
        .resolvePlatformSpecificImplementation<
          AndroidFlutterLocalNotificationsPlugin
        >()
        ?.createNotificationChannel(channel);
    _inited = true;
  }

  static int _idFor(String key, int base) =>
      base + (key.hashCode % _slotSpan).abs();

  static tz.TZDateTime _at9(String ymd) {
    final y = int.parse(ymd.substring(0, 4));
    final m = int.parse(ymd.substring(5, 7));
    final d = int.parse(ymd.substring(8, 10));
    return tz.TZDateTime(tz.local, y, m, d, _hour);
  }

  static String _title(DueNotif n) {
    if (n.kind == 'bill') return tr('due_bill_t');
    if (n.kind == 'recv') return tr('due_recv_t');
    return tr('due_debt_t');
  }

  static String _body(DueNotif n) {
    final left = n.date;
    if (n.kind == 'bill') {
      return tr('due_bill_b')
          .replaceFirst('{n}', n.name)
          .replaceFirst('{m}', amt(n.amount))
          .replaceFirst('{d}', left);
    }
    if (n.kind == 'recv') {
      return tr('due_recv_b')
          .replaceFirst('{n}', n.name)
          .replaceFirst('{m}', amt(n.amount))
          .replaceFirst('{d}', left);
    }
    return tr('due_debt_b')
        .replaceFirst('{n}', n.name)
        .replaceFirst('{m}', amt(n.amount))
        .replaceFirst('{d}', left);
  }

  /// Hitung ulang + jadwalkan. Panggil saat start + tiap mutasi.
  static Future<void> reschedule() async {
    try {
      await _init();
      final prefs = await SharedPreferences.getInstance();
      final debts = await loadDebts();
      final bills = await loadBills();
      final now = DateTime.now();
      final plan = notifPlan(debts: debts, bills: _toInputs(bills), today: now);
      final oldIds = prefs.getStringList(_kIds) ?? [];
      final wanted = <int, DueNotif>{};
      for (final n in plan) {
        final base = n.kind == 'bill' ? _billBase : _debtBase;
        wanted[_idFor(n.key, base)] = n;
      }
      for (final raw in oldIds) {
        final id = int.tryParse(raw);
        if (id == null || !wanted.containsKey(id)) {
          try {
            if (id != null) await _plugin.cancel(id);
          } catch (_) {}
        }
      }
      const details = NotificationDetails(
        android: AndroidNotificationDetails(
          channelId,
          channelName,
          channelDescription: channelDesc,
          importance: Importance.high,
          priority: Priority.high,
        ),
      );
      for (final e in wanted.entries) {
        try {
          await _plugin.zonedSchedule(
            id: e.key,
            title: _title(e.value),
            body: _body(e.value),
            scheduledDate: _at9(e.value.date),
            notificationDetails: details,
            androidScheduleMode: AndroidScheduleMode.exactAllowWhileIdle,
          );
        } catch (_) {}
      }
      await prefs.setStringList(
        _kIds,
        [for (final id in wanted.keys) '$id'],
      );
    } catch (err, st) {
      ErrorReporter.capture(err, st, context: 'due_reschedule');
    }
  }

  static List<DueBillInput> _toInputs(List<RecurringBill> bills) => [
        for (final b in bills)
          DueBillInput(
            id: b.id,
            label: b.label,
            amount: b.amount,
            nextDue: b.nextDue,
            active: b.active,
          ),
      ];
}
