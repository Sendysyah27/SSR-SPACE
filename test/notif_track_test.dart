import 'package:flutter_test/flutter_test.dart';
import 'package:ssr_space/core/format/datetime.dart';
import 'package:ssr_space/core/saas/notif_parse.dart';
import 'package:ssr_space/core/saas/notif_track_service.dart';

void main() {
  test('dayLabel formats ymd', () {
    expect(dayLabel('2026-09-24'), '24 Sep 2026');
    expect(dayLabel('2026-01-05'), '05 Jan 2026');
    expect(dayLabel(null), '-');
    expect(dayLabel('bad'), '-');
  });

  test('txTime from iso', () {
    expect(txTime(''), '');
    expect(txTime(null), '');
    final t = txTime('2026-09-24T07:05:00+07:00');
    expect(t.length, 5);
    expect(ymd(DateTime.parse('2026-09-24T07:05:00+07:00')), '2026-09-24');
  });

  test('CapturedNotif parses amount and type', () {
    final n = CapturedNotif(
      'id.dana',
      'DANA',
      'DANA',
      'Pembayaran berhasil Rp75.000',
      at: DateTime(2026, 9, 24, 12, 0),
    );
    expect(n.amount, 75000);
    expect(n.type, 'out');
    expect(ymd(n.at), '2026-09-24');
    expect(matchWatchedApp(n.package), 'DANA');
  });

  test('wallet pref keys do not clash with toggle keys', () {
    expect(NotifTrack.walletPrefKey('DANA'), 'track_wallet_DANA');
    expect(NotifTrack.catPrefKey('DANA'), 'track_cat_DANA');
  });
}
