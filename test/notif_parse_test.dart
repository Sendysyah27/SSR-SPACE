import 'package:flutter_test/flutter_test.dart';
import 'package:ssr_space/core/saas/notif_parse.dart';

void main() {
  test('parse nominal Rp pertama', () {
    expect(parseNotifAmount('Transaksi sebesar Rp459.999 berhasil'), 459999);
    expect(parseNotifAmount('Dana masuk Rp2.800.000 dari Budi'), 2800000);
    expect(parseNotifAmount('Bayar Rp10.800,00 via QRIS'), 10800);
    expect(parseNotifAmount('Halo apa kabar'), null);
  });

  test('classify in vs out vs ambiguous', () {
    expect(classifyNotif('Dana masuk Rp100 ke DANA'), 'in');
    expect(classifyNotif('Pembayaran berhasil Rp50 di merchant'), 'out');
    expect(classifyNotif('Info promo akhir bulan'), null);
    expect(classifyNotif('Dana masuk lalu berhasil ditransfer'), null);
  });

  test('hash stable same day, differs across day', () {
    final d1 = DateTime(2026, 9, 24, 10, 0);
    final d2 = DateTime(2026, 9, 25, 10, 0);
    expect(
      notifHash('a', 'b', 'c', at: d1),
      notifHash('a', 'b', 'c', at: DateTime(2026, 9, 24, 23, 59)),
    );
    expect(
      notifHash('a', 'b', 'c', at: d1) == notifHash('a', 'b', 'c', at: d2),
      false,
    );
  });

  test('match watched app by exact package prefix', () {
    expect(matchWatchedApp('com.bca.mybca.omni.android'), 'myBCA');
    expect(matchWatchedApp('com.gojek.app'), 'GoPay');
    expect(matchWatchedApp('com.isaku.app'), 'ISAKU');
    expect(matchWatchedApp('id.co.bankbkemobile.digitalbank'), 'KEB Hana');
    expect(matchWatchedApp('id.dana.debug'), 'DANA');
    expect(matchWatchedApp('com.game.asing'), null);
    expect(matchWatchedApp('com.example.danagame'), null);
    expect(matchWatchedApp('com.bluetooth.something'), null);
    expect(matchWatchedApp('org.blurnotbank'), null);
    expect(matchWatchedApp(''), null);
  });

  test('ymd formats local date', () {
    expect(ymd(DateTime(2026, 9, 4)), '2026-09-04');
    expect(ymd(DateTime(2026, 12, 31)), '2026-12-31');
  });
}
