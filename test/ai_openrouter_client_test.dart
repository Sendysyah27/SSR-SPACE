import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:ssr_space/services/ai_openrouter_client.dart';
import 'package:ssr_space/services/firebase_ai_parser.dart';

String _ok(String inner) => jsonEncode({
      'choices': [
        {
          'message': {'content': inner}
        }
      ],
    });

void main() {
  test('sukses OR + header referer/title', () async {
    final client = MockClient((req) async {
      expect(req.headers['Authorization'], startsWith('Bearer '));
      expect(req.headers['HTTP-Referer'], isNotNull);
      expect(req.headers['X-Title'], isNotNull);
      expect(jsonDecode(req.body)['model'], aiOrModel);
      return http.Response(_ok('{"total":7000}'), 200);
    });
    final d = await parseReceiptOr(
      apiKey: 'sk-or-x',
      ocrText: 'TOKO\nTOTAL 7000',
      client: client,
    );
    expect(d, isNotNull);
    expect(d!.total, 7000);
  });

  test('401 jadi denied + 429 jadi quota', () async {
    var denied = false;
    try {
      await parseReceiptOr(
        apiKey: 'salah',
        ocrText: 'TOTAL 1',
        client: MockClient((_) async => http.Response('no', 401)),
      );
    } on AiFailure catch (e) {
      denied = e.code == 'denied' && (e.detail ?? '').contains('[OpenRouter]');
    }
    expect(denied, isTrue);
    var quota = false;
    try {
      await parseReceiptOr(
        apiKey: 'k',
        ocrText: 'TOTAL 1',
        client: MockClient(
            (_) async => http.Response('rate limited retry in 3m', 429)),
      );
    } on AiFailure catch (e) {
      quota = e.code == 'quota';
    }
    expect(quota, isTrue);
  });

  test('kunci/ocr kosong = null', () async {
    expect(await parseReceiptOr(apiKey: ' ', ocrText: 'x'), isNull);
    expect(await parseReceiptOr(apiKey: 'k', ocrText: ' '), isNull);
  });
}
