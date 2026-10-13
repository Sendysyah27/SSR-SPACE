import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:ssr_space/services/ai_zen_client.dart';
import 'package:ssr_space/services/firebase_ai_parser.dart';

void main() {
  test('SSE spark jadi teks + provider', () async {
    final client = MockClient((req) async {
      expect(req.url.toString(), zenResponsesEndpoint);
      expect(req.headers['Authorization'], startsWith('Bearer '));
      expect(req.headers['User-Agent'], contains('opencode/1.18.30'));
      expect(req.headers['x-opencode-client'], 'desktop');
      expect(req.headers['anthropic-version'], '2023-06-01');
      expect(req.headers['x-opencode-session'], startsWith('ses_'));
      expect(req.headers['x-opencode-request'], startsWith('msg_'));
      expect(jsonDecode(req.body)['model'], zenModelSpark);
      return http.Response(
        'data: {"choices":[{"delta":{"content":"Halo"}}]}\n'
        'data: {"choices":[{"delta":{"content":"!"}}]}\n'
        'data: [DONE]\n',
        200,
        headers: {'content-type': 'text/event-stream'},
      );
    });
    final r = await zenChatRaw(apiKey: 'k', prompt: 'Halo', client: client);
    expect(r.text, 'Halo!');
    expect(r.provider, zenModelSpark);
  });

  test('JSON biasa non-stream ikut terbaca', () async {
    final client = MockClient((_) async => http.Response(
        jsonEncode({
          'choices': [
            {
              'message': {'content': 'Hai'}
            }
          ],
        }),
        200,
        headers: {'content-type': 'application/json'}));
    final r =
        await zenChatRaw(apiKey: 'k', prompt: 'Halo', client: client);
    expect(r.text, 'Hai');
  });

  test('401 jadi denied + kunci kosong', () async {
    final client =
        MockClient((_) async => http.Response('no', 401));
    try {
      await zenChatRaw(apiKey: 'salah', prompt: 'Halo', client: client);
      fail('harus lempar');
    } on AiFailure catch (e) {
      expect(e.code, 'denied');
    }
    expect(await parseReceiptZen(ocrText: ' '), isNull);
  });

  test('anonim: tanpa header Authorization', () async {
    final client = MockClient((req) async {
      expect(req.headers.containsKey('Authorization'), isFalse);
      expect(req.headers['Accept'], 'text/event-stream');
      return http.Response(
        'data: {"choices":[{"delta":{"content":"Bebas!"}}]}\n'
        'data: [DONE]\n',
        200,
        headers: {'content-type': 'text/event-stream'},
      );
    });
    final r = await zenChatRaw(prompt: 'Halo', client: client);
    expect(r.text, 'Bebas!');
  });

  test('kunci ditolak -> coba anonim lalu sukses', () async {
    final authed = <bool?>[];
    final client = MockClient((req) async {
      final hasAuth = req.headers.containsKey('Authorization');
      authed.add(hasAuth);
      if (hasAuth) return http.Response('ditolak', 401);
      return http.Response(
        'data: {"choices":[{"delta":{"content":"OK"}}]}\n'
        'data: [DONE]\n',
        200,
        headers: {'content-type': 'text/event-stream'},
      );
    });
    final r =
        await zenChatRaw(apiKey: 'salah', prompt: 'Halo', client: client);
    expect(authed, [true, false]);
    expect(r.text, 'OK');
  });

  test('spark gagal -> cadangan chat', () async {
    final urls = <String>[];
    final client = MockClient((req) async {
      urls.add(req.url.toString());
      if (urls.length == 1) {
        return http.Response('sibuk', 500);
      }
      return http.Response(
          jsonEncode({
            'choices': [
              {
                'message': {'content': '{"total":9}'}
              }
            ],
          }),
          200,
          headers: {'content-type': 'application/json'});
    });
    final r = await zenChatRaw(apiKey: 'k', prompt: 'Halo', client: client);
    expect(urls, [zenResponsesEndpoint, zenChatEndpoint]);
    expect(r.provider, zenModelFree);
  });
}
