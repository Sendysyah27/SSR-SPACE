import 'package:flutter/material.dart';
import 'package:ssr_space/services/space_logic.dart';
import 'package:ssr_space/services/space_service.dart';
import 'package:ssr_space/services/supabase_config.dart';
import 'package:ssr_space/theme/app_icons.dart';
import 'package:ssr_space/theme/app_theme.dart';
import 'package:ssr_space/utils/datetime.dart';
import 'package:ssr_space/utils/mask.dart';
import 'package:ssr_space/utils/org_prefs.dart';
import 'package:ssr_space/utils/strings.dart';
import 'package:ssr_space/widgets/state_views.dart';

/// Teks utama per event audit. Nominal via amt() (ikut privacy-mask),
/// pencatat tanpa nama/email (ikut pola list_org_members).
String _titleOf(SpaceActivity a) {
  final amount = a.meta['amount'];
  final nominal = amount is num ? amt(amount) : null;
  switch (a.event) {
    case 'tx_manual_insert':
    case 'tx_auto_insert':
      final kind = a.meta['type'] == 'in' ? tr('tx_in') : tr('tx_out');
      final cat = (a.meta['category'] ?? '').toString();
      final head = nominal == null ? kind : '$kind: $nominal';
      return cat.isEmpty ? head : '$head · $cat';
    case 'org_join':
      final role = (a.meta['role'] ?? '').toString();
      return role.isEmpty ? tr('o_invite') : '${tr('o_invite')} · $role';
    case 'space_mode_change':
      final m = (a.meta['mode'] ?? '').toString();
      return '${tr('sp_mode')}: ${m == 'bendahara' ? tr('sp_bendahara') : tr('sp_bebas')}';
    case 'member_kick':
      return tr('wsm_kick');
    default:
      return a.event;
  }
}

String _actorText(String? actorId, String myId) {
  final r = actorLabel(actorId, myId);
  return r.$2 ? tr('sp_by_you') : tr('sp_by_member').replaceFirst('{s}', r.$1);
}

String _atLabel(DateTime at) {
  final iso = at.toIso8601String();
  return txWhenLabel(iso.length >= 10 ? iso.substring(0, 10) : null, iso);
}

IconData _iconOf(String event) {
  switch (event) {
    case 'tx_manual_insert':
    case 'tx_auto_insert':
      return AppIcons.history;
    case 'org_join':
      return AppIcons.invite;
    case 'space_mode_change':
      return AppIcons.workspace;
    case 'member_kick':
      return AppIcons.error;
    default:
      return AppIcons.menu;
  }
}

/// Aktivitas Space: siapa–apa–kapan dari audit_logs. Dibuka → markSeen
/// (penanda "baru" di hub hilang). Tanpa nama/email siapa pun.
class SpaceActivityScreen extends StatefulWidget {
  const SpaceActivityScreen({super.key});

  @override
  State<SpaceActivityScreen> createState() => _SpaceActivityState();
}

class _SpaceActivityState extends State<SpaceActivityScreen> {
  final _service = SpaceService();
  List<SpaceActivity> _rows = [];
  bool _loading = true;
  String? _err;

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _err = null;
    });
    try {
      final orgId = await activeOrgId();
      final rows = await _service.activity(orgId);
      await _service.markSeen(orgId);
      if (!mounted) return;
      setState(() => _rows = rows);
    } catch (_) {
      if (!mounted) return;
      setState(() => _err = tr('conn_error'));
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  Widget build(BuildContext context) {
    final myId = SupabaseConfig.client.auth.currentUser?.id ?? '';
    return Scaffold(
      appBar: AppBar(title: Text(tr('sp_activity'))),
      body: _body(myId),
    );
  }

  Widget _body(String myId) {
    if (_loading) return LoadingView(label: tr('reload'));
    if (_err != null) return ErrorView(message: _err!, onRetry: _load);
    if (_rows.isEmpty) {
      return EmptyView(
        icon: AppIcons.history,
        illustration: 'assets/illustrations/empty_riwayat.svg',
        title: tr('sp_activity'),
        subtitle: tr('sp_mode_desc'),
        actionLabel: tr('reload'),
        onAction: _load,
      );
    }
    return ListView.separated(
      padding: const EdgeInsets.all(SsrSpace.lg),
      itemCount: _rows.length,
      separatorBuilder: (_, __) => const Divider(height: 1),
      itemBuilder: (_, i) => _ActivityTile(row: _rows[i], myId: myId),
    );
  }
}

class _ActivityTile extends StatelessWidget {
  final SpaceActivity row;
  final String myId;

  const _ActivityTile({required this.row, required this.myId});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return ListTile(
      contentPadding: const EdgeInsets.symmetric(vertical: 6),
      leading: DuoIcon(_iconOf(row.event), size: 20),
      title: Text(_titleOf(row), style: theme.textTheme.titleSmall),
      subtitle: Text(
        '${_actorText(row.actorId, myId)} · ${_atLabel(row.at)}',
        style: theme.textTheme.bodySmall,
      ),
    );
  }
}
