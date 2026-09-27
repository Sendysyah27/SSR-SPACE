import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:uuid/uuid.dart';
import 'package:ssr_space/utils/org_prefs.dart';
import 'package:ssr_space/services/billing_service.dart';
import 'package:ssr_space/services/invite_service.dart';
import 'package:ssr_space/services/plan_limits.dart';
import 'package:ssr_space/services/supabase_config.dart';
import 'package:ssr_space/services/session_service.dart';
import 'package:ssr_space/utils/strings.dart';
import 'package:ssr_space/theme/app_icons.dart';
import 'package:ssr_space/theme/app_theme.dart';
import 'package:ssr_space/screens/shell/main_shell.dart';
import 'package:ssr_space/screens/workspace/workspace_detail_screen.dart';
import 'package:ssr_space/widgets/primary_button.dart';
import 'package:ssr_space/widgets/section_card.dart';
import 'package:ssr_space/widgets/state_views.dart';
import 'package:ssr_space/widgets/status_chip.dart';

class OrgSwitcherScreen extends StatefulWidget {
  final SessionService session;
  const OrgSwitcherScreen({super.key, required this.session});
  @override
  State<OrgSwitcherScreen> createState() => _OrgSwitcherScreenState();
}

class _OrgSwitcherScreenState extends State<OrgSwitcherScreen> {
  List<Map<String, dynamic>> orgs = [];
  bool loading = true;
  bool busy = false;
  String? loadErr;
  String? formErr;
  String? joinErr;
  final nameC = TextEditingController();
  final nameFocus = FocusNode();
  final joinC = TextEditingController();

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void dispose() {
    nameC.dispose();
    nameFocus.dispose();
    joinC.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    setState(() {
      loading = true;
      loadErr = null;
    });
    try {
      final uid = SupabaseConfig.client.auth.currentUser!.id;
      final rows = await SupabaseConfig.client
          .from('org_members')
          .select('org_id, role, organizations(id, name, plan)')
          .eq('user_id', uid);
      setState(() => orgs = List<Map<String, dynamic>>.from(rows));
    } catch (_) {
      setState(() => orgs = []);
      loadErr = tr('org_err_load');
    } finally {
      setState(() => loading = false);
    }
  }

  Future<void> _create() async {
    if (busy) return;
    final name = nameC.text.trim();
    if (name.isEmpty) {
      setState(() => formErr = tr('org_err_name'));
      return;
    }
    setState(() {
      busy = true;
      formErr = null;
    });
    try {
      final activeId = await activeOrgId();
      final plan = activeId.isEmpty ? 'free' : await currentPlan(activeId);
      if (!canCreateWorkspace(plan: plan, joined: orgs.length)) {
        if (!mounted) return;
        setState(() => busy = false);
        await requirePro(
          context,
          tr('q_ws').replaceFirst('{n}', '${PlanLimits.freeWorkspaces}'),
        );
        return;
      }
      final c = SupabaseConfig.client;
      final uid = c.auth.currentUser!.id;
      final newId = const Uuid().v4();
      await c.from('organizations').insert({
        'id': newId,
        'name': name,
        'created_by': uid,
      });
      await c.from('org_members').insert({
        'org_id': newId,
        'user_id': uid,
        'role': 'owner',
      });
      nameC.clear();
      await _select({'id': newId, 'name': name});
    } catch (_) {
      formErr = tr('org_err_create');
    } finally {
      if (mounted) setState(() => busy = false);
    }
  }

