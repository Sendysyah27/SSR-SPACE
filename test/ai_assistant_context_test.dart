import 'package:flutter_test/flutter_test.dart';
import 'package:ssr_space/services/ai_assistant_context.dart';

void main() {
  test('assistantContextText kosong untuk snapshot kosong', () {
    expect(assistantContextText(const AssistantSnapshot()), '');
  });

  test('assistantContextText memuat saldo + kategori + tren', () {
    const s = AssistantSnapshot(
      wallets: [(name: 'Tunai', balance: 50000.0)],
      totalBalance: 50000,
      monthIn: 100000,
      monthOut: 30000,
      topCategories: [(name: 'Makanan', total: 20000.0)],
      last7Count: 2,
      last7In: 10000,
      last7Out: 5000,
    );
    final t = assistantContextText(s);
    expect(t.contains('DATA ASISTEN'), isTrue);
    expect(t.contains('Tunai'), isTrue);
    expect(t.contains('Makanan'), isTrue);
    expect(t.contains('7 hari terakhir'), isTrue);
  });

  test('hasData false hanya bila semua kosong', () {
    expect(const AssistantSnapshot().hasData, isFalse);
    expect(
        const AssistantSnapshot(wallets: [(name: 'A', balance: 0.0)]).hasData,
        isTrue);
  });
}
