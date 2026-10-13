import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:ssr_space/services/ai_zen_client.dart';
import 'package:ssr_space/services/firebase_ai_parser.dart';

void main() {
  test('sukses proxy jadi draft + provider', () async {
    final client = MockClient((req) async {
      expect(req.url.toString(), zenProxyDefault);
      final b = jsonDecode(req.body) as Map;
      expect(b['api_key'], 'kunci');
      expect(b['ocr_text'], contains('TOTAL'));
      return http.Response(
          jsonEncode({
            'ok': true,
            'data': {'merchant': 'TOKO', 'total': 5000},
            'provider': 'muse-spark-1.3',
          }),
          200);
    });
    final d = await parseReceiptZen(
      apiKey: 'kunci',
      ocrText: 'TOKO\nTOTAL 5000',
      client: client,
    );
    expect(d, isNotNull);
    expect(d!.merchant, 'TOKO');
    expect(d.total, 5000);
  });

  test('chat mentah lapor provider', () async {
    final client = MockClient((_) async => http.Response(
        jsonEncode(
            {'ok': true, 'data': 'Halo juga!', 'provider': 'muse-spark'}),
        200));
    final r = await zenChatRaw(
        apiKey: 'k', prompt: 'Halo', client: client);
    expect(r.text, 'Halo juga!');
    expect(r.provider, 'muse-spark');
  });

  test('custom URL dipakai', () async {
    var host = '';
    final client = MockClient((req) async {
      host = req.url.host;
      return http.Response(
          jsonEncode({'ok': true, 'data': '{"total":1}'}), 200);
    });
    await zenChatRaw(
      apiKey: 'k',
      prompt: 'Halo',
      url: 'http://contoh:9999/x',
      client: client,
    );
    expect(host, 'contoh');
  });

  test('ok:false kuota + kunci/ocr kosong', () async {
    final client = MockClient((_) async => http.Response(
        jsonEncode(
            {'ok': false, 'error': 'quota exceeded retry in 2h'}),
        200));
    try {
      await zenChatRaw(apiKey: 'k', prompt: 'Halo', client: client);
      fail('harus lempar');
    } on AiFailure catch (e) {
      expect(e.code, 'quota');
    }
    expect(await parseReceiptZen(apiKey: ' ', ocrText: 'x'), isNull);
  });
}
