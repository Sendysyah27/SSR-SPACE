import 'package:flutter_test/flutter_test.dart';
import 'package:ssr_space/services/notif_parse.dart';

void main() {
  test('parse nominal Rp pertama', () {
    expect(parseNotifAmount('Transaksi sebesar Rp459.999 berhasil'), 459999);
    expect(parseNotifAmount('Dana masuk Rp2.800.000 dari Budi'), 2800000);
    expect(parseNotifAmount('Bayar Rp10.800,00 via QRIS'), 10800);
    expect(parseNotifAmount('Halo apa kabar'), null);
  });

  test('parse nominal format IDR (gaya barat koma ribuan)', () {
    expect(
      parseNotifAmount('Pengeluaran sebesar IDR 88,655.00 di kategori'),
      88655,
    );
    expect(
      parseNotifAmount('Pengeluaran sebesar IDR88,655.00 di kat...'),
      88655,
    );
    expect(parseNotifAmount('IDR 1,234,567 transfer masuk'), 1234567);
    expect(parseNotifAmount('IDR 88,655 pengeluaran'), 88655);
  });

  test('parse nominal abaikan titik/koma akhir kalimat', () {
    expect(
      parseNotifAmount('Berhasil Sebesar Rp. 17.000. Ref T99920260926'),
      17000,
    );
    expect(parseNotifAmount('Saldo Rp10.000, terima kasih.'), 10000);
    expect(parseNotifAmount('Diskon Rp15 ribu'), 15);
  });

  test('classify in vs out vs ambiguous', () {
    expect(classifyNotif('Dana masuk Rp100 ke DANA'), 'in');
    expect(classifyNotif('Pembayaran berhasil Rp50 di merchant'), 'out');
    expect(classifyNotif('Info promo akhir bulan'), null);
    expect(classifyNotif('Dana masuk lalu berhasil ditransfer'), null);
  });

  test('classify frasa asli bank: top up, pengeluaran, menerima', () {
    expect(classifyNotif('Berhasil top up saldo Rp88.655 d...'), 'in');
    expect(classifyNotif('Pengeluaran sebesar IDR 88,655.00 di kat...'), 'out');
    expect(
      classifyNotif('Pengeluaran sebesar Rp88.655,00 di kategori Belanja'),
      'out',
    );
    expect(classifyNotif('Anda menerima transfer Rp100.000'), 'in');
    expect(classifyNotif('Transfer Rp50.000 berhasil'), 'out');
    expect(classifyNotif('Pembayaran sebesar Rp10.000 berhasil'), 'out');
  });

  test('classify format ISAKU cash in', () {
    expect(
      classifyNotif(
        'Transaksi Cash In Transaksi Isi Ulang Di PT INDOMARCO PRISMATAMA '
        'tgl 26-09-2026 01:32 Berhasil Sebesar Rp. 17.000. Ref T999',
      ),
      'in',
    );
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
    // App SeaBank di Play Store memakai namespace lama BKE.
    expect(matchWatchedApp('id.co.bankbkemobile.digitalbank'), 'SeaBank');
    expect(matchWatchedApp('id.co.bankbke'), 'SeaBank');
    // MyHana (KEB Hana) pakai co.id.myhana.app.
    expect(matchWatchedApp('co.id.myhana.app'), 'KEB Hana');
    expect(matchWatchedApp('id.co.kebhana'), 'KEB Hana');
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