  Future<void> _join() async {
    if (busy) return;
    final code = joinC.text.trim();
    if (code.isEmpty) {
      setState(() => joinErr = tr('org_err_code'));
      return;
    }
    setState(() {
      busy = true;
      joinErr = null;
    });
    try {
      await InviteService().join(code);
      joinC.clear();
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(tr('org_joined'))),
      );
      await _load();
    } on InviteException catch (err) {
      if (!mounted) return;
      setState(() => joinErr = err.message);
    } catch (_) {
      if (!mounted) return;
      setState(() => joinErr = tr('org_err_join'));
    } finally {
      if (mounted) setState(() => busy = false);
    }
  }

  Future<void> _select(Map<String, dynamic> org) async {
    final o = (org['organizations'] ?? org) as Map<String, dynamic>;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('active_org_id', o['id'].toString());
    await prefs.setString('active_org_name', (o['name'] ?? '-').toString());
    if (!mounted) return;
    Navigator.pushReplacement(
      context,
      MaterialPageRoute(builder: (_) => MainShell(session: widget.session)),
    );
  }

  void _openDetail(Map<String, dynamic> m) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => WorkspaceDetailScreen(org: m, session: widget.session),
      ),
    );
  }

  void _focusForm() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) nameFocus.requestFocus();
    });
  }

  @override
  Widget build(BuildContext context) {
    if (loading) {
      return _OrgSwitcherScaffold(
        LoadingView(label: tr('org_loading')),
      );
    }
    if (loadErr != null) {
      return _OrgSwitcherScaffold(ErrorView(message: loadErr!, onRetry: _load));
    }
    return _OrgSwitcherScaffold(
      _OrgPickerBody(
        orgs: orgs,
        nameC: nameC,
        nameFocus: nameFocus,
        joinC: joinC,
        formErr: formErr,
        joinErr: joinErr,
        busy: busy,
        onNameChanged: (_) => setState(() => formErr = null),
        onCreate: _create,
        onCodeChanged: (_) => setState(() => joinErr = null),
        onJoin: _join,
        onFocusForm: _focusForm,
        onSelect: _select,
        onManage: _openDetail,
      ),
    );
  }
}

/// Kerangka layar pilih workspace: AppBar "Pilih workspace" + body.
class _OrgSwitcherScaffold extends StatelessWidget {
  final Widget body;
  const _OrgSwitcherScaffold(this.body);

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text(tr('org_title'))),
      body: body,
    );
  }
}

/// Isi layar: ajakan singkat, daftar workspace (atau EmptyView), form buat
/// workspace, dan form gabung via kode undangan.
class _OrgPickerBody extends StatelessWidget {
  final List<Map<String, dynamic>> orgs;
  final TextEditingController nameC;
  final FocusNode nameFocus;
  final TextEditingController joinC;
  final String? formErr;
  final String? joinErr;
  final bool busy;
  final ValueChanged<String> onNameChanged;
  final VoidCallback onCreate;
  final ValueChanged<String> onCodeChanged;
  final VoidCallback onJoin;
  final VoidCallback onFocusForm;
  final Future<void> Function(Map<String, dynamic> org) onSelect;
  final ValueChanged<Map<String, dynamic>> onManage;

  const _OrgPickerBody({
    required this.orgs,
    required this.nameC,
    required this.nameFocus,
    required this.joinC,
    required this.formErr,
    required this.joinErr,
    required this.busy,
    required this.onNameChanged,
    required this.onCreate,
    required this.onCodeChanged,
    required this.onJoin,
    required this.onFocusForm,
    required this.onSelect,
    required this.onManage,
  });

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.all(SsrSpace.lg),
      children: [
        Text(
          tr('org_pick'),
          style: Theme.of(context).textTheme.bodyMedium?.copyWith(
            color: Theme.of(context).textTheme.bodySmall?.color,
          ),
        ),
        const SizedBox(height: SsrSpace.lg),
        if (orgs.isEmpty)
          EmptyView(
            icon: AppIcons.workspace,
            title: tr('org_empty_t'),
            subtitle: tr('org_empty_s'),
            actionLabel: tr('org_empty_a'),
            onAction: onFocusForm,
          )
        else
          _OrgListCard(items: orgs, onSelect: onSelect, onManage: onManage),
        const SizedBox(height: SsrSpace.lg),
        _CreateOrgForm(
          nameC: nameC,
          nameFocus: nameFocus,
          formErr: formErr,
          busy: busy,
          onNameChanged: onNameChanged,
          onCreate: onCreate,
        ),
        const SizedBox(height: SsrSpace.lg),
        _JoinOrgForm(
          joinC: joinC,
          joinErr: joinErr,
          busy: busy,
          onCodeChanged: onCodeChanged,
          onJoin: onJoin,
        ),
      ],
    );
  }
}

/// Kartu daftar workspace: satu `_OrgRow` per workspace, berdivider.
class _OrgListCard extends StatelessWidget {
  final List<Map<String, dynamic>> items;
  final Future<void> Function(Map<String, dynamic> org) onSelect;
  final ValueChanged<Map<String, dynamic>> onManage;

  const _OrgListCard({
    required this.items,
    required this.onSelect,
    required this.onManage,
  });

