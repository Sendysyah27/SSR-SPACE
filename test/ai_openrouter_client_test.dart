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

  test('404 rotasi ke model berikut + lapor nama', () async {
    final seen = <String>[];
    final client = MockClient((req) async {
      final m = jsonDecode(req.body)['model'] as String;
      seen.add(m);
      if (seen.length == 1) {
        return http.Response('{"error":{"message":"No endpoints found"}}', 404);
      }
      return http.Response(_ok('Halo!'), 200);
    });
    String? used;
    final t = await orChatRaw(
      apiKey: 'k',
      prompt: 'Halo',
      client: client,
      onModel: (m) => used = m,
    );
    expect(t, 'Halo!');
    expect(seen.length, 2);
    expect(seen.first, aiOrModel);
    expect(used, seen.last);
  });

  test('404 semua model = server + cuplikan', () async {
    final client = MockClient(
        (_) async => http.Response('{"error":{"code":404}}', 404));
    try {
      await orChatRaw(apiKey: 'k', prompt: 'Halo', client: client);
      fail('harus lempar');
    } on AiFailure catch (e) {
      expect(e.code, 'server');
      expect(e.detail, contains('404'));
      expect(e.detail, contains('code'));
    }
  });
}
