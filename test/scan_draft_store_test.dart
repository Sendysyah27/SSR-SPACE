import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:ssr_space/services/ai_draft.dart';
import 'package:ssr_space/services/scan_draft_store.dart';

// Batch 286 tahap C: draft scan persisten lokal.
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  const draft = AiDraft(
    merchant: 'SANCHA',
    date: '2026-09-08',
    time: '19:21',
    items: [
      AiDraftItem(name: 'Da Hong Pao Milk Tea (M)', qty: 1, price: 32000),
    ],
    subtotal: 32000,
    discount: 16000,
    total: 16000,
    payment: 'QRIS',
  );

  setUp(() {
    SharedPreferences.setMockInitialValues({});
  });

  test('add lalu list: draft utuh termasuk jam & diskon', () async {
    final store = ScanDraftStore();
    await store.add(draft);
    final entries = await store.list();
    expect(entries.length, 1);
    final d = entries.first.draft;
    expect(d.merchant, 'SANCHA');
    expect(d.date, '2026-09-08');
    expect(d.time, '19:21');
    expect(d.discount, 16000);
    expect(d.total, 16000);
    expect(d.items.length, 1);
  });

  test('update menimpa isi draft yang sama', () async {
    final store = ScanDraftStore();
    final e = await store.add(draft);
    await store.update(
      e.id,
      const AiDraft(merchant: 'UBAH', total: 99000),
    );
    final entries = await store.list();
    expect(entries.length, 1);
    expect(entries.first.draft.merchant, 'UBAH');
    expect(entries.first.draft.total, 99000);
  });

  test('remove menghapus; list kosong di awal', () async {
    final store = ScanDraftStore();
    expect(await store.list(), isEmpty);
    final e = await store.add(draft);
    await store.remove(e.id);
    expect(await store.list(), isEmpty);
  });

  test('entri rusak di storage dilewati, bukan crash', () async {
    SharedPreferences.setMockInitialValues({
      'scan_drafts_v1': '[{"id":123},{"draft":"x"},42]',
    });
    final store = ScanDraftStore();
    expect(await store.list(), isEmpty);
  });
}
