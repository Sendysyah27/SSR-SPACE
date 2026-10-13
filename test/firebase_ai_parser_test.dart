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
          throw AiDenied();
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
}
