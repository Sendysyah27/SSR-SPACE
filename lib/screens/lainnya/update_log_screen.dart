import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:ssr_space/services/changelog_parse.dart';
import 'package:ssr_space/theme/app_theme.dart';
import 'package:ssr_space/utils/app_info.dart';
import 'package:ssr_space/utils/strings.dart';
import 'package:ssr_space/widgets/section_card.dart';
import 'package:ssr_space/widgets/status_chip.dart';

/// Catatan perubahan: baca aset teks statis, tanpa paket markdown.
class UpdateLogScreen extends StatefulWidget {
  const UpdateLogScreen({super.key});

  @override
  State<UpdateLogScreen> createState() => _UpdateLogScreenState();
}

class _UpdateLogScreenState extends State<UpdateLogScreen> {
  Future<String>? _future;

  @override
  void initState() {
    super.initState();
    _future = _load();
  }

  Future<String> _load() => rootBundle.loadString('assets/changelog_id.md');

  void _retry() {
    setState(() => _future = _load());
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text(tr('ab_changelog'))),
      body: FutureBuilder<String>(
        future: _future,
        builder: (context, snap) {
          if (snap.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }
          if (snap.hasError || !snap.hasData) {
            return _LogError(onRetry: _retry);
          }
          return _LogBody(text: snap.data ?? '');
        },
      ),
    );
  }
}

/// Status galat baca aset plus tombol coba lagi.
class _LogError extends StatelessWidget {
  final VoidCallback onRetry;

  const _LogError({required this.onRetry});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(SsrSpace.lg),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              tr('w_err_load'),
              style: Theme.of(context).textTheme.bodyMedium,
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: SsrSpace.md),
            OutlinedButton(onPressed: onRetry, child: Text(tr('retry'))),
          ],
        ),
      ),
    );
  }
}

/// Log sebagai kartu per-versi (parse markdown). Bila format tak terbaca,
/// jatuh ke teks polos supaya isi tetap tampil.
class _LogBody extends StatelessWidget {
  final String text;

  const _LogBody({required this.text});

  @override
  Widget build(BuildContext context) {
    final versions = parseChangelog(text);
    if (versions.isEmpty) {
      return SingleChildScrollView(
        padding: const EdgeInsets.all(SsrSpace.lg),
        child: Text(text, style: Theme.of(context).textTheme.bodyMedium),
      );
    }
    return ListView.separated(
      padding: const EdgeInsets.all(SsrSpace.lg),
      itemCount: versions.length,
      separatorBuilder: (_, __) => const SizedBox(height: SsrSpace.md),
      itemBuilder: (_, i) => _VersionCard(
        v: versions[i],
        installed: isInstalledVersion(versions[i], AppInfo.version),
      ),
    );
  }
}

/// Kartu satu versi: judul + daftar poin; versi terpasang diberi aksen
/// (border primer + label).
class _VersionCard extends StatelessWidget {
  final ChangelogVersion v;
  final bool installed;

  const _VersionCard({required this.v, required this.installed});

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return SectionCard(
      borderColor: installed ? scheme.primary : null,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  v.version,
                  style: Theme.of(context).textTheme.titleMedium,
                ),
              ),
              if (installed) ...[
                const SizedBox(width: SsrSpace.sm),
                StatusChip(
                  label: tr('ul_installed'),
                  tone: StatusTone.accent,
                  isSmall: true,
                ),
              ],
            ],
          ),
          if (v.items.isNotEmpty) const SizedBox(height: SsrSpace.sm),
          for (final item in v.items) _Point(text: item),
        ],
      ),
    );
  }
}

/// Satu poin changelog: titik aksen + teks.
class _Point extends StatelessWidget {
  final String text;

  const _Point({required this.text});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: SsrSpace.xs),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.only(top: 6, right: SsrSpace.sm),
            child: Container(
              width: 5,
              height: 5,
              decoration: BoxDecoration(
                color: Theme.of(context).colorScheme.primary,
                shape: BoxShape.circle,
              ),
            ),
          ),
          Expanded(
            child: Text(text, style: Theme.of(context).textTheme.bodyMedium),
          ),
        ],
      ),
    );
  }
}
