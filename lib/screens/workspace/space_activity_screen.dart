import 'package:flutter/material.dart';
import 'package:ssr_space/services/space_logic.dart';
import 'package:ssr_space/services/space_service.dart';
import 'package:ssr_space/services/supabase_config.dart';
import 'package:ssr_space/theme/app_icons.dart';
import 'package:ssr_space/theme/app_theme.dart';
import 'package:ssr_space/theme/dribbble_tokens.dart';
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
      backgroundColor: DribTokens.bgOf(context),
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        title: Text(
          tr('sp_activity'),
          style: Theme.of(context)
              .textTheme
              .titleLarge
              ?.copyWith(fontWeight: FontWeight.w800),
        ),
      ),
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
      separatorBuilder: (_, __) => const SizedBox(height: 16),
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
    final r = actorLabel(row.actorId, myId);
    final actorName = r.$2 ? tr('sp_by_you') : r.$1;
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _ActorAvatar(name: actorName, seed: row.actorId ?? ''),
        const SizedBox(width: 11),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                _titleOf(row),
                style: const TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                  color: DribTokens.navy,
                ),
              ),
              const SizedBox(height: 1),
              Text(
                '${_actorText(row.actorId, myId)} · ${_atLabel(row.at)}',
                style: const TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.w600,
                  color: DribTokens.textSecondary,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}


/// Palet avatar aktor plek frame (warna solid bergiliran deterministik).
const _avatarPalette = [
  Color(0xFF2E6BE6),
  Color(0xFFC2437E),
  Color(0xFFD97316),
  Color(0xFF12805C),
  Color(0xFF6D4BD8),
  Color(0xFF2A7F9E),
];

Color _avatarColorFor(String seed) {
  var h = 0;
  for (final c in seed.codeUnits) {
    h = (h * 31 + c) & 0x7fffffff;
  }
  return _avatarPalette[h % _avatarPalette.length];
}

String _initialsOf(String name) {
  final parts =
      name.trim().split(RegExp(r'\s+')).where((p) => p.isNotEmpty).toList();
  if (parts.isEmpty) return '?';
  if (parts.length == 1) return parts.first[0].toUpperCase();
  return (parts.first[0] + parts[1][0]).toUpperCase();
}

/// Avatar lingkaran 34px warna solid + inisial putih plek frame aktivitas.
class _ActorAvatar extends StatelessWidget {
  final String name;
  final String seed;

  const _ActorAvatar({required this.name, required this.seed});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 34,
      height: 34,
      alignment: Alignment.center,
      decoration: BoxDecoration(
        color: _avatarColorFor(seed),
        shape: BoxShape.circle,
      ),
      child: Text(
        _initialsOf(name),
        style: const TextStyle(
          color: Colors.white,
          fontSize: 10.5,
          fontWeight: FontWeight.w800,
        ),
      ),
    );
  }
}
