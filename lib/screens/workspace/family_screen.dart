import 'package:flutter/material.dart';
import 'package:ssr_space/services/family_summary.dart';
import 'package:ssr_space/services/invite_service.dart';
import 'package:ssr_space/services/month.dart';
import 'package:ssr_space/services/space_logic.dart';
import 'package:ssr_space/services/supabase_config.dart';
import 'package:ssr_space/services/transaction_service.dart';
import 'package:ssr_space/services/workspace_service.dart';
import 'package:ssr_space/screens/workspace/invite_screen.dart';
import 'package:ssr_space/theme/app_icons.dart';
import 'package:ssr_space/theme/app_theme.dart';
import 'package:ssr_space/utils/mask.dart';
import 'package:ssr_space/utils/org_prefs.dart';
import 'package:ssr_space/utils/strings.dart';
import 'package:ssr_space/widgets/section_card.dart';
import 'package:ssr_space/widgets/skeletons.dart';
import 'package:ssr_space/widgets/state_views.dart';
import 'package:ssr_space/widgets/status_chip.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

/// Anggota workspace + belanja per anggota bulan berjalan.
/// Undang via layar invite existing; kick via RPC existing (owner/admin).
class FamilyScreen extends StatefulWidget {
  const FamilyScreen({super.key});

  @override
  State<FamilyScreen> createState() => FamilyScreenState();
}

