import 'package:flutter/material.dart';
import 'package:ssr_space/services/announcement_parse.dart';
import 'package:ssr_space/services/announcement_service.dart';
import 'package:ssr_space/theme/app_icons.dart';
import 'package:ssr_space/theme/app_theme.dart';
import 'package:ssr_space/utils/datetime.dart';
import 'package:ssr_space/utils/strings.dart';
import 'package:ssr_space/widgets/section_card.dart';
import 'package:ssr_space/widgets/skeletons.dart';
import 'package:ssr_space/widgets/state_views.dart';
import 'package:ssr_space/widgets/status_chip.dart';

/// Pengumuman produk: server dulu (RPC), fallback aset bawaan. Ketuk kartu
/// = tandai dibaca (ack server + prefs) lalu segarkan angka badge hub.
/// Status baca di server per-user; dedupe notifikasi terpisah (device-local).
class AnnouncementsScreen extends StatefulWidget {
  const AnnouncementsScreen({super.key});

  @override
  State<AnnouncementsScreen> createState() => _AnnouncementsScreenState();
}

class _AnnouncementsScreenState extends State<AnnouncementsScreen> {
  bool _loading = true;
  List<Announcement> _items = const [];

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() => _loading = true);
    final list = await fetchAnnouncements();
    if (!mounted) return;
    setState(() {
      _items = list;
      _loading = false;
    });
  }

  Future<void> _open(Announcement a) async {
    if (a.read) return;
    await ackAnnouncements([a.id]);
    await refreshUnreadBadge();
    if (!mounted) return;
    setState(() => _items = _readNow(_items, a.id));
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text(tr('an_title'))),
      body: _body(),
    );
  }

  Widget _body() {
    if (_loading) return const TxListSkeleton();
    if (_items.isEmpty) {
      return EmptyView(
        icon: AppIcons.autoBadge,
        illustration: 'assets/illustrations/empty_riwayat.svg',
        title: tr('an_empty'),
        actionLabel: tr('reload'),
        onAction: _load,
      );
    }
    return ListView.separated(
      padding: const EdgeInsets.all(SsrSpace.lg),
      itemCount: _items.length,
      separatorBuilder: (_, __) => const SizedBox(height: SsrSpace.md),
      itemBuilder: (_, i) => _AnnouncementCard(
        a: _items[i],
        onTap: () => _open(_items[i]),
      ),
    );
  }
}

/// Salin daftar dengan satu id ditandai sudah dibaca.
List<Announcement> _readNow(List<Announcement> items, String id) => [
  for (final e in items)
    e.id == id
        ? Announcement(
            id: e.id,
            title: e.title,
            body: e.body,
            kind: e.kind,
            pinned: e.pinned,
            read: true,
            publishedAt: e.publishedAt,
          )
        : e,
];

String _kindKey(String kind) => switch (kind) {
  'promo' => 'an_kind_promo',
  'update' => 'an_kind_update',
  _ => 'an_kind_info',
};

StatusTone _kindTone(String kind) => switch (kind) {
  'promo' => StatusTone.ink,
  'update' => StatusTone.accent,
  _ => StatusTone.neutral,
};

String _dateLabel(DateTime dt) {
  final d = dt.toLocal();
  final ymd =
      '${d.year.toString().padLeft(4, '0')}-'
      '${d.month.toString().padLeft(2, '0')}-'
      '${d.day.toString().padLeft(2, '0')}';
  return dayLabel(ymd);
}

/// Satu kartu pengumuman: judul (+ tanda Baru), chip jenis, tanggal, isi.
class _AnnouncementCard extends StatelessWidget {
  final Announcement a;
  final VoidCallback onTap;

  const _AnnouncementCard({required this.a, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    return SectionCard(
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(SsrRadius.card),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                  child: Text(a.title, style: textTheme.titleMedium),
                ),
                if (!a.read) ...[
                  const SizedBox(width: SsrSpace.sm),
                  StatusChip(
                    label: tr('an_new'),
                    tone: StatusTone.danger,
                    isSmall: true,
                  ),
                ],
              ],
            ),
            const SizedBox(height: SsrSpace.sm),
            Row(
              children: [
                StatusChip(
                  label: tr(_kindKey(a.kind)),
                  tone: _kindTone(a.kind),
                  isSmall: true,
                ),
                if (a.publishedAt != null) ...[
                  const SizedBox(width: SsrSpace.sm),
                  Text(_dateLabel(a.publishedAt!), style: textTheme.bodySmall),
                ],
              ],
            ),
            if (a.body.isNotEmpty) ...[
              const SizedBox(height: SsrSpace.sm),
              Text(a.body, style: textTheme.bodyMedium),
            ],
          ],
        ),
      ),
    );
  }
}
