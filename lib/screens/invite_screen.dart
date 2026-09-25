import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:share_plus/share_plus.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:ssr_space/core/saas/invite_service.dart';
import 'package:ssr_space/core/saas/invite_token.dart';
import 'package:ssr_space/core/theme/app_theme.dart';
import 'package:ssr_space/widgets/primary_button.dart';
import 'package:ssr_space/widgets/section_card.dart';
import 'package:ssr_space/widgets/state_views.dart';
import 'package:ssr_space/widgets/status_chip.dart';

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
      setState(() => loadErr = 'Gagal memuat undangan. Periksa koneksi.');
    } finally {
      if (mounted) setState(() => loading = false);
    }
  }

  Future<void> _create() async {
    if (creating) return;
    setState(() => creating = true);
    try {
      final res = await _service.createInvite(
        orgId: orgId,
        role: role ?? 'member',
      );
      if (!mounted) return;
      await _showTokenDialog(res.token);
      await _load();
    } catch (err) {
      if (!mounted) return;
      final msg = err is InviteException
          ? err.message
          : 'Gagal membuat undangan. Coba lagi.';
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(msg)),
      );
    } finally {
      if (mounted) setState(() => creating = false);
    }
  }

  Future<void> _showTokenDialog(String token) async {
    await showDialog<void>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Kode undangan'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Bagikan kode ini sekali. Kode tidak bisa dilihat lagi setelah '
              'dialog ditutup.',
              style: Theme.of(ctx).textTheme.bodySmall,
            ),
            const SizedBox(height: SsrSpace.md),
            SelectableText(
              token,
              style: Theme.of(ctx).textTheme.titleMedium?.copyWith(
                    fontFamily: 'monospace',
                    letterSpacing: 1.2,
                  ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () async {
              await Clipboard.setData(ClipboardData(text: token));
              if (ctx.mounted) {
                ScaffoldMessenger.of(ctx).showSnackBar(
                  const SnackBar(content: Text('Kode disalin.')),
                );
              }
            },
            child: const Text('Salin'),
          ),
          TextButton(
            onPressed: () {
              Share.share(
                'Gabung workspace di SSR SPACE dengan kode: $token',
              );
            },
            child: const Text('Bagikan'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Selesai'),
          ),
        ],
      ),
    );
  }

  Future<void> _revoke(Map<String, dynamic> row) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Cabut undangan?'),
        content: const Text('Kode yang sudah dicabut tidak bisa dipakai lagi.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Batal'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Cabut'),
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
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Gagal mencabut. Coba lagi.')),
      );
    }
  }

  String _status(Map<String, dynamic> row) {
    final expires = DateTime.parse(row['expires_at'].toString()).toLocal();
    return inviteStatusLabel(
      expiresAt: expires,
      revoked: row['revoked'] == true,
      usedCount: (row['used_count'] as num?)?.toInt() ?? 0,
      maxUses: (row['max_uses'] as num?)?.toInt() ?? 1,
      now: DateTime.now(),
    );
  }

  StatusTone _tone(String status) {
    switch (status) {
      case 'Aktif':
        return StatusTone.accent;
      case 'Habis':
        return StatusTone.neutral;
      default:
        return StatusTone.danger;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Undang anggota')),
      body: loading
          ? const LoadingView(label: 'Memuat undangan...')
          : loadErr != null
              ? ErrorView(message: loadErr!, onRetry: _load)
              : orgId.isEmpty
                  ? EmptyView(
                      icon: Icons.person_add_alt_outlined,
                      title: 'Belum ada workspace.',
                      subtitle: 'Pilih atau buat workspace dulu untuk mengundang.',
                      actionLabel: 'Muat ulang',
                      onAction: _load,
                    )
                  : !isAdmin
                      ? EmptyView(
                          icon: Icons.lock_outline,
                          title:
                              'Hanya admin workspace yang bisa mengundang anggota.',
                          subtitle:
                              'Minta owner atau admin membuat kode undangan.',
                          actionLabel: 'Muat ulang',
                          onAction: _load,
                        )
                      : ListView(
                          padding: const EdgeInsets.all(SsrSpace.lg),
                          children: [
                            SectionCard(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    orgName.isEmpty ? 'Workspace aktif' : orgName,
                                    style:
                                        Theme.of(context).textTheme.titleMedium,
                                  ),
                                  const SizedBox(height: SsrSpace.sm),
                                  Text(
                                    'Bagikan kode agar anggota lain bisa masuk ke '
                                    'buku kas ini.',
                                    style: Theme.of(context)
                                        .textTheme
                                        .bodyMedium
                                        ?.copyWith(
                                          color: SsrColors.secondary,
                                        ),
                                  ),
                                  const SizedBox(height: SsrSpace.md),
                                  DropdownButtonFormField<String>(
                                    value: role,
                                    decoration: const InputDecoration(
                                      labelText: 'Peran anggota',
                                    ),
                                    items: const [
                                      DropdownMenuItem(
                                          value: 'member',
                                          child: Text('Anggota')),
                                      DropdownMenuItem(
                                          value: 'admin', child: Text('Admin')),
                                    ],
                                    onChanged: (v) =>
                                        setState(() => role = v ?? 'member'),
                                  ),
                                  const SizedBox(height: SsrSpace.lg),
                                  PrimaryButton(
                                    label: 'Buat undangan',
                                    loading: creating,
                                    onPressed: orgId.isEmpty ? null : _create,
                                  ),
                                ],
                              ),
                            ),
                            const SizedBox(height: SsrSpace.lg),
                            if (invites.isEmpty)
                              SectionCard(
                                child: Text(
                                  'Belum ada undangan aktif. Buat kode di atas '
                                  'untuk mengundang anggota.',
                                  style: Theme.of(context).textTheme.bodyMedium,
                                ),
                              )
                            else
                              SectionCard(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: SsrSpace.md,
                                  vertical: SsrSpace.xs,
                                ),
                                child: Column(
                                  children: [
                                    for (var i = 0; i < invites.length; i++) ...[
                                      if (i > 0) const Divider(height: 1),
                                      _inviteRow(invites[i]),
                                    ],
                                  ],
                                ),
                              ),
                          ],
                        ),
    );
  }

  Widget _inviteRow(Map<String, dynamic> row) {
    final status = _status(row);
    final canRevoke = status == 'Aktif';
    final remaining =
        ((row['max_uses'] as num?)?.toInt() ?? 1) -
            ((row['used_count'] as num?)?.toInt() ?? 0);
    final roleName = row['role'] == 'admin' ? 'Admin' : 'Anggota';
    final createdAt =
        DateTime.parse(row['created_at'].toString()).toLocal();
    final createdLabel =
        '${createdAt.day.toString().padLeft(2, '0')}/'
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
                  '$roleName · sisa pemakaian $remaining',
                  style: Theme.of(context).textTheme.bodySmall,
                ),
              ],
            ),
          ),
          StatusChip(label: status, tone: _tone(status)),
          if (canRevoke) ...[
            const SizedBox(width: SsrSpace.xs),
            IconButton(
              tooltip: 'Cabut undangan',
              onPressed: () => _revoke(row),
              icon: const Icon(Icons.link_off, size: 20),
            ),
          ],
        ],
      ),
    );
  }
}
