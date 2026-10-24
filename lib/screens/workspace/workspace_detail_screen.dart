import 'package:ssr_space/services/pg_trigger_codes.dart';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:ssr_space/screens/workspace/invite_screen.dart';
import 'package:ssr_space/screens/workspace/org_switcher_screen.dart';
import 'package:ssr_space/services/session_service.dart';
import 'package:ssr_space/services/space_service.dart';
import 'package:ssr_space/services/supabase_config.dart';
import 'package:ssr_space/services/workspace_service.dart';
import 'package:ssr_space/theme/app_icons.dart';
import 'package:ssr_space/theme/app_theme.dart';
import 'package:ssr_space/theme/dribbble_tokens.dart';
import 'package:ssr_space/utils/org_prefs.dart';
import 'package:ssr_space/utils/strings.dart';
import 'package:ssr_space/widgets/drib_card.dart';
import 'package:ssr_space/widgets/pin_dialog.dart';
import 'package:ssr_space/widgets/restyle/role_badge.dart';
import 'package:ssr_space/widgets/tx_type_selector.dart';
import 'package:ssr_space/widgets/state_views.dart';

/// Potong ID user untuk tampil (tanpa email/nama, sesuai RPC list).
String shortUid(String id) => id.length <= 8 ? id : id.substring(0, 8);

/// Label peran anggota.
String roleLabel(String role) {
  if (role == 'owner') return tr('org_owner');
  if (role == 'admin') return tr('org_admin');
  return tr('org_member');
}

/// Detail workspace: hero, daftar anggota, zona danger.
/// Org berbentuk map baris switcher (m['organizations'], m['role']).
class WorkspaceDetailScreen extends StatefulWidget {
  final Map<String, dynamic> org;
  final SessionService session;

  const WorkspaceDetailScreen({
    super.key,
    required this.org,
    required this.session,
  });

  @override
  State<WorkspaceDetailScreen> createState() => _WorkspaceDetailState();
}

class _WorkspaceDetailState extends State<WorkspaceDetailScreen> {
  final _service = WorkspaceService();
  final delC = TextEditingController();
  List<OrgMember> members = [];
  bool loading = true;
  bool deleting = false;
  String? loadErr;
  String? kicking;
  String? activeId;
  String _mode = 'bebas';
  bool _switching = false;

  String get _orgId => (widget.org['org_id'] ??
          widget.org['organizations']?['id'] ??
          widget.org['id'] ??
          '')
      .toString();

  String get _name =>
      (widget.org['organizations']?['name'] ?? widget.org['name'] ?? '-')
          .toString();

  String get _myRole => (widget.org['role'] ?? 'member').toString();
  String get _myId => SupabaseConfig.client.auth.currentUser?.id ?? '';
  bool get _canManage => _myRole == 'owner' || _myRole == 'admin';
  bool get _isActiveView => activeId == _orgId;

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void dispose() {
    delC.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    setState(() {
      loading = true;
      loadErr = null;
    });
    final active = await activeOrgId();
    if (!mounted) return;
    try {
      final rows = await _service.members(_orgId);
      final mode = await _service.spaceMode(_orgId);
      if (!mounted) return;
      setState(() {
        members = rows;
        activeId = active;
        _mode = mode;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        activeId = active;
        loadErr = tr('wsm_err');
      });
    } finally {
      if (mounted) setState(() => loading = false);
    }
  }

