import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:ssr_space/services/nfc_emoney.dart';
import 'package:ssr_space/services/nfc_emoney_logic.dart';

const _hist = '[{"amount":"9000","balance":"100","counter":"15","date":"2026-8-28 20:24:16","no":"1","tid":"72100851","type":"2001"},{"amount":"100000","balance":"151000","counter":"6","date":"2019-8-4 8:44:40","no":"8","tid":"43061933","type":"1"},{"amount":"x","balance":"0","counter":"99","date":"bad","no":"9","tid":"","type":"2001"}]';

void main() {
  test('saldo valid vs gagal', () {
    expect(parseNfcBalance('100'), 100);
    expect(parseNfcBalance('  45500 '), 45500);
    expect(parseNfcBalance(''), isNull);
    expect(parseNfcBalance('abc'), isNull);
  });

  test('histori sort counter desc + peta tipe + baris rusak dibuang', () {
    final out = parseNfcHistory(_hist);
    expect(out.length, 2);
    expect(out[0].counter, 15);
    expect(out[0].dir, NfcEntryDir.debit);
    expect(out[0].balance, 100);
    expect(out[1].counter, 6);
    expect(out[1].dir, NfcEntryDir.credit);
    expect(parseNfcHistory('bukan json'), isEmpty);
    expect(parseNfcHistory('[]'), isEmpty);
  });

  test('label bank + masker nomor', () {
    expect(nfcBankLabel(' mandiri '), 'MANDIRI');
    expect(nfcBankLabel(''), 'UNKNOWN');
    expect(maskCardNumber('6032986072713976'), '6032 •••• 3976');
    expect(maskCardNumber('123'), '123');
    expect(maskCardNumber(''), '-');
  });

  test('NfcCard round-trip + tolak uid kosong', () {
    final c = NfcCard(
      uid: 'CFEF1CCD',
      bank: 'MANDIRI',
      last4: '3976',
      label: 'Mandiri •• 3976',
      walletId: null,
      addedAt: '2026-09-28T00:00:00.000',
    );
    final back = NfcCard.tryParse(c.toJson())!;
    expect(back.uid, 'CFEF1CCD');
    expect(back.walletId, isNull);
    expect(NfcCard.tryParse({'uid': ''}), isNull);
    expect(NfcCard.tryParse('x'), isNull);
  });

  test('NfcCheck tolak bentuk rusak', () {
    expect(
      NfcCheck.tryParse({
        'uid': 'CFEF1CCD',
        'bank': 'MANDIRI',
        'balance': 100,
        'at': '2026-09-28T00:00:00.000',
      })!.balance,
      100,
    );
    expect(NfcCheck.tryParse({'uid': 'A'}), isNull);
  });

  test('capList memotong di max', () {
    expect(capList([1, 2, 3], 20), [1, 2, 3]);
    expect(capList([for (var i = 0; i < 60; i++) i], 50).length, 50);
  });

  test('histori toleran angka numerik + string', () {
    final out = parseNfcHistory('[{"amount":9000,"balance":100,"counter":15,"date":"d","tid":"t","type":"2001"}]');
    expect(out.length, 1);
    expect(out.first.amount, 9000);
    expect(
      NfcCheck.tryParse({'uid': 'U', 'bank': 'B', 'balance': '250', 'at': '2026-09-28T00:00:00.000'})!.balance,
      250,
    );
  });

  test('prefs kartu + cek round-trip dan cap', () async {
    SharedPreferences.setMockInitialValues({});
    await saveNfcCards([
      const NfcCard(
        uid: 'U1',
        bank: 'MANDIRI',
        last4: '3976',
        label: 'Mandiri •• 3976',
        walletId: null,
        addedAt: '2026-09-28T00:00:00.000',
      ),
    ]);
    final cards = await loadNfcCards();
    expect(cards.length, 1);
    expect(cards.first.last4, '3976');
    await addNfcCheck(const NfcCheck(
      uid: 'U1',
      bank: 'MANDIRI',
      balance: 100,
      at: '2026-09-28T00:00:00.000',
    ));
    final checks = await loadNfcChecks();
    expect(checks.length, 1);
    expect(checks.first.balance, 100);
  });
}
