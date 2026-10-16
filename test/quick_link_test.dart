import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:ssr_space/services/quick_link.dart';

void main() {
  setUp(() => SharedPreferences.setMockInitialValues({}));

  test('parse tipe valid', () {
    expect(
      parseQuickLink(Uri.parse('ssrspace://quick-entry?type=in')),
      'in',
    );
    expect(
      parseQuickLink(Uri.parse('ssrspace://quick-entry?type=out')),
      'out',
    );
    expect(
      parseQuickLink(Uri.parse('ssrspace://quick-entry?type=transfer')),
      'transfer',
    );
  });

  test('skema salah → null', () {
    expect(parseQuickLink(Uri.parse('https://x?type=out')), isNull);
  });

  test('host salah atau uri null → null', () {
    expect(parseQuickLink(Uri.parse('ssrspace://other?type=out')), isNull);
    expect(parseQuickLink(null), isNull);
  });

  test('tipe absen, kosong, atau asing → out', () {
    expect(parseQuickLink(Uri.parse('ssrspace://quick-entry')), 'out');
    expect(parseQuickLink(Uri.parse('ssrspace://quick-entry?type=')), 'out');
    expect(
      parseQuickLink(Uri.parse('ssrspace://quick-entry?type=bogus')),
      'out',
    );
  });

  test('antre lalu ambil sekali, ambil kedua null', () async {
    await queuePending('in');
    expect(await takePending(), 'in');
    expect(await takePending(), isNull);
  });

  test('queuePending sanitasi tipe asing ke out', () async {
    await queuePending('bogus');
    expect(await takePending(), 'out');
  });

  test('pending basi dibuang', () async {
    final prefs = await SharedPreferences.getInstance();
    final stale = DateTime.now()
        .subtract(const Duration(hours: 25))
        .millisecondsSinceEpoch;
    await prefs.setString(
      pendingQuickEntryKey,
      '{"type":"out","at":$stale}',
    );
    expect(await takePending(), isNull);
    expect(prefs.getString(pendingQuickEntryKey), isNull);
  });

  test('pending segar terbaca', () async {
    final prefs = await SharedPreferences.getInstance();
    final fresh = DateTime.now()
        .subtract(const Duration(hours: 23))
        .millisecondsSinceEpoch;
    await prefs.setString(
      pendingQuickEntryKey,
      '{"type":"transfer","at":$fresh}',
    );
    expect(await takePending(), 'transfer');
  });

  test('pending rusak dibuang', () async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(pendingQuickEntryKey, 'rusak{');
    expect(await takePending(), isNull);
    expect(prefs.getString(pendingQuickEntryKey), isNull);
  });

  test('ready hanya (true,true,false)', () {
    expect(
      quickLinkReady(loggedIn: true, hasOrg: true, locked: false),
      isTrue,
    );
    expect(
      quickLinkReady(loggedIn: false, hasOrg: true, locked: false),
      isFalse,
    );
    expect(
      quickLinkReady(loggedIn: true, hasOrg: false, locked: false),
      isFalse,
    );
    expect(
      quickLinkReady(loggedIn: true, hasOrg: true, locked: true),
      isFalse,
    );
  });
}