  void _openInvite() {
    Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => const InviteScreen()),
    );
  }

  Future<void> _kick(OrgMember target) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(tr('wsm_kick_title')),
        content: Text(tr('wsm_kick_body')),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: Text(tr('cancel')),
          ),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: Text(
              tr('wsm_kick'),
              style: TextStyle(color: Theme.of(ctx).colorScheme.error),
            ),
          ),
        ],
      ),
    );
    if (ok != true || !mounted) return;
    setState(() => kicking = target.userId);
    try {
      await _service.kickMember(_orgId, target.userId);
      if (!mounted) return;
      await _load();
    } on PostgrestException catch (e) {
      if (!mounted) return;
      _snack(_kickError(e));
    } catch (_) {
      if (!mounted) return;
      _snack(tr('wsm_err'));
    } finally {
      if (mounted) setState(() => kicking = null);
    }
  }

  String _kickError(PostgrestException e) {
    if (e.code == '42883') return tr('wsm_nomigration');
    if (pgIsKickLastOwner(e)) return tr('wsm_kick_last');
    if (pgIsNotAdmin(e)) return tr('wsm_kick_denied');
    return tr('wsm_err');
  }

  Future<void> _delete() async {
    final ok = await askPinDialog(context);
    if (!ok || !mounted) return;
    setState(() => deleting = true);
    try {
      await _service.deleteWorkspace(_orgId);
      final active = await activeOrgId();
      if (active == _orgId) {
        final prefs = await SharedPreferences.getInstance();
        await prefs.remove('active_org_id');
        await prefs.remove('active_org_name');
      }
      if (!mounted) return;
      Navigator.pushReplacement(
        context,
        MaterialPageRoute(
          builder: (_) => OrgSwitcherScreen(session: widget.session),
        ),
      );
    } on PostgrestException catch (e) {
      if (!mounted) return;
      _snack(_deleteError(e));
    } catch (_) {
      if (!mounted) return;
      _snack(tr('wsm_err'));
    } finally {
      if (mounted) setState(() => deleting = false);
    }
  }

  String _deleteError(PostgrestException e) {
    if (e.code == '42883') return tr('wsm_nomigration');
    if (e.message.contains('NOT_OWNER')) return tr('wsm_delete_denied');
    return tr('wsm_err');
  }

  /// Ganti mode Space: PIN dulu, RPC jalan, tampilan ikut hanya bila sukses.
  Future<void> _switchMode(String next) async {
    if (next == _mode || _switching) return;
    final ok = await askPinDialog(context);
    if (!ok || !mounted) return;
    setState(() => _switching = true);
    try {
      await _service.setSpaceMode(_orgId, next);
      if (!mounted) return;
      setState(() => _mode = next);
    } on SpaceException catch (e) {
      if (!mounted) return;
      _snack(e.message);
    } on PostgrestException catch (e) {
      if (!mounted) return;
      _snack(e.code == '42883' ? tr('wsm_nomigration') : tr('wsm_err'));
    } catch (_) {
      if (!mounted) return;
      _snack(tr('wsm_err'));
    } finally {
      if (mounted) setState(() => _switching = false);
    }
  }

  void _snack(String msg) {
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(msg)));
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: DribTokens.bgOf(context),
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        title: Text(
          _name,
          style: Theme.of(context)
              .textTheme
              .titleLarge
              ?.copyWith(fontWeight: FontWeight.w800),
        ),
        actions: _actions(),
      ),
      body: _body(),
    );
  }

  List<Widget> _actions() {
    if (!_isActiveView) return const [];
    return [
      IconButton(
        tooltip: tr('o_invite'),
        onPressed: _openInvite,
        icon: const DuoIcon(AppIcons.addUser),
      ),
    ];
  }

  Widget _body() {
    if (loading) return LoadingView(label: tr('org_loading'));
    if (loadErr != null) {
      return ErrorView(message: loadErr!, onRetry: _load);
    }
    return _DetailBody(
      name: _name,
      myRole: _myRole,
      members: members,
      myId: _myId,
      canManage: _canManage,
      isActiveView: _isActiveView,
      mode: _mode,
      switching: _switching,
      kicking: kicking,
      delC: delC,
      deleting: deleting,
      onKick: _kick,
      onMode: _switchMode,
      onDeleteChanged: (_) => setState(() {}),
      onDelete: _delete,
    );
  }
}

