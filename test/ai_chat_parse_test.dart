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

  test('type transfer valid', () {
    final r = parseChatReply(
      '{"reply":"Ok.","action":{"type":"transfer","amount":50000,'
      '"category":"Lainnya","wallet":"DANA"}}',
      wallets: _wallets,
      categories: _cats,
    );
    expect(r.action, isNotNull);
    expect(r.action!['type'], 'transfer');
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
}
