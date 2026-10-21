import 'package:flutter_test/flutter_test.dart';
import 'package:ssr_space/services/ai_chat_parse.dart';

const _wallets = ['TUNAI', 'PALING MURAH', 'DANA'];
const _cats = ['Makanan', 'Transportasi', 'Belanja', 'Lainnya'];

void main() {
  test('JSON bersih valid dengan action', () {
    final r = parseChatReply(
      '{"reply":"Siap, catat ya.","action":{"type":"out","amount":16000,'
      '"category":"Makanan","wallet":"TUNAI","note":"kopi"}}',
      wallets: _wallets,
      categories: _cats,
    );
    expect(r.reply, 'Siap, catat ya.');
    expect(r.action, isNotNull);
    expect(r.action!['type'], 'out');
    expect(r.action!['amount'], 16000);
    expect(r.action!['amount'] is int, isTrue);
    expect(r.action!['category'], 'Makanan');
    expect(r.action!['wallet'], 'TUNAI');
    expect(r.action!['note'], 'kopi');
  });

  test('type transfer ditolak (tanpa dompet tujuan di kontrak)', () {
    final r = parseChatReply(
      '{"reply":"Ok.","action":{"type":"transfer","amount":50000,'
      '"category":"Lainnya","wallet":"DANA"}}',
      wallets: _wallets,
      categories: _cats,
    );
    expect(r.action, isNull);
    expect(
      validateChatActionReason(
        {'type': 'transfer', 'amount': 50000, 'category': 'Lainnya', 'wallet': 'DANA'},
        wallets: _wallets,
        categories: _cats,
      ),
      'transfer_tanpa_tujuan',
    );
  });

  test('JSON dalam fence ```json', () {
    final r = parseChatReply(
      '```json\n{"reply":"Oke.","action":null}\n```',
      wallets: _wallets,
      categories: _cats,
    );
    expect(r.reply, 'Oke.');
    expect(r.action, isNull);
  });

  test('JSON dalam fence ``` biasa', () {
    final r = parseChatReply(
      '```\n{"reply":"Oke."}\n```',
      wallets: _wallets,
      categories: _cats,
    );
    expect(r.reply, 'Oke.');
    expect(r.action, isNull);
  });

  test('JSON invalid -> fallback teks asli', () {
    const raw = 'maaf, lagi error {bukan json';
    final r = parseChatReply(raw, wallets: _wallets, categories: _cats);
    expect(r.reply, raw);
    expect(r.action, isNull);
  });

  test('bukan Map -> fallback teks asli', () {
    const raw = '[1,2,3]';
    final r = parseChatReply(raw, wallets: _wallets, categories: _cats);
    expect(r.reply, raw);
    expect(r.action, isNull);
  });

  test('action null', () {
    final r = parseChatReply(
      '{"reply":"Halo!","action":null}',
      wallets: _wallets,
      categories: _cats,
    );
    expect(r.reply, 'Halo!');
    expect(r.action, isNull);
  });

  test('reply saja tanpa action', () {
    final r = parseChatReply(
      '{"reply":"Halo mang!"}',
      wallets: _wallets,
      categories: _cats,
    );
    expect(r.reply, 'Halo mang!');
    expect(r.action, isNull);
  });

  test('amount negatif ditolak', () {
    final r = parseChatReply(
      '{"reply":"x","action":{"type":"out","amount":-500,'
      '"category":"Makanan","wallet":"TUNAI"}}',
      wallets: _wallets,
      categories: _cats,
    );
    expect(r.reply, 'x');
    expect(r.action, isNull);
  });

  test('amount nol ditolak', () {
    final r = parseChatReply(
      '{"reply":"x","action":{"type":"out","amount":0,'
      '"category":"Makanan","wallet":"TUNAI"}}',
      wallets: _wallets,
      categories: _cats,
    );
    expect(r.action, isNull);
  });

  test('amount double ditolak', () {
    final r = parseChatReply(
      '{"reply":"x","action":{"type":"out","amount":16000.5,'
      '"category":"Makanan","wallet":"TUNAI"}}',
      wallets: _wallets,
      categories: _cats,
    );
    expect(r.action, isNull);
  });

  test('amount string ditolak', () {
    final r = parseChatReply(
      '{"reply":"x","action":{"type":"out","amount":"16000",'
      '"category":"Makanan","wallet":"TUNAI"}}',
      wallets: _wallets,
      categories: _cats,
    );
    expect(r.action, isNull);
  });

  test('wallet tidak dikenal ditolak', () {
    final r = parseChatReply(
      '{"reply":"x","action":{"type":"out","amount":1000,'
      '"category":"Makanan","wallet":"DOMPET GAIB"}}',
      wallets: _wallets,
      categories: _cats,
    );
    expect(r.reply, 'x');
    expect(r.action, isNull);
  });

  test('type tidak dikenal ditolak', () {
    final r = parseChatReply(
      '{"reply":"x","action":{"type":"ngutang","amount":1000,'
      '"category":"Makanan","wallet":"TUNAI"}}',
      wallets: _wallets,
      categories: _cats,
    );
    expect(r.action, isNull);
  });

  test('category tidak dikenal ditolak', () {
    final r = parseChatReply(
      '{"reply":"x","action":{"type":"out","amount":1000,'
      '"category":"Judi","wallet":"TUNAI"}}',
      wallets: _wallets,
      categories: _cats,
    );
    expect(r.action, isNull);
  });

  test('wallet fuzzy cocok -> normalisasi nama resmi', () {
    final r = parseChatReply(
      '{"reply":"x","action":{"type":"in","amount":27900,'
      '"category":"Belanja","wallet":"tunai"}}',
      wallets: _wallets,
      categories: _cats,
    );
    expect(r.action, isNotNull);
    expect(r.action!['wallet'], 'TUNAI');
  });

  test('category case-insensitive -> normalisasi', () {
    final r = parseChatReply(
      '{"reply":"x","action":{"type":"out","amount":1000,'
      '"category":"makanan","wallet":"TUNAI"}}',
      wallets: _wallets,
      categories: _cats,
    );
    expect(r.action, isNotNull);
    expect(r.action!['category'], 'Makanan');
  });

  test('format hybrid lama tetap terbaca reply-nya', () {
    final r = parseChatReply(
      '{"intent":"adjust_balance","reply":"Siap mang."}',
      wallets: _wallets,
      categories: _cats,
    );
    expect(r.reply, 'Siap mang.');
    expect(r.action, isNull);
  });

  test('tanpa daftar wallet/kategori: string non-empty diterima', () {
    final r = parseChatReply(
      '{"reply":"x","action":{"type":"out","amount":1000,'
      '"category":"Bebas","wallet":"Dompetku"}}',
    );
    expect(r.action, isNotNull);
    expect(r.action!['wallet'], 'Dompetku');
  });

  group('reason codes (debug-only, tanpa isi pesan)', () {
    test('wallet tidak dikenal -> wallet_tidak_cocok + actionRaw', () {
      final r = parseChatReply(
        '{"reply":"Siap, tinggal konfirmasi.","action":{"type":"out",'
        '"amount":16000,"category":"Makanan","wallet":"QRIS BCA"}}',
        wallets: _wallets,
        categories: _cats,
      );
      expect(r.action, isNull);
      expect(r.reason, 'wallet_tidak_cocok');
      expect(r.actionRaw, isNotNull);
      expect(r.actionRaw!['wallet'], 'QRIS BCA');
      expect(r.actionRaw!['amount'], 16000);
    });

    test('kategori tidak dikenal -> kategori_tidak_cocok', () {
      final r = parseChatReply(
        '{"reply":"Ok.","action":{"type":"out","amount":16000,'
        '"category":"Jajan","wallet":"TUNAI"}}',
        wallets: _wallets,
        categories: _cats,
      );
      expect(r.action, isNull);
      expect(r.reason, 'kategori_tidak_cocok');
    });

    test('amount string -> amount_invalid', () {
      final r = parseChatReply(
        '{"reply":"Ok.","action":{"type":"out","amount":"16000",'
        '"category":"Makanan","wallet":"TUNAI"}}',
        wallets: _wallets,
        categories: _cats,
      );
      expect(r.reason, 'amount_invalid');
    });

    test('amount nol -> amount_invalid', () {
      final r = parseChatReply(
        '{"reply":"Ok.","action":{"type":"out","amount":0,'
        '"category":"Makanan","wallet":"TUNAI"}}',
        wallets: _wallets,
        categories: _cats,
      );
      expect(r.reason, 'amount_invalid');
    });

    test('bukan JSON -> parse_gagal, reply = teks asli', () {
      const raw = 'halo, ini bukan json';
      final r = parseChatReply(raw, wallets: _wallets, categories: _cats);
      expect(r.reply, raw);
      expect(r.action, isNull);
      expect(r.reason, 'parse_gagal');
    });

    test('action null eksplisit -> action_null', () {
      final r = parseChatReply(
        '{"reply":"Halo.","action":null}',
        wallets: _wallets,
        categories: _cats,
      );
      expect(r.reason, 'action_null');
    });

    test('type tidak dikenal -> type_invalid', () {
      final r = parseChatReply(
        '{"reply":"Ok.","action":{"type":"bayar","amount":1000,'
        '"category":"Makanan","wallet":"TUNAI"}}',
        wallets: _wallets,
        categories: _cats,
      );
      expect(r.reason, 'type_invalid');
    });

    test('aksi valid -> reason null', () {
      final r = parseChatReply(
        '{"reply":"Ok.","action":{"type":"out","amount":1000,'
        '"category":"Makanan","wallet":"TUNAI"}}',
        wallets: _wallets,
        categories: _cats,
      );
      expect(r.reason, isNull);
      expect(r.action, isNotNull);
    });
  });

  group('replyPromisesConfirmation', () {
    test('mengandung "konfirmasi" -> true', () {
      expect(replyPromisesConfirmation('Siap, tinggal konfirmasi ya.'), isTrue);
    });

    test('mengandung "jalankan" -> true', () {
      expect(replyPromisesConfirmation('Ketuk jalankan di bawah.'), isTrue);
    });

    test('teks biasa -> false', () {
      expect(replyPromisesConfirmation('Halo, apa kabar?'), isFalse);
    });
  });

  group('shouldShowActionFallback', () {
    test('action null + janji konfirmasi -> true', () {
      expect(
        shouldShowActionFallback(
          action: null,
          reason: 'wallet_tidak_cocok',
          reply: 'Siap, tinggal konfirmasi.',
        ),
        isTrue,
      );
    });

    test('action valid -> false', () {
      expect(
        shouldShowActionFallback(
          action: {'type': 'out'},
          reason: null,
          reply: 'tinggal konfirmasi',
        ),
        isFalse,
      );
    });

    test('ditolak tanpa janji -> false', () {
      expect(
        shouldShowActionFallback(
          action: null,
          reason: 'wallet_tidak_cocok',
          reply: 'Halo, apa kabar?',
        ),
        isFalse,
      );
    });

    test('reason null -> false', () {
      expect(
        shouldShowActionFallback(
          action: null,
          reason: null,
          reply: 'tinggal konfirmasi',
        ),
        isFalse,
      );
    });
  });

  group('buildPendingChatAction', () {
    test('wallet bad -> fixable, walletBad terisi', () {
      final p = buildPendingChatAction(
        reason: 'wallet_tidak_cocok',
        raw: {
          'type': 'out',
          'amount': 16000,
          'category': 'Makanan',
          'wallet': 'QRIS BCA',
        },
        walletNames: _wallets,
        categories: _cats,
      );
      expect(p, isNotNull);
      expect(p!.fixable, isTrue);
      expect(p.walletBad, 'QRIS BCA');
      expect(p.walletOk, isNull);
      expect(p.categoryOk, 'Makanan');
      expect(p.amount, 16000);
      expect(p.walletOptions, _wallets);
    });

    test('kategori bad -> fixable, categoryBad terisi', () {
      final p = buildPendingChatAction(
        reason: 'kategori_tidak_cocok',
        raw: {
          'type': 'out',
          'amount': 16000,
          'category': 'Jajan',
          'wallet': 'TUNAI',
        },
        walletNames: _wallets,
        categories: _cats,
      );
      expect(p!.fixable, isTrue);
      expect(p.categoryBad, 'Jajan');
      expect(p.walletOk, 'TUNAI');
    });

    test('amount invalid -> unfixable', () {
      final p = buildPendingChatAction(
        reason: 'amount_invalid',
        raw: null,
        walletNames: _wallets,
        categories: _cats,
      );
      expect(p!.fixable, isFalse);
    });

    test('parse_gagal -> unfixable', () {
      final p = buildPendingChatAction(
        reason: 'parse_gagal',
        raw: null,
        walletNames: _wallets,
        categories: _cats,
      );
      expect(p!.fixable, isFalse);
    });
  });

  group('batch 281: ekstraksi lenient', () {
    test('prosa + JSON kontrak di tengah -> reply bersih + action', () {
      final r = parseChatReply(
        'Baik, saya catatkan ya. {"reply":"Siap, tekan Jalankan.",'
        '"action":{"type":"out","amount":16000,"category":"Makanan",'
        '"wallet":"TUNAI"}} sudah saya siapkan.',
        wallets: _wallets,
        categories: _cats,
      );
      expect(r.reply, 'Siap, tekan Jalankan.');
      expect(r.action, isNotNull);
      expect(r.action!['amount'], 16000);
      expect(r.command, isNull);
    });

    test('fence json di tengah prosa -> terekstrak', () {
      final r = parseChatReply(
        'Berikut hasilnya:\n```json\n{"reply":"Halo!",'
        '"action":null}\n```\nSemoga membantu.',
      );
      expect(r.reply, 'Halo!');
      expect(r.action, isNull);
      expect(r.reason, 'action_null');
    });

    test('prosa murni tanpa kontrak -> teks asli apa adanya', () {
      final r = parseChatReply('Halo, ada yang bisa saya bantu?');
      expect(r.reply, 'Halo, ada yang bisa saya bantu?');
      expect(r.reason, 'parse_gagal');
      expect(r.command, isNull);
    });

    test('kurung liar di prosa tidak mengganggu ekstraksi', () {
      final r = parseChatReply(
        'Saldo (estimasi) {belum final. {"reply":"Oke.","action":null}',
      );
      expect(r.reply, 'Oke.');
    });
  });

  group('batch 281: action navigate', () {
    test('navigate valid -> command terisi, action tx null', () {
      final r = parseChatReply(
        '{"reply":"Siap, buka E-Money NFC ya.","action":'
        '{"type":"navigate","target":"nfc"}}',
      );
      expect(r.command, isNotNull);
      expect(r.command!['type'], 'navigate');
      expect(r.command!['target'], 'nfc');
      expect(r.action, isNull);
      expect(r.reason, isNull);
    });

    test('target tak dikenal -> command null + target_invalid', () {
      final r = parseChatReply(
        '{"reply":"Siap.","action":{"type":"navigate","target":"mars"}}',
      );
      expect(r.command, isNull);
      expect(r.reason, 'target_invalid');
      expect(r.actionRaw?['target'], 'mars');
    });

    test('target bukan string -> target_invalid', () {
      final r = parseChatReply(
        '{"reply":"Siap.","action":{"type":"navigate","target":7}}',
      );
      expect(r.command, isNull);
      expect(r.reason, 'target_invalid');
    });

    test('semua target resmi diterima', () {
      for (final t in kChatNavTargets) {
        final r = parseChatReply(
          '{"reply":"x","action":{"type":"navigate","target":"$t"}}',
        );
        expect(r.command?['target'], t, reason: t);
      }
    });
  });

  group('batch 281: action add_wallet', () {
    test('valid dengan default cash + saldo awal 0', () {
      final r = parseChatReply(
        '{"reply":"Siap.","action":{"type":"add_wallet","name":"BRI"}}',
        wallets: _wallets,
        categories: _cats,
      );
      expect(r.command, isNotNull);
      expect(r.command!['name'], 'BRI');
      expect(r.command!['wallet_type'], 'cash');
      expect(r.command!['opening_balance'], 0);
      expect(r.action, isNull);
    });

    test('valid dengan tipe + saldo awal', () {
      final r = parseChatReply(
        '{"reply":"Siap.","action":{"type":"add_wallet","name":"OVO",'
        '"wallet_type":"ewallet","opening_balance":50000}}',
        wallets: _wallets,
      );
      expect(r.command!['wallet_type'], 'ewallet');
      expect(r.command!['opening_balance'], 50000);
    });

    test('nama kosong -> nama_kosong', () {
      final r = parseChatReply(
        '{"reply":"Siap.","action":{"type":"add_wallet","name":"  "}}',
        wallets: _wallets,
      );
      expect(r.command, isNull);
      expect(r.reason, 'nama_kosong');
    });

    test('nama duplikat (case-insensitive) -> dompet_sudah_ada', () {
      final r = parseChatReply(
        '{"reply":"Siap.","action":{"type":"add_wallet","name":"tunai"}}',
        wallets: _wallets,
      );
      expect(r.command, isNull);
      expect(r.reason, 'dompet_sudah_ada');
    });

    test('tipe asing -> tipe_dompet_invalid', () {
      final r = parseChatReply(
        '{"reply":"Siap.","action":{"type":"add_wallet","name":"X",'
        '"wallet_type":"crypto"}}',
        wallets: _wallets,
      );
      expect(r.command, isNull);
      expect(r.reason, 'tipe_dompet_invalid');
    });

    test('saldo awal negatif / double -> saldo_awal_invalid', () {
      for (final v in ['-5', '12.5']) {
        final r = parseChatReply(
          '{"reply":"Siap.","action":{"type":"add_wallet","name":"X",'
          '"opening_balance":$v}}',
          wallets: _wallets,
        );
        expect(r.command, isNull, reason: v);
        expect(r.reason, 'saldo_awal_invalid', reason: v);
      }
    });
  });

  group('batch 281: action add_category', () {
    test('valid -> command terisi', () {
      final r = parseChatReply(
        '{"reply":"Siap.","action":{"type":"add_category","name":"Kopi"}}',
        categories: _cats,
      );
      expect(r.command, isNotNull);
      expect(r.command!['name'], 'Kopi');
    });

    test('duplikat (case-insensitive) -> kategori_sudah_ada', () {
      final r = parseChatReply(
        '{"reply":"Siap.","action":{"type":"add_category","name":"makanan"}}',
        categories: _cats,
      );
      expect(r.command, isNull);
      expect(r.reason, 'kategori_sudah_ada');
    });

    test('kind asing -> kind_invalid; kind in/out diterima', () {
      final bad = parseChatReply(
        '{"reply":"Siap.","action":{"type":"add_category","name":"Kopi",'
        '"kind":"sideways"}}',
        categories: _cats,
      );
      expect(bad.command, isNull);
      expect(bad.reason, 'kind_invalid');
      final ok = parseChatReply(
        '{"reply":"Siap.","action":{"type":"add_category","name":"Kopi",'
        '"kind":"out"}}',
        categories: _cats,
      );
      expect(ok.command?['kind'], 'out');
    });
  });
}
