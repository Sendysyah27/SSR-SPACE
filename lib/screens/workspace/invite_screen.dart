import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:share_plus/share_plus.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:ssr_space/services/invite_service.dart';
import 'package:ssr_space/services/invite_token.dart';
import 'package:ssr_space/services/billing_service.dart';
import 'package:ssr_space/services/plan_limits.dart';
import 'package:ssr_space/theme/app_icons.dart';
import 'package:ssr_space/theme/app_theme.dart';
import 'package:ssr_space/widgets/primary_button.dart';
import 'package:ssr_space/widgets/section_card.dart';
import 'package:ssr_space/widgets/skeletons.dart';
import 'package:ssr_space/widgets/state_views.dart';
import 'package:ssr_space/widgets/status_chip.dart';
import 'package:ssr_space/utils/strings.dart';

class InviteScreen extends StatefulWidget {
  const InviteScreen({super.key});

  @override
  State<InviteScreen> createState() => _InviteScreenState();
}

class _InviteScreenState extends State<InviteScreen> {
  final _service = InviteService();
  List<Map<String, dynamic>> invites = [];
  String orgId = '';
  String orgName = '';
  bool loading = true;
  bool creating = false;
  String? loadErr;
  String? role = 'member';
  bool isAdmin = false;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() {
      loading = true;
      loadErr = null;
      isAdmin = false;
    });
    final prefs = await SharedPreferences.getInstance();
    orgId = prefs.getString('active_org_id') ?? '';
    orgName = prefs.getString('active_org_name') ?? '';
    if (orgId.isEmpty) {
      setState(() {
        loading = false;
        invites = [];
      });
      return;
    }
    try {
      final myRole = await _service.myRole(orgId);
      final admin = myRole == 'owner' || myRole == 'admin';
      if (!mounted) return;
      if (!admin) {
        setState(() {
          isAdmin = false;
          invites = [];
        });
        return;
      }
      setState(() => isAdmin = true);
      final rows = await _service.listInvites(orgId);
      if (!mounted) return;
      setState(() => invites = rows);
    } catch (_) {
      if (!mounted) return;
      setState(() => loadErr = tr('iv_err_load'));
    } finally {
      if (mounted) setState(() => loading = false);
    }
  }

  Future<void> _create() async {
    if (creating) return;
    setState(() => creating = true);
    try {
      final plan = await currentPlan(orgId);
      final members = await memberCount(orgId);
      if (!canInvite(plan: plan, members: members)) {
        if (!mounted) return;
        setState(() => creating = false);
        await requirePro(
          context,
          tr('q_members').replaceFirst('{n}', '${PlanLimits.freeMembers}'),
        );
        return;
      }
      final res = await _service.createInvite(
        orgId: orgId,
        role: role ?? 'member',
      );
      if (!mounted) return;
      await _showTokenDialog(res.token);
      await _load();
    } catch (err) {
      if (!mounted) return;
      final msg = err is InviteException ? err.message : tr('iv_err_create');
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(msg)));
    } finally {
      if (mounted) setState(() => creating = false);
    }
  }

  Future<void> _showTokenDialog(String token) async {
    await showDialog<void>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(tr('iv_code')),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(tr('iv_share_once'), style: Theme.of(ctx).textTheme.bodySmall),
            const SizedBox(height: SsrSpace.md),
            SelectableText(
              token,
              style: Theme.of(ctx).textTheme.titleMedium
                  ?.copyWith(fontFamily: 'monospace', letterSpacing: 1.2),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () async {
              await Clipboard.setData(ClipboardData(text: token));
              if (ctx.mounted) {
                ScaffoldMessenger.of(ctx)
                    .showSnackBar(SnackBar(content: Text(tr('iv_copied'))));
              }
            },
            child: Text(tr('iv_copy')),
          ),
          TextButton(
            onPressed: () {
              Share.share(tr('iv_share_text').replaceFirst('{c}', token));
            },
            child: Text(tr('iv_share')),
          ),
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: Text(tr('iv_done')),
          ),
        ],
      ),
    );
  }

  Future<void> _revoke(Map<String, dynamic> row) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(tr('iv_revoke_t')),
        content: Text(tr('iv_revoke_b')),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: Text(tr('cancel')),
          ),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: Text(tr('iv_revoke')),
          ),
        ],
      ),
    );
    if (ok != true) return;
    try {
      await _service.revokeInvite(row['id'].toString());
      await _load();
    } catch (_) {
      if (!mounted) return;
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text(tr('iv_revoke_fail'))));
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text(tr('o_invite'))),
      body: loading
          ? const InviteListSkeleton()
          : loadErr != null
          ? ErrorView(message: loadErr!, onRetry: _load)
          : orgId.isEmpty
          ? EmptyView(
              icon: AppIcons.workspace,
              title: tr('iv_noorg_t'),
              subtitle: tr('iv_noorg_s'),
              actionLabel: tr('reload'),
              onAction: _load,
            )
          : !isAdmin
          ? EmptyView(
              icon: AppIcons.lock,
              title: tr('iv_notadmin_t'),
              subtitle: tr('iv_notadmin_s'),
              actionLabel: tr('reload'),
              onAction: _load,
            )
          : ListView(
              padding: const EdgeInsets.all(SsrSpace.lg),
              children: [
                _InviteCreateCard(
                  orgName: orgName,
                  role: role,
                  creating: creating,
                  canCreate: orgId.isNotEmpty,
                  onRoleChanged: (v) => setState(() => role = v ?? 'member'),
                  onCreate: _create,
                ),
                const SizedBox(height: SsrSpace.lg),
                _InviteListCard(invites: invites, onRevoke: _revoke),
              ],
            ),
    );
  }
}

