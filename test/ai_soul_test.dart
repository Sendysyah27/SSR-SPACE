import 'package:flutter_test/flutter_test.dart';
import 'package:ssr_space/services/ai_soul.dart';

void main() {
  test('parseRingkasBlocks ambil ringkasan', () {
    const t =
        '{"reply":"ok","action":null}\n```ringkas user memutuskan nabung 500rb per bulan```';
    expect(parseRingkasBlocks(t), ['user memutuskan nabung 500rb per bulan']);
  });

  test('parseRingkasBlocks ambil beberapa blok', () {
    const t = '```ringkas a``` teks ```ringkas b```';
    expect(parseRingkasBlocks(t), ['a', 'b']);
  });

  test('parseRingkasBlocks tolak yang terlalu panjang', () {
    final long = 'x' * 501;
    expect(parseRingkasBlocks('```ringkas $long```'), isEmpty);
  });

  test('parseRingkasBlocks kosong tanpa blok', () {
    expect(parseRingkasBlocks('{"reply":"halo","action":null}'), isEmpty);
  });

  test('stripRingkasBlocks hapus blok, JSON utuh', () {
    const t = '{"reply":"ok","action":null}\n```ringkas abc```';
    expect(stripRingkasBlocks(t), '{"reply":"ok","action":null}');
  });

  test('stripRingkasBlocks tidak sentuh teks tanpa blok', () {
    const t = '{"reply":"halo","action":null}';
    expect(stripRingkasBlocks(t), t);
  });

  test('aiContextBlock sertakan fakta + ringkasan', () {
    final b =
        aiContextBlock(['nama Sendy'], ['user mau nabung 500rb per bulan']);
    expect(b.contains('Fakta tentang user'), isTrue);
    expect(b.contains('nama Sendy'), isTrue);
    expect(b.contains('Ringkasan percakapan penting'), isTrue);
    expect(b.contains('user mau nabung 500rb per bulan'), isTrue);
  });

  test('aiContextBlock kompatibel tanpa ringkasan', () {
    final b = aiContextBlock(['nama Sendy']);
    expect(b.contains('Fakta tentang user'), isTrue);
    expect(b.contains('Ringkasan percakapan penting'), isFalse);
  });

  test('aiContextBlock batasi jumlah ringkasan', () {
    final many = List.generate(aiSummaryCap + 5, (i) => 'ringkasan $i');
    final b = aiContextBlock([], many);
    expect(b.contains('ringkasan ${aiSummaryCap + 4}'), isFalse);
    expect(b.contains('ringkasan 0'), isTrue);
  });

  test('aiAssistantSoul hanya izinkan navigate', () {
    expect(aiAssistantSoul.contains('navigate'), isTrue);
    expect(aiAssistantSoul.contains('add_wallet'), isFalse);
    expect(aiAssistantSoul.contains('Mode Catat'), isTrue);
  });

  test('aiAssistantContextBlock tanpa kontrak catat', () {
    final b = aiAssistantContextBlock(['nama Sendy'], ['nabung 500rb']);
    expect(b.contains('Mode Asisten'), isTrue);
    expect(b.contains('Fakta tentang user'), isTrue);
    expect(b.contains('nama Sendy'), isTrue);
    expect(b.contains('Ringkasan percakapan penting'), isTrue);
    expect(b.contains('Untuk mencatat transaksi, balas HANYA'), isFalse);
  });
}
