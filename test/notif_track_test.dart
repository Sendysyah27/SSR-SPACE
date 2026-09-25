import 'package:flutter_test/flutter_test.dart';
import 'package:ssr_space/utils/datetime.dart';
import 'package:ssr_space/services/notif_parse.dart';
import 'package:ssr_space/services/notif_track_service.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

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

  test('scanErrorStatus jujur saat service mati', () {
    expect(scanErrorStatus('ServiceUnavailable'), contains('tidak nyambung'));
    expect(
      scanErrorStatus('ServiceUnavailable'),
      isNot(contains('tidak ada notif')),
    );
    expect(scanErrorStatus('REBIND_ERROR'), contains('Gagal sambung'));
    expect(scanErrorStatus('RECONNECT_ERROR'), contains('Gagal sambung'));
    expect(scanErrorStatus('custom', message: 'oops'), contains('oops'));
    expect(scanErrorStatus('custom'), contains('custom'));
  });

  test('eventTime pakai postTime plugin bila valid', () {
    final ms = DateTime(2026, 9, 24, 19, 5).millisecondsSinceEpoch;
    final t = eventTime(ms);
    expect(ymd(t), '2026-09-24');
    expect(t.hour, 19);
    expect(t.minute, 5);

    final fb = DateTime(2026, 1, 1, 8, 0);
    expect(eventTime(0, fallback: fb), fb);
    expect(eventTime(-1, fallback: fb), fb);
    expect(eventTime(0).year, DateTime.now().year);
  });

  test('connectionLabel bedakan izin vs service', () {
    expect(
      connectionLabel(permissionGranted: false, serviceConnected: false),
      contains('Izin'),
    );
    expect(
      connectionLabel(permissionGranted: true, serviceConnected: false),
      contains('terputus'),
    );
    expect(
      connectionLabel(permissionGranted: true, serviceConnected: true),
      contains('terhubung'),
    );
  });

  test('saveErrorStatus: RATE_LIMITED jadi Dibatasi', () {
    const err = PostgrestException(message: 'RATE_LIMITED', code: 'P0001');
    expect(saveErrorStatus(err), 'Dibatasi, terlalu banyak. Coba lagi.');
    expect(saveErrorStatus(err), isNot(contains('—')));
  });

  test('saveErrorStatus: duplikat 23505 Sudah pernah dicatat', () {
    const err = PostgrestException(
      message: 'duplicate key value violates unique constraint',
      code: '23505',
    );
    expect(saveErrorStatus(err), 'Sudah pernah dicatat');
  });

  test('saveErrorStatus: error lain Gagal simpan dengan code', () {
    const err = PostgrestException(message: 'boom', code: '42501');
    expect(saveErrorStatus(err), 'Gagal simpan: 42501');
  });
}
