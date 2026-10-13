import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:ssr_space/services/firebase_ai_parser.dart';

void main() {
  test('sukses JSON jadi draft', () async {
    var calls = 0;
    final d = await parseReceiptFirebase(
      ocrText: 'TOKO MAKMUR\nTOTAL 25000',
      generate: (prompt) async {
        calls++;
        expect(prompt, contains('TOKO MAKMUR'));
        return '{"merchant":"TOKO MAKMUR","total":25000}';
      },
    );
    expect(calls, 1);
    expect(d, isNotNull);
    expect(d!.merchant, 'TOKO MAKMUR');
    expect(d.total, 25000);
  });

  test('ocr kosong tidak panggil model', () async {
    var calls = 0;
    final d = await parseReceiptFirebase(
      ocrText: '   ',
      generate: (prompt) async {
        calls++;
        return '{}';
      },
    );
    expect(d, isNull);
    expect(calls, 0);
  });

  test('timeout dua kali jadi AiFailure timeout', () async {
    var calls = 0;
    try {
      await parseReceiptFirebase(
        ocrText: 'TOTAL 10000',
        generate: (prompt) async {
          calls++;
          throw TimeoutException('lelet');
        },
      );
      fail('harus lempar');
    } on AiFailure catch (e) {
      expect(e.code, 'timeout');
      expect(e.detail, contains('lelet'));
    }
    expect(calls, 2);
  });

  test('AiDenied jadi AiFailure denied tanpa retry', () async {
    var calls = 0;
    try {
      await parseReceiptFirebase(
        ocrText: 'TOTAL 10000',
        generate: (prompt) async {
          calls++;
          throw const AiDenied();
        },
      );
      fail('harus lempar');
    } on AiFailure catch (e) {
      expect(e.code, 'denied');
    }
    expect(calls, 1);
  });

  test('teks sampah jadi null (bukan throw)', () async {
    final d = await parseReceiptFirebase(
      ocrText: 'TOTAL 10000',
      generate: (prompt) async => 'bukan json sama sekali {{{',
    );
    expect(d, isNull);
  });

  test('gagal sekali lalu sukses (retry)', () async {
    var calls = 0;
    final d = await parseReceiptFirebase(
      ocrText: 'TOTAL 5000',
      generate: (prompt) async {
        calls++;
        if (calls == 1) throw Exception('jaringan putus');
        return '{"total":5000}';
      },
    );
    expect(calls, 2);
    expect(d, isNotNull);
    expect(d!.total, 5000);
  });

  test('respons kosong jadi AiFailure empty', () async {
    try {
      await parseReceiptFirebase(
        ocrText: 'TOTAL 10000',
        generate: (prompt) async => '   ',
      );
      fail('harus lempar');
    } on AiFailure catch (e) {
      expect(e.code, 'empty');
    }
  });

  test('denied tanpa sesi = minta login, dengan sesi = gagal umum', () {
    expect(aiFailureTrKey('denied', loggedIn: false), 'ai_need_google');
    expect(aiFailureTrKey('denied', loggedIn: true), 'ai_fail');
    expect(aiFailureTrKey('timeout', loggedIn: true), 'ai_fail');
  });

  test('detail error asli terbawa (timeout/network/denied)', () async {
    try {
      await parseReceiptFirebase(
        ocrText: 'TOTAL 100',
        generate: (prompt) async => throw Exception('jaringan putus'),
      );
      fail('harus lempar');
    } on AiFailure catch (e) {
      expect(e.code, 'network');
      expect(e.detail, contains('putus'));
    }
    try {
      await parseReceiptFirebase(
        ocrText: 'TOTAL 100',
        generate: (prompt) async => throw const AiDenied('quota habis'),
      );
      fail('harus lempar');
    } on AiFailure catch (e) {
      expect(e.code, 'denied');
      expect(e.detail, 'quota habis');
    }
  });

  test('app check invalid = kode app_check spesifik tanpa retry', () async {
    var calls = 0;
    try {
      await parseReceiptFirebase(
        ocrText: 'TOTAL 100',
        generate: (prompt) async {
          calls++;
          throw const AiAppCheck('Firebase App Check token is invalid');
        },
      );
      fail('harus lempar');
    } on AiFailure catch (e) {
      expect(e.code, 'app_check');
      expect(e.detail, contains('invalid'));
    }
    expect(calls, 1);
  });

  test('helper REST: body + parse valid/rusak', () {
    final b = restPromptBody('Halo');
    final parts =
        ((b['contents'] as List).first as Map)['parts'] as List;
    expect((parts.first as Map)['text'], 'Halo');
    expect(
      parseRestText({
        'candidates': [
          {
            'content': {
              'parts': [
                {'text': 'Hai!'}
              ]
            }
          }
        ]
      }),
      'Hai!',
    );
    expect(parseRestText({'candidates': []}), isNull);
    expect(parseRestText({'nope': 1}), isNull);
    expect(parseRestText('string'), isNull);
  });

  test('reachReport: status apapun = hidup, error = buntu', () {    expect(reachReport(status: 404), 'NET: host hidup (HTTP 404)');
    expect(reachReport(status: 200), 'NET: host hidup (HTTP 200)');
    expect(
      reachReport(error: 'TimeoutException after 10s'),
      'NET: BUNTU (TimeoutException after 10s)',
    );
  });

  test('isBusyMessage + server = ai_busy ramah', () {
    expect(
      isBusyMessage(
          'Server Error 500 This model is currently experiencing high demand'),
      isTrue,
    );
    expect(isBusyMessage('429 resource exhausted'), isTrue);
    expect(isBusyMessage('quota exceeded'), isTrue);
    expect(isBusyMessage('model overloaded'), isTrue);
    expect(isBusyMessage('permission denied'), isFalse);
    expect(isBusyMessage('timeout'), isFalse);
    expect(aiFailureTrKey('server', loggedIn: true), 'ai_busy');
  });

  test('kuota: parse waktu + baris ramah', () {
    expect(isQuotaMessage('quota exceeded, limit 20'), isTrue);
    expect(isQuotaMessage('429 resource exhausted'), isTrue);
    expect(isQuotaMessage('Server Error 500'), isFalse);
    expect(
      parseQuotaRetry('quota exceeded, please retry in 12h'),
      const Duration(hours: 12),
    );
    expect(parseQuotaRetry('retry in 30m'), const Duration(minutes: 30));
    expect(
      parseQuotaRetry('{"retryDelay": "3600s"}'),
      const Duration(hours: 1),
    );
    expect(parseQuotaRetry('quota habis'), isNull);
    expect(
      quotaWaitLine('retry in 12h'),
      'Kuota AI habis. Coba lagi dalam 12 jam.',
    );
    expect(quotaWaitLine('x'), 'Kuota AI habis. Coba lagi nanti.');
  });

  test('pickAiError: tekan kuota firebase bila kunci ada', () {
    var e = pickAiError(
      gemini: const AiFailure('quota', 'quota, retry in 2h'),
      firebase: const AiFailure('quota', 'quota, retry in 10h'),
      hasKey: true,
    )!;
    expect(e.code, 'quota');
    expect(e.detail, contains('10h'));
    e = pickAiError(
      gemini: const AiFailure('timeout', 'hang'),
      firebase: const AiFailure('quota', 'retry in 10h'),
      hasKey: true,
    )!;
    expect(e.code, 'timeout');
    e = pickAiError(
      firebase: const AiFailure('quota', 'x'),
      hasKey: false,
    )!;
    expect(e.code, 'quota');
    expect(pickAiError(hasKey: true), isNull);
  });

  test('aiMessageKey: pendek ramah tanpa kode teknis', () {
    expect(aiMessageKey('server'), 'ai_busy');
    expect(aiMessageKey('denied'), 'ai_key_invalid');
    expect(aiMessageKey('timeout'), 'ai_fail');
    expect(aiMessageKey('network'), 'ai_fail');
    expect(aiMessageKey('empty'), 'ai_fail');
    expect(aiMessageKey('app_check'), 'ai_fail');
  });
}
