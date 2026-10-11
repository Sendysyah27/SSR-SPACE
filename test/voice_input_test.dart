import 'package:flutter_test/flutter_test.dart';
import 'package:ssr_space/services/quick_input_parse.dart';

void main() {
  test('normalisasi ucapan -> teks ketik-cepat', () {
    expect(normalizeSpoken('Makan Siang 25 Ribu'), 'makan siang 25 ribu');
    expect(normalizeSpoken('  gaji   5 JUTA rupiah  '), 'gaji 5 juta');
    expect(normalizeSpoken('Transfer 100RB DANA ke BCA'), 'transfer 100rb dana ke bca');
  });

  test('ucapan "makan siang 25 ribu" terparse penuh', () {
    final q = parseQuickInput(
      normalizeSpoken('Makan Siang 25 Ribu'),
      categories: const ['Makanan'],
      wallets: const [],
    )!;
    expect(q.amount, 25000);
    expect(q.type, 'out');
  });

  test('kosong tetap kosong', () {
    expect(normalizeSpoken('   '), '');
  });

  test('kode error recognizer -> kunci pesan', () {
    expect(voiceErrorKey('error_no_match'), 'vc_hear');
    expect(voiceErrorKey('error_speech_timeout'), 'vc_hear');
    expect(voiceErrorKey('error_no_sound'), 'vc_hear');
    expect(voiceErrorKey('error_permission'), 'vc_denied');
    expect(voiceErrorKey('error_insufficient_permissions'), 'vc_denied');
    expect(voiceErrorKey('error_busy'), 'vc_error');
    expect(voiceErrorKey('error_client'), 'vc_error');
    expect(voiceErrorKey(''), 'vc_error');
  });
}
