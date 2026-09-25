import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:uuid/uuid.dart';
import 'package:ssr_space/services/invite_service.dart';
import 'package:ssr_space/services/supabase_config.dart';
import 'package:ssr_space/services/session_service.dart';
import 'package:ssr_space/theme/app_theme.dart';
import 'package:ssr_space/screens/shell/main_shell.dart';
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
      loadErr = 'Gagal memuat workspace. Periksa koneksi lalu coba lagi.';
    } finally {
      setState(() => loading = false);
    }
  }

  Future<void> _create() async {
    if (busy) return;
    final name = nameC.text.trim();
    if (name.isEmpty) {
      setState(() => formErr = 'Nama workspace wajib diisi.');
      return;
    }
    setState(() {
      busy = true;
      formErr = null;
    });
    try {
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
      formErr = 'Gagal membuat workspace. Periksa nama dan koneksi.';
    } finally {
      if (mounted) setState(() => busy = false);
    }
  }

  Future<void> _join() async {
    if (busy) return;
    final code = joinC.text.trim();
    if (code.isEmpty) {
      setState(() => joinErr = 'Tempel kode undangan dulu.');
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
        const SnackBar(content: Text('Berhasil bergabung ke workspace.')),
      );
      await _load();
    } on InviteException catch (err) {
      if (!mounted) return;
      setState(() => joinErr = err.message);
    } catch (_) {
      if (!mounted) return;
      setState(() => joinErr = 'Gagal bergabung. Periksa koneksi.');
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

  void _focusForm() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) nameFocus.requestFocus();
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Pilih workspace')),
      body: loading
          ? const LoadingView(label: 'Memuat workspace...')
          : loadErr != null
          ? ErrorView(message: loadErr!, onRetry: _load)
          : ListView(
              padding: const EdgeInsets.all(SsrSpace.lg),
              children: [
                Text(
                  'Pilih ruang catat atau buat baru.',
                  style: Theme.of(context).textTheme.bodyMedium
                      ?.copyWith(color: SsrColors.secondary),
                ),
                const SizedBox(height: SsrSpace.lg),
                if (orgs.isEmpty)
                  EmptyView(
                    icon: Icons.workspaces_outlined,
                    title: 'Belum ada workspace.',
                    subtitle:
                        'Buat workspace pertama di bawah untuk mulai mencatat.',
                    actionLabel: 'Buat workspace',
                    onAction: _focusForm,
                  )
                else
                  SectionCard(
                    padding: const EdgeInsets.symmetric(
                      horizontal: SsrSpace.md,
                      vertical: SsrSpace.xs,
                    ),
                    child: Column(
                      children: [
                        for (var i = 0; i < orgs.length; i++) ...[
                          if (i > 0) const Divider(height: 1),
                          _OrgRow(m: orgs[i], onSelect: _select),
                        ],
                      ],
                    ),
                  ),
                const SizedBox(height: SsrSpace.lg),
                _CreateOrgForm(
                  nameC: nameC,
                  nameFocus: nameFocus,
                  formErr: formErr,
                  busy: busy,
                  onNameChanged: (_) => setState(() => formErr = null),
                  onCreate: _create,
                ),
                const SizedBox(height: SsrSpace.lg),
                _JoinOrgForm(
                  joinC: joinC,
                  joinErr: joinErr,
                  busy: busy,
                  onCodeChanged: (_) => setState(() => joinErr = null),
                  onJoin: _join,
                ),
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

  const _OrgRow({required this.m, required this.onSelect});

  @override
  Widget build(BuildContext context) {
    final name = (m['organizations']?['name'] ?? '-').toString();
    final isOwner = m['role'] == 'owner';
    final initial = name.isEmpty ? '?' : name[0].toUpperCase();
    return InkWell(
      onTap: () => onSelect(m),
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: SsrSpace.sm),
        child: Row(
          children: [
            Container(
              width: 40,
              height: 40,
              alignment: Alignment.center,
              decoration: const BoxDecoration(
                color: SsrColors.accentSoft,
                shape: BoxShape.circle,
              ),
              child: Text(
                initial,
                style: const TextStyle(
                  color: SsrColors.accent,
                  fontWeight: FontWeight.w700,
                  fontSize: 15,
                ),
              ),
            ),
            const SizedBox(width: SsrSpace.md),
            Expanded(
              child: Text(name, style: Theme.of(context).textTheme.titleMedium),
            ),
            const SizedBox(width: SsrSpace.sm),
            StatusChip(
              label: isOwner ? 'Pemilik' : 'Anggota',
              tone: isOwner ? StatusTone.accent : StatusTone.neutral,
            ),
          ],
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
            'Buat workspace baru',
            style: Theme.of(context).textTheme.titleMedium,
          ),
          const SizedBox(height: SsrSpace.md),
          TextField(
            controller: nameC,
            focusNode: nameFocus,
            onChanged: onNameChanged,
            decoration: InputDecoration(
              labelText: 'Nama workspace',
              errorText: formErr,
            ),
          ),
          const SizedBox(height: SsrSpace.lg),
          PrimaryButton(label: 'Buat', loading: busy, onPressed: onCreate),
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
              labelText: 'Kode undangan',
              errorText: joinErr,
            ),
          ),
          const SizedBox(height: SsrSpace.lg),
          PrimaryButton(label: 'Gabung', loading: busy, onPressed: onJoin),
        ],
      ),
    );
  }
}