/// Kolom isi: hero + mode Space + anggota + danger.
class _DetailBody extends StatelessWidget {
  final String name;
  final String myRole;
  final List<OrgMember> members;
  final String myId;
  final bool canManage;
  final bool isActiveView;
  final String mode;
  final bool switching;
  final String? kicking;
  final TextEditingController delC;
  final bool deleting;
  final Future<void> Function(OrgMember m) onKick;
  final ValueChanged<String> onMode;
  final ValueChanged<String> onDeleteChanged;
  final VoidCallback onDelete;

  const _DetailBody({
    required this.name,
    required this.myRole,
    required this.members,
    required this.myId,
    required this.canManage,
    required this.isActiveView,
    required this.mode,
    required this.switching,
    required this.kicking,
    required this.delC,
    required this.deleting,
    required this.onKick,
    required this.onMode,
    required this.onDeleteChanged,
    required this.onDelete,
  });

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.all(SsrSpace.lg),
      children: [
        _DetailHero(name: name, myRole: myRole, count: members.length),
        const SizedBox(height: SsrSpace.lg),
        if (!isActiveView) ...[
          const _InviteNote(),
          const SizedBox(height: SsrSpace.lg),
        ],
        _ModeCard(
          mode: mode,
          switching: switching,
          canManage: canManage,
          onMode: onMode,
        ),
        const SizedBox(height: SsrSpace.lg),
        _MembersCard(
          members: members,
          myId: myId,
          canManage: canManage,
          kicking: kicking,
          onKick: onKick,
        ),
        if (myRole == 'owner') ...[
          const SizedBox(height: SsrSpace.lg),
          _DangerCard(
            name: name,
            delC: delC,
            deleting: deleting,
            onChanged: onDeleteChanged,
            onDelete: onDelete,
          ),
        ],
      ],
    );
  }
}

/// Mode Space: Bebas vs Bendahara. Ubah hanya owner/admin + PIN (di state).
class _ModeCard extends StatelessWidget {
  final String mode;
  final bool switching;
  final bool canManage;
  final ValueChanged<String> onMode;

  const _ModeCard({
    required this.mode,
    required this.switching,
    required this.canManage,
    required this.onMode,
  });

  @override
  Widget build(BuildContext context) {
    return DribCard(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            tr('sp_mode'),
            style: const TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w800,
              color: DribTokens.navy,
            ),
          ),
          const SizedBox(height: 10),
          SegmentedButton<String>(
            style: ssrSegmentedStyle(context),
            segments: [
              ButtonSegment(value: 'bebas', label: Text(tr('sp_bebas'))),
              ButtonSegment(
                  value: 'bendahara', label: Text(tr('sp_bendahara'))),
            ],
            selected: {mode},
            showSelectedIcon: false,
            onSelectionChanged:
                canManage && !switching ? (s) => onMode(s.first) : null,
          ),
          const SizedBox(height: 8),
          Text(
            tr('sp_mode_desc'),
            style: const TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.w600,
              color: DribTokens.textSecondary,
            ),
          ),
          if (mode == 'bendahara' && canManage) ...[
            const SizedBox(height: 4),
            Text(
              tr('sp_bendahara_hint'),
              style: const TextStyle(
                fontSize: 11,
                fontWeight: FontWeight.w600,
                color: DribTokens.textSecondary,
              ),
            ),
          ],
        ],
      ),
    );
  }
}

/// Hero: nama workspace + chip peran + jumlah anggota.
class _DetailHero extends StatelessWidget {
  final String name;
  final String myRole;
  final int count;

  const _DetailHero({
    required this.name,
    required this.myRole,
    required this.count,
  });

