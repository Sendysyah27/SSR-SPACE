import 'package:flutter_test/flutter_test.dart';
import 'package:ssr_space/services/announcement_parse.dart';

void main() {
  test('parseAnnouncements toleran + unreadCount', () {
    final raw = [
      {
        'id': 'a1',
        'title': 'Halo',
        'body': 'Isi',
        'kind': 'promo',
        'pinned': true,
        'published_at': '2026-10-17T00:00:00Z',
        'read': false,
      },
      {'id': '', 'title': 'kosong'},
      {'id': 'a2', 'kind': 'aneh', 'published_at': 'bukan-tanggal'},
      42,
    ];
    final list = parseAnnouncements(raw);
    expect(list.length, 2);
    expect(list[0].kind, 'promo');
    expect(list[0].pinned, isTrue);
    expect(list[0].publishedAt, isNotNull);
    expect(list[1].kind, 'info');
    expect(list[1].publishedAt, isNull);
    expect(unreadCount(list), 2);
    expect(unreadCount(parseAnnouncements([{'id': 'b', 'read': true}])), 0);
    expect(parseAnnouncements(null), isEmpty);
  });

  test('parseAnnouncements non-list input = kosong', () {
    expect(parseAnnouncements('bukan-list'), isEmpty);
    expect(parseAnnouncements({'id': 'x'}), isEmpty);
  });

  test('parseFallbackAnnouncements decode + gagal = kosong', () {
    final fb = parseFallbackAnnouncements(
      '[{"id":"f1","title":"Fallback","kind":"update"}]',
    );
    expect(fb.length, 1);
    expect(fb[0].id, 'f1');
    expect(fb[0].kind, 'update');
    expect(parseFallbackAnnouncements('{bukan json'), isEmpty);
  });

  test('parseRoadmap toleran', () {
    final list = parseRoadmap([
      {'id': 'r1', 'title': 'X', 'status': 'done', 'sort_order': 20},
      {'id': 'r2', 'status': 'aneh', 'sort_order': 'x'},
      {'id': '', 'title': 'kosong'},
      42,
    ]);
    expect(list.length, 2);
    expect(list[0].status, 'done');
    expect(list[0].sortOrder, 20);
    expect(list[1].status, 'planned');
    expect(list[1].sortOrder, 0);
  });

  test('parseRoadmap non-list/null = kosong, elemen cacat dilewati', () {
    expect(parseRoadmap(null), isEmpty);
    expect(parseRoadmap('bukan-list'), isEmpty);
    expect(parseRoadmap({'id': 'x'}), isEmpty);
  });

  test('unionReadIds monoton: prefs hanya menambah baca', () {
    final items = [
      const Announcement(
        id: 'a1',
        title: 'T',
        body: '',
        kind: 'info',
        pinned: false,
        read: false,
      ),
      const Announcement(
        id: 'a2',
        title: 'T',
        body: '',
        kind: 'info',
        pinned: false,
        read: true,
      ),
    ];
    final out = unionReadIds(items, {'a1'});
    expect(out.firstWhere((a) => a.id == 'a1').read, isTrue);
    expect(out.firstWhere((a) => a.id == 'a2').read, isTrue);
    expect(identical(unionReadIds(items, const <String>{}), items), isTrue);
  });

  test('pendingReadIds = prefs yang belum read di server', () {
    final items = [
      const Announcement(
        id: 'a1',
        title: 'T',
        body: '',
        kind: 'info',
        pinned: false,
        read: true,
      ),
      const Announcement(
        id: 'a2',
        title: 'T',
        body: '',
        kind: 'info',
        pinned: false,
        read: false,
      ),
    ];
    expect(
      pendingReadIds(items, {'a1', 'a2', 'a3'}),
      unorderedEquals(['a2', 'a3']),
    );
    expect(pendingReadIds(items, const <String>{}), isEmpty);
  });
}