class FamilyScreenState extends State<FamilyScreen> {
  bool loading = true;
  bool loadFailed = false;
  bool noOrg = false;
  List<OrgMember> members = [];
  String myRole = 'member';
  String myId = '';
  Map<String, MemberTotal> totals = {};
  double monthIn = 0;
  double monthOut = 0;
  String? kicking;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() {
      loading = true;
      loadFailed = false;
      noOrg = false;
    });
    final orgId = await activeOrgId();
    if (orgId.isEmpty) {
      if (!mounted) return;
      setState(() {
        loading = false;
        noOrg = true;
      });
      return;
    }
    try {
      final svc = WorkspaceService();
      final fetched = await svc.members(orgId);
      final role = await InviteService().myRole(orgId);
      final month = currentMonth();
      final txs = await TransactionService().listMonth(orgId, month);
      final sums = memberMonthTotals(
        [
          for (final t in txs)
            MemberTx(
              type: t.type,
              amount: t.amount,
              createdBy: t.createdBy,
              date: t.date ?? '',
            ),
        ],
        month,
      );
      var tin = 0.0;
      var tout = 0.0;
      for (final t in txs) {
        if (t.type == 'in') {
          tin += t.amount;
        } else if (t.type == 'out') {
          tout += t.amount;
        }
      }
      if (!mounted) return;
      setState(() {
        loading = false;
        members = fetched;
        myRole = role;
        myId = SupabaseConfig.client.auth.currentUser?.id ?? '';
        totals = sums;
        monthIn = tin;
        monthOut = tout;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        loading = false;
        loadFailed = true;
      });
    }
  }

  bool get _canManage => myRole == 'owner' || myRole == 'admin';

  Future<void> _kick(OrgMember target) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        title: Text(tr('wsm_kick_title')),
        content: Text(tr('wsm_kick_body')),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: Text(tr('cancel')),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: Text(
              tr('wsm_kick'),
              style: TextStyle(color: Theme.of(context).colorScheme.error),
            ),
          ),
        ],
      ),
    );
    if (ok != true || !mounted) return;
    setState(() => kicking = target.userId);
    try {
      final orgId = await activeOrgId();
      await WorkspaceService().kickMember(orgId, target.userId);
      if (!mounted) return;
      await _load();
    } on PostgrestException catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(_kickError(e))),
      );
    } catch (_) {
      if (!mounted) return;
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text(tr('fam_kick_fail'))));
    } finally {
      if (mounted) setState(() => kicking = null);
    }
  }

  String _kickError(PostgrestException e) {
    if (e.code == '42883') return tr('wsm_nomigration');
    if (e.message.contains('KICK_LAST_OWNER')) return tr('wsm_kick_last');
    if (e.message.contains('NOT_ADMIN')) return tr('wsm_kick_denied');
    return tr('fam_kick_fail');
  }

  String _roleLabel(String role) {
    if (role == 'owner') return tr('org_owner');
    if (role == 'admin') return tr('org_admin');
    return tr('org_member');
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text(tr('fam_title'))),
      floatingActionButton: (loading || loadFailed || noOrg)
          ? null
          : FloatingActionButton(
              onPressed: () => Navigator.push(
                context,
                MaterialPageRoute(builder: (_) => const InviteScreen()),
              ),
              child: const DuoIcon(AppIcons.invite),
            ),
      body: _body(),
    );
  }

  Widget _body() {
    if (loading) return const TxListSkeleton();
    if (noOrg) {
      return EmptyView(
        icon: AppIcons.workspace,
        title: tr('tx_no_org_t'),
        subtitle: tr('tx_no_org_s'),
        actionLabel: tr('reload'),
        onAction: _load,
      );
    }
    if (loadFailed) {
      return ErrorView(message: tr('tx_err_load'), onRetry: _load);
    }
    if (members.isEmpty) {
      return EmptyView(
        icon: AppIcons.members,
        title: tr('fam_empty_t'),
        subtitle: tr('fam_empty_s'),
        actionLabel: tr('o_invite'),
        onAction: () => Navigator.push(
          context,
          MaterialPageRoute(builder: (_) => const InviteScreen()),
        ),
      );
    }
    return ListView(
      padding: const EdgeInsets.all(SsrSpace.lg),
      children: [
        _SummaryCard(monthIn: monthIn, monthOut: monthOut),
        const SizedBox(height: SsrSpace.md),
        for (final m in members) _memberTile(m),
      ],
    );
  }

  Widget _memberTile(OrgMember m) {
    final isMe = m.userId == myId;
    final r = actorLabel(m.userId, myId);
    final name = r.$2 ? tr('sp_by_you') : r.$1;
    final t = totals[m.userId];
    final canKick = _canManage && !isMe && kicking == null;
    return SectionCard(
      margin: const EdgeInsets.only(bottom: SsrSpace.md),
      child: Row(
        children: [
          CircleAvatar(
            child: Text(name.isEmpty ? '?' : name[0].toUpperCase()),
          ),
          const SizedBox(width: SsrSpace.md),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        name,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: Theme.of(context).textTheme.titleSmall,
                      ),
                    ),
                    StatusChip(
                      label: _roleLabel(m.role),
                      tone: m.role == 'member'
                          ? StatusTone.neutral
                          : StatusTone.accent,
                    ),
                  ],
                ),
                const SizedBox(height: 2),
                Text(
                  t == null
                      ? tr('fam_notx')
                      : '${tr('tx_out')} ${amt(t.outTotal)} · '
                          '${tr('tx_in')} ${amt(t.inTotal)} · '
                          '${t.count}x',
                  style: Theme.of(context).textTheme.bodySmall,
                ),
              ],
            ),
          ),
          if (canKick)
            IconButton(
              icon: const DuoIcon(AppIcons.trash),
              tooltip: tr('wsm_kick'),
              onPressed: () => _kick(m),
            ),
          if (kicking == m.userId)
            const SizedBox(
              width: 24,
              height: 24,
              child: CircularProgressIndicator(strokeWidth: 2),
            ),
        ],
      ),
    );
  }
}

/// Total workspace bulan berjalan.
class _SummaryCard extends StatelessWidget {
  final double monthIn;
  final double monthOut;

  const _SummaryCard({required this.monthIn, required this.monthOut});

  @override
  Widget build(BuildContext context) {
    return SectionCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(tr('fam_sub'), style: Theme.of(context).textTheme.bodySmall),
          const SizedBox(height: 4),
          Text(
            '${tr('tx_in')} ${amt(monthIn)} · ${tr('tx_out')} ${amt(monthOut)}',
            style: Theme.of(context).textTheme.titleSmall?.copyWith(
              fontFeatures: const [FontFeature.tabularFigures()],
            ),
          ),
        ],
      ),
    );
  }
}