  @override
  Widget build(BuildContext context) {
    return DribCard(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 16),
      child: Column(
        children: [
          _WorkspaceAvatar(name: name),
          const SizedBox(height: 10),
          Text(
            name,
            textAlign: TextAlign.center,
            style: const TextStyle(
              fontSize: 15.5,
              fontWeight: FontWeight.w800,
              color: DribTokens.navy,
            ),
          ),
          const SizedBox(height: 8),
          Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              RoleBadge(role: roleLabel(myRole), roleKey: myRole),
              const SizedBox(width: 8),
              Text(
                '$count ${tr('wsm_members')}',
                style: const TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.w600,
                  color: DribTokens.textSecondary,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

/// Catatan pengganti tombol undang saat workspace yang dilihat bukan aktif.
class _InviteNote extends StatelessWidget {
  const _InviteNote();

  @override
  Widget build(BuildContext context) {
    return Text(
      tr('wsm_invite_active'),
      style: Theme.of(context).textTheme.bodySmall,
    );
  }
}

/// Daftar anggota: satu baris per user, berdivider.
class _MembersCard extends StatelessWidget {
  final List<OrgMember> members;
  final String myId;
  final bool canManage;
  final String? kicking;
  final Future<void> Function(OrgMember m) onKick;

  const _MembersCard({
    required this.members,
    required this.myId,
    required this.canManage,
    required this.kicking,
    required this.onKick,
  });

  @override
  Widget build(BuildContext context) {
    return DribCard(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            tr('wsm_members'),
            style: const TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w800,
              color: DribTokens.navy,
            ),
          ),
          for (var i = 0; i < members.length; i++) ...[
            const Divider(height: 1, color: DribTokens.border),
            _MemberRow(
              m: members[i],
              isSelf: members[i].userId == myId,
              canKick: canManage && members[i].userId != myId,
              kicking: kicking == members[i].userId,
              onKick: () => onKick(members[i]),
            ),
          ],
        ],
      ),
    );
  }
}

/// Satu baris anggota: avatar, nama, chip peran, tombol keluarkan.
class _MemberRow extends StatelessWidget {
  final OrgMember m;
  final bool isSelf;
  final bool canKick;
  final bool kicking;
  final VoidCallback onKick;

  const _MemberRow({
    required this.m,
    required this.isSelf,
    required this.canKick,
    required this.kicking,
    required this.onKick,
  });

  @override
  Widget build(BuildContext context) {
    final short = shortUid(m.userId);
    final label = isSelf ? '${tr('wsm_you')} ($short)' : short;
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: SsrSpace.sm),
      child: Row(
        children: [
          _MemberAvatar(short: short),
          const SizedBox(width: SsrSpace.md),
          Expanded(
            child: Text(
              label,
              style: const TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w700,
                color: DribTokens.navy,
              ),
            ),
          ),
          RoleBadge(role: roleLabel(m.role), roleKey: m.role),
          if (canKick) ...[
            const SizedBox(width: SsrSpace.xs),
            _KickAction(kicking: kicking, onKick: onKick),
          ],
        ],
      ),
    );
  }
}

/// Lingkaran inisial dari ID terpotong.
class _MemberAvatar extends StatelessWidget {
  final String short;
  const _MemberAvatar({required this.short});

  @override
  Widget build(BuildContext context) {
    final initial = short.isEmpty ? '?' : short[0].toUpperCase();
    return Container(
      width: 38,
      height: 38,
      alignment: Alignment.center,
      decoration: BoxDecoration(
        color: _memberColorFor(short),
        shape: BoxShape.circle,
      ),
      child: Text(
        initial,
        style: const TextStyle(
          color: Colors.white,
          fontWeight: FontWeight.w800,
          fontSize: 12,
        ),
      ),
    );
  }
}

/// Tombol keluarkan atau spinner saat RPC jalan.
class _KickAction extends StatelessWidget {
  final bool kicking;
  final VoidCallback onKick;
  const _KickAction({required this.kicking, required this.onKick});

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 36,
      child: kicking
          ? const Padding(
              padding: EdgeInsets.all(8),
              child: SizedBox(
                width: 20,
                height: 20,
                child: CircularProgressIndicator(strokeWidth: 2),
              ),
            )
          : TextButton(
              style: TextButton.styleFrom(
                foregroundColor: Theme.of(context).colorScheme.error,
              ),
              onPressed: onKick,
              child: Text(tr('wsm_kick')),
            ),
    );
  }
}

