import 'package:flutter_test/flutter_test.dart';
import 'package:ssr_space/services/transaction_service.dart';
import 'package:ssr_space/services/tx_input_logic.dart';

void main() {
  test('numpadAppend digit biasa menempel', () {
    expect(numpadAppend('', '5'), '5');
    expect(numpadAppend('12', '3'), '123');
  });

  test('numpadAppend nol tunggal tak menumpuk', () {
    expect(numpadAppend('', '0'), '0');
    expect(numpadAppend('0', '0'), '0');
    expect(numpadAppend('0', '5'), '5');
  });

  test("numpadAppend '000' dari kosong/nol tetap '0'", () {
    expect(numpadAppend('', '000'), '0');
    expect(numpadAppend('0', '000'), '0');
  });

  test("numpadAppend '000' menempel tiga nol", () {
    expect(numpadAppend('5', '000'), '5000');
    expect(numpadAppend('12', '000'), '12000');
  });

  test('numpadAppend kunci asing diabaikan', () {
    expect(numpadAppend('12', 'a'), '12');
    expect(numpadAppend('12', ''), '12');
    expect(numpadAppend('12', '12'), '12');
    expect(numpadAppend('12', '.'), '12');
    expect(numpadAppend('12', '-'), '12');
  });

  test('numpadAppend patuh maxLen', () {
    expect(numpadAppend('12345', '6', maxLen: 5), '12345');
    expect(numpadAppend('1234', '000', maxLen: 5), '12340');
    expect(numpadAppend('12345', '000', maxLen: 5), '12345');
  });

  test('numpadBackspace potong 1 digit', () {
    expect(numpadBackspace('123'), '12');
    expect(numpadBackspace('5'), '');
  });

  test('numpadBackspace aman saat kosong', () {
    expect(numpadBackspace(''), '');
  });

  test('majorFromDigits IDR langsung, kosong jadi 0', () {
    expect(majorFromDigits('25000'), 25000);
    expect(majorFromDigits(''), 0);
  });

  test('majorFromDigits USD dec:2 eksak', () {
    expect(majorFromDigits('1050', dec: 2), 10.5);
  });

  test('digitsFromMajor dua arah (IDR + USD) dan nol jadi kosong', () {
    expect(digitsFromMajor(25000), '25000');
    expect(digitsFromMajor(10.5, dec: 2), '1050');
    expect(digitsFromMajor(0), '');
  });

  test('txYmd padding nol', () {
    expect(txYmd(DateTime(2026, 1, 5)), '2026-01-05');
    expect(txYmd(DateTime(2026, 12, 26)), '2026-12-26');
  });

  test('txWhen tanpa jam -> createdAt null', () {
    final w = txWhen(DateTime(2026, 9, 26));
    expect(w.date, '2026-09-26');
    expect(w.createdAt, isNull);
  });

  test('txWhen tanpa jam parsial (satu sisi null) -> createdAt null', () {
    expect(txWhen(DateTime(2026, 9, 26), hour: 8).createdAt, isNull);
    expect(txWhen(DateTime(2026, 9, 26), minute: 5).createdAt, isNull);
  });

  test('txWhen dengan jam -> ISO presisi menit', () {
    final w = txWhen(DateTime(2026, 9, 26), hour: 8, minute: 5);
    expect(w.date, '2026-09-26');
    expect(w.createdAt, '2026-09-26T08:05:00');
  });

  test('txCreatedAtTime roundtrip hasil txWhen', () {
    final w = txWhen(DateTime(2026, 9, 26), hour: 18, minute: 34);
    final t = txCreatedAtTime(w.createdAt);
    expect(t?.hour, 18);
    expect(t?.minute, 34);
  });

  test('txCreatedAtTime null/kosong/sampah -> null', () {
    expect(txCreatedAtTime(null), isNull);
    expect(txCreatedAtTime(''), isNull);
    expect(txCreatedAtTime('sampah'), isNull);
  });

  test("txInsertPayload createdAt null -> key 'created_at' TIDAK ada", () {
    final p = txInsertPayload(
      orgId: 'org-1',
      type: 'in',
      amount: 1000,
      date: '2026-09-26',
    );
    expect(p.containsKey('created_at'), isFalse);
  });

  test("txInsertPayload createdAt terisi -> ada dan nilainya benar", () {
    final p = txInsertPayload(
      orgId: 'org-1',
      type: 'out',
      amount: 1000,
      date: '2026-09-26',
      createdAt: '2026-09-26T18:34:00',
    );
    expect(p['created_at'], '2026-09-26T18:34:00');
  });

  test('txInsertPayload date default pakai now', () {
    final p = txInsertPayload(
      orgId: 'org-1',
      type: 'in',
      amount: 1000,
      date: null,
      now: DateTime(2026, 9, 26),
    );
    expect(p['date'], '2026-09-26');
  });

  test("txUpdatePayload createdAt null -> key tak ada; terisi -> ada", () {
    final kosong = txUpdatePayload(type: 'in', amount: 1);
    expect(kosong.containsKey('created_at'), isFalse);
    final isi = txUpdatePayload(
      type: 'in',
      amount: 1,
      createdAt: '2026-09-26T18:34:00',
    );
    expect(isi['created_at'], '2026-09-26T18:34:00');
  });
}