/// Kartu "buat undangan": nama workspace, deskripsi, pilih peran, tombol.
class _InviteCreateCard extends StatelessWidget {
  final String orgName;
  final String? role;
  final bool creating;
  final bool canCreate;
  final ValueChanged<String?> onRoleChanged;
  final VoidCallback onCreate;

  const _InviteCreateCard({
    required this.orgName,
    required this.role,
    required this.creating,
    required this.canCreate,
    required this.onRoleChanged,
    required this.onCreate,
  });

  @override
  Widget build(BuildContext context) {
    return SectionCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            orgName.isEmpty ? tr('iv_noorg_t') : orgName,
            style: Theme.of(context).textTheme.titleMedium,
          ),
          const SizedBox(height: SsrSpace.sm),
          Text(
            tr('iv_share_hint'),
            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
              color: Theme.of(context).textTheme.bodySmall?.color,
            ),
          ),
          const SizedBox(height: SsrSpace.md),
          DropdownButtonFormField<String>(
            initialValue: role,
            decoration: InputDecoration(labelText: tr('iv_role')),
            items: [
              DropdownMenuItem(value: 'member', child: Text(tr('iv_member'))),
              DropdownMenuItem(value: 'admin', child: Text(tr('iv_admin'))),
            ],
            onChanged: onRoleChanged,
          ),
          const SizedBox(height: SsrSpace.lg),
          PrimaryButton(
            label: tr('iv_create'),
            loading: creating,
            onPressed: canCreate ? onCreate : null,
          ),
        ],
      ),
    );
  }
}

/// Daftar undangan aktif (atau pesan kosong): satu baris per kode.
class _InviteListCard extends StatelessWidget {
  final List<Map<String, dynamic>> invites;
  final Future<void> Function(Map<String, dynamic> row) onRevoke;

  const _InviteListCard({required this.invites, required this.onRevoke});

  static String _status(Map<String, dynamic> row) {
    // Fail-closed: tanggal rusak/tak terbaca = anggap kedaluwarsa,
    // jangan pernah lempar (baris sampah tak boleh crash layar).
    final expires = tryParseInviteDate(row['expires_at']);
    if (expires == null) return tr('iv_st_expired');
    return inviteStatusLabel(
      expiresAt: expires,
      revoked: row['revoked'] == true,
      usedCount: (row['used_count'] as num?)?.toInt() ?? 0,
      maxUses: (row['max_uses'] as num?)?.toInt() ?? 1,
      now: DateTime.now(),
    );
  }

  static StatusTone _tone(String status) {
    if (status == tr('iv_st_active')) return StatusTone.accent;
    if (status == tr('iv_st_used')) return StatusTone.neutral;
    return StatusTone.danger;
  }

  Widget _inviteRow(BuildContext context, Map<String, dynamic> row) {
    final status = _status(row);
    final canRevoke = status == tr('iv_st_active');
    final remaining =
        ((row['max_uses'] as num?)?.toInt() ?? 1) -
        ((row['used_count'] as num?)?.toInt() ?? 0);
    final roleName = row['role'] == 'admin' ? tr('iv_admin') : tr('iv_member');
    final createdAt = tryParseInviteDate(row['created_at']);
    final createdLabel = createdAt == null
        ? '–'
        : '${createdAt.day.toString().padLeft(2, '0')}/'
            '${createdAt.month.toString().padLeft(2, '0')}';
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: SsrSpace.sm),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Undangan $createdLabel',
                  style: Theme.of(context).textTheme.titleSmall,
                ),
                const SizedBox(height: 2),
                Text(
                  '$roleName · ${tr('iv_remaining').replaceFirst('{n}', '$remaining')}',
                  style: Theme.of(context).textTheme.bodySmall,
                ),
              ],
            ),
          ),
          StatusChip(label: status, tone: _tone(status)),
          if (canRevoke) ...[
            const SizedBox(width: SsrSpace.xs),
            IconButton(
              tooltip: tr('iv_unrevoke'),
              onPressed: () => onRevoke(row),
              icon: const DuoIcon(AppIcons.revoke, size: 20),
            ),
          ],
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    if (invites.isEmpty) {
      return SectionCard(
        child: Column(
          children: [
            SvgPicture.asset(
              'assets/illustrations/empty_undangan.svg',
              height: 100,
              fit: BoxFit.contain,
            ),
            const SizedBox(height: SsrSpace.md),
            Text(
              tr('iv_list_empty'),
              textAlign: TextAlign.center,
              style: Theme.of(context).textTheme.bodyMedium,
            ),
          ],
        ),
      );
    }
    return SectionCard(
      padding: const EdgeInsets.symmetric(
        horizontal: SsrSpace.md,
        vertical: SsrSpace.xs,
      ),
      child: Column(
        children: [
          for (var i = 0; i < invites.length; i++) ...[
            if (i > 0) const Divider(height: 1),
            _inviteRow(context, invites[i]),
          ],
        ],
      ),
    );
  }
}