  @override
  Widget build(BuildContext context) {
    return SectionCard(
      padding: const EdgeInsets.symmetric(
        horizontal: SsrSpace.md,
        vertical: SsrSpace.xs,
      ),
      child: Column(
        children: [
          for (var i = 0; i < items.length; i++) ...[
            if (i > 0) const Divider(height: 1),
            _OrgRow(m: items[i], onSelect: onSelect, onManage: onManage),
          ],
        ],
      ),
    );
  }
}

/// Satu baris daftar workspace: avatar inisial, nama, chip peran,
/// ketuk untuk pindah ke workspace tsb.
class _OrgRow extends StatelessWidget {
  final Map<String, dynamic> m;
  final Future<void> Function(Map<String, dynamic> org) onSelect;
  final ValueChanged<Map<String, dynamic>> onManage;

  const _OrgRow({
    required this.m,
    required this.onSelect,
    required this.onManage,
  });

  @override
  Widget build(BuildContext context) {
    final name = (m['organizations']?['name'] ?? '-').toString();
    final isOwner = m['role'] == 'owner';
    return InkWell(
      onTap: () => onSelect(m),
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: SsrSpace.sm),
        child: Row(
          children: [
            _OrgAvatar(name: name),
            const SizedBox(width: SsrSpace.md),
            Expanded(
              child: Text(
                name,
                style: Theme.of(context).textTheme.titleMedium,
              ),
            ),
            const SizedBox(width: SsrSpace.sm),
            StatusChip(
              label: isOwner ? tr('org_owner') : tr('org_member'),
              tone: isOwner ? StatusTone.accent : StatusTone.neutral,
            ),
            IconButton(
              tooltip: tr('wsm_detail'),
              onPressed: () => onManage(m),
              icon: const DuoIcon(AppIcons.settings),
            ),
          ],
        ),
      ),
    );
  }
}

/// Avatar lingkaran inisial nama workspace di atas surface terangkat.
class _OrgAvatar extends StatelessWidget {
  final String name;

  const _OrgAvatar({required this.name});

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final initial = name.isEmpty ? '?' : name[0].toUpperCase();
    return Container(
      width: 40,
      height: 40,
      alignment: Alignment.center,
      decoration: BoxDecoration(
        color: scheme.outline.withValues(alpha: 0.35),
        shape: BoxShape.circle,
        border: Border.all(color: scheme.outline),
      ),
      child: Text(
        initial,
        style: TextStyle(
          color: scheme.primary,
          fontWeight: FontWeight.w700,
          fontSize: 15,
        ),
      ),
    );
  }
}

/// Kartu form "Buat workspace baru".
class _CreateOrgForm extends StatelessWidget {
  final TextEditingController nameC;
  final FocusNode nameFocus;
  final String? formErr;
  final bool busy;
  final ValueChanged<String> onNameChanged;
  final VoidCallback onCreate;

  const _CreateOrgForm({
    required this.nameC,
    required this.nameFocus,
    required this.formErr,
    required this.busy,
    required this.onNameChanged,
    required this.onCreate,
  });

  @override
  Widget build(BuildContext context) {
    return SectionCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            tr('org_new'),
            style: Theme.of(context).textTheme.titleMedium,
          ),
          const SizedBox(height: SsrSpace.md),
          TextField(
            controller: nameC,
            focusNode: nameFocus,
            onChanged: onNameChanged,
            decoration: InputDecoration(
              labelText: tr('org_f_name'),
              errorText: formErr,
            ),
          ),
          const SizedBox(height: SsrSpace.lg),
          PrimaryButton(label: tr('org_create'), loading: busy, onPressed: onCreate),
        ],
      ),
    );
  }
}

/// Kartu form "Punya kode undangan?".
class _JoinOrgForm extends StatelessWidget {
  final TextEditingController joinC;
  final String? joinErr;
  final bool busy;
  final ValueChanged<String> onCodeChanged;
  final VoidCallback onJoin;

  const _JoinOrgForm({
    required this.joinC,
    required this.joinErr,
    required this.busy,
    required this.onCodeChanged,
    required this.onJoin,
  });

  @override
  Widget build(BuildContext context) {
    return SectionCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Punya kode undangan?',
            style: Theme.of(context).textTheme.titleMedium,
          ),
          const SizedBox(height: SsrSpace.md),
          TextField(
            controller: joinC,
            onChanged: onCodeChanged,
            decoration: InputDecoration(
              labelText: tr('org_f_code'),
              errorText: joinErr,
            ),
          ),
          const SizedBox(height: SsrSpace.lg),
          PrimaryButton(label: tr('org_join'), loading: busy, onPressed: onJoin),
        ],
      ),
    );
  }
}