/// Zona danger: ketik nama persis lalu hapus via PIN.
class _DangerCard extends StatelessWidget {
  final String name;
  final TextEditingController delC;
  final bool deleting;
  final ValueChanged<String> onChanged;
  final VoidCallback onDelete;

  const _DangerCard({
    required this.name,
    required this.delC,
    required this.deleting,
    required this.onChanged,
    required this.onDelete,
  });

  @override
  Widget build(BuildContext context) {
    final ready = delC.text == name;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      decoration: BoxDecoration(
        color: DribTokens.cardOf(context),
        borderRadius: BorderRadius.circular(DribTokens.cardRadius),
        boxShadow: DribTokens.cardShadow,
        border: Border.all(color: DribTokens.error.withValues(alpha: 0.45)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            tr('wsm_danger'),
            style: const TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w800,
              color: DribTokens.errorText,
            ),
          ),
          const SizedBox(height: SsrSpace.sm),
          Text(
            tr('wsm_delete_body'),
            style: const TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w600,
              color: DribTokens.textSecondary,
            ),
          ),
          const SizedBox(height: SsrSpace.md),
          TextField(
            controller: delC,
            onChanged: onChanged,
            enabled: !deleting,
            decoration: InputDecoration(hintText: tr('wsm_delete_hint')),
          ),
          const SizedBox(height: SsrSpace.lg),
          _DeleteButton(ready: ready, deleting: deleting, onDelete: onDelete),
        ],
      ),
    );
  }
}

/// Tombol hapus workspace (bata, penuh, nonaktif hingga nama cocok).
class _DeleteButton extends StatelessWidget {
  final bool ready;
  final bool deleting;
  final VoidCallback onDelete;
  const _DeleteButton({
    required this.ready,
    required this.deleting,
    required this.onDelete,
  });

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: double.infinity,
      height: 48,
      child: ElevatedButton(
        style: ElevatedButton.styleFrom(
          backgroundColor: const Color(0xFFFBDCDD),
          foregroundColor: DribTokens.errorText,
          elevation: 0,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
          ),
          textStyle: const TextStyle(
            fontSize: 13,
            fontWeight: FontWeight.w800,
          ),
        ),
        onPressed: ready && !deleting ? onDelete : null,
        child: deleting
            ? const SizedBox(
                width: 22,
                height: 22,
                child: CircularProgressIndicator(
                  strokeWidth: 2.4,
                  color: DribTokens.errorText,
                ),
              )
            : Text(tr('wsm_delete')),
      ),
    );
  }
}


/// Palet avatar anggota plek frame (warna solid bergiliran deterministik).
const _memberPalette = [
  Color(0xFF2E6BE6),
  Color(0xFFC2437E),
  Color(0xFFD97316),
  Color(0xFF12805C),
  Color(0xFF6D4BD8),
  Color(0xFF2A7F9E),
];

Color _memberColorFor(String seed) {
  var h = 0;
  for (final c in seed.codeUnits) {
    h = (h * 31 + c) & 0x7fffffff;
  }
  return _memberPalette[h % _memberPalette.length];
}

String _initialsOf(String name) {
  final parts =
      name.trim().split(RegExp(r'\s+')).where((p) => p.isNotEmpty).toList();
  if (parts.isEmpty) return '?';
  if (parts.length == 1) return parts.first[0].toUpperCase();
  return (parts.first[0] + parts[1][0]).toUpperCase();
}

/// Avatar besar gradient navy + inisial nama workspace plek frame detail.
class _WorkspaceAvatar extends StatelessWidget {
  final String name;

  const _WorkspaceAvatar({required this.name});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 62,
      height: 62,
      alignment: Alignment.center,
      decoration: const BoxDecoration(
        gradient: DribTokens.balanceGradient,
        shape: BoxShape.circle,
      ),
      child: Text(
        _initialsOf(name),
        style: const TextStyle(
          color: Colors.white,
          fontSize: 18,
          fontWeight: FontWeight.w800,
        ),
      ),
    );
  }
}
