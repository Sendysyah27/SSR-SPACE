import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:ssr_space/services/firebase_ai_factory.dart';
import 'package:ssr_space/services/firebase_ai_parser.dart';

String _ok(String text) => jsonEncode({
      'candidates': [
        {
          'content': {
            'parts': [
              {'text': text}
            ]
          }
        }
      ],
    });

void main() {
  test('200 valid jadi teks', () async {
    final client = MockClient((req) async {
      expect(req.headers['x-goog-api-key'], 'kunci-AQ');
      expect(req.url.path, contains('gemini-flash-latest'));
      return http.Response(_ok('Halo!'), 200);
    });
    final t = await restGenerate('Halo', apiKey: 'kunci-AQ', client: client);
    expect(t, 'Halo!');
  });

  test('400 jadi server + status + cuplikan', () async {
    final client = MockClient(
        (_) async => http.Response('{"error":{"message":"API key not valid"}}', 400));
    try {
      await restGenerate('Halo', apiKey: 'salah', client: client);
      fail('harus lempar');
    } on AiFailure catch (e) {
      expect(e.code, 'server');
      expect(e.detail, contains('400'));
      expect(e.detail, contains('not valid'));
    }
  });

  test('200 tanpa teks jadi empty (bukan null diam)', () async {
    final client = MockClient(
        (_) async => http.Response('{"candidates":[]}', 200));
    try {
      await restGenerate('Halo', apiKey: 'k', client: client);
      fail('harus lempar');
    } on AiFailure catch (e) {
      expect(e.code, 'empty');
    }
  });

  test('tanpa kunci = null tanpa request', () async {
    var n = 0;
    final client = MockClient((_) async {
      n++;
      return http.Response('', 500);
    });
    expect(await restGenerate('Halo', client: client), isNull);
    expect(n, 0);
  });

  test('503 lalu sukses di model cadangan + lapor nama', () async {
    final seen = <String>[];
    final client = MockClient((req) async {
      seen.add(req.url.pathSegments.last.split(':').first);
      if (seen.length == 1) {
        return http.Response('high demand, try later', 503);
      }
      return http.Response(_ok('Halo juga!'), 200);
    });
    String? used;
    final t = await restGenerate('Halo',
        apiKey: 'k', client: client, onModel: (m) => used = m);
    expect(t, 'Halo juga!');
    expect(seen, ['gemini-flash-latest', 'gemini-3.5-flash']);
    expect(used, 'gemini-3.5-flash');
  });

  test('sibuk di semua model = server', () async {
    final client = MockClient(
        (_) async => http.Response('overloaded', 503));
    try {
      await restGenerate('Halo', apiKey: 'k', client: client);
      fail('harus lempar');
    } on AiFailure catch (e) {
      expect(e.code, 'server');
      expect(e.detail, contains('semua model sibuk'));
    }
  });
}
