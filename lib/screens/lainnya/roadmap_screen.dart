import 'package:flutter/material.dart';
import 'package:ssr_space/services/announcement_parse.dart';
import 'package:ssr_space/services/announcement_service.dart';
import 'package:ssr_space/theme/app_icons.dart';
import 'package:ssr_space/theme/app_theme.dart';
import 'package:ssr_space/utils/strings.dart';
import 'package:ssr_space/widgets/section_card.dart';
import 'package:ssr_space/widgets/skeletons.dart';
import 'package:ssr_space/widgets/state_views.dart';
import 'package:ssr_space/widgets/status_chip.dart';

/// Roadmap produk: server dulu (RPC), fallback aset bawaan. Urut `sortOrder`
/// naik; status Direncanakan / Sedang dikerjakan / Selesai.
class RoadmapScreen extends StatefulWidget {
  const RoadmapScreen({super.key});

  @override
  State<RoadmapScreen> createState() => _RoadmapScreenState();
}

class _RoadmapScreenState extends State<RoadmapScreen> {
  bool _loading = true;
  List<RoadmapItem> _items = const [];

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() => _loading = true);
    final list = await fetchRoadmap();
    final sorted = [...list]..sort((a, b) => a.sortOrder.compareTo(b.sortOrder));
    if (!mounted) return;
    setState(() {
      _items = sorted;
      _loading = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text(tr('rm_title'))),
      body: _body(),
    );
  }

  Widget _body() {
    if (_loading) return const TxListSkeleton();
    if (_items.isEmpty) {
      return EmptyView(
        icon: AppIcons.history,
        illustration: 'assets/illustrations/empty_laporan.svg',
        title: tr('rm_empty'),
        actionLabel: tr('reload'),
        onAction: _load,
      );
    }
    return ListView.separated(
      padding: const EdgeInsets.all(SsrSpace.lg),
      itemCount: _items.length,
      separatorBuilder: (_, __) => const SizedBox(height: SsrSpace.md),
      itemBuilder: (_, i) => _RoadmapRow(item: _items[i]),
    );
  }
}

String _statusKey(String status) => switch (status) {
  'in_progress' => 'rm_progress',
  'done' => 'rm_done',
  _ => 'rm_planned',
};

StatusTone _statusTone(String status) => switch (status) {
  'in_progress' => StatusTone.ink,
  'done' => StatusTone.accent,
  _ => StatusTone.neutral,
};

/// Satu baris roadmap: judul (+ deskripsi opsional) di kiri, chip status
/// di kanan.
class _RoadmapRow extends StatelessWidget {
  final RoadmapItem item;

  const _RoadmapRow({required this.item});

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    return SectionCard(
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(item.title, style: textTheme.titleMedium),
                if (item.description.isNotEmpty) ...[
                  const SizedBox(height: SsrSpace.xs),
                  Text(item.description, style: textTheme.bodySmall),
                ],
              ],
            ),
          ),
          const SizedBox(width: SsrSpace.sm),
          StatusChip(
            label: tr(_statusKey(item.status)),
            tone: _statusTone(item.status),
            isSmall: true,
          ),
        ],
      ),
    );
  }
}
