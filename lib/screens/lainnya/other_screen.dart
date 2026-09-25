import 'dart:io';

import 'package:flutter/material.dart';
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:ssr_space/utils/mask.dart';
import 'package:ssr_space/services/backup_export.dart';
import 'package:ssr_space/services/billing_service.dart';
import 'package:ssr_space/services/error_reporter.dart';
import 'package:ssr_space/services/foreground_track.dart';
import 'package:ssr_space/services/supabase_config.dart';
import 'package:ssr_space/services/session_service.dart';
import 'package:ssr_space/theme/app_icons.dart';
import 'package:ssr_space/theme/app_theme.dart';
import 'package:ssr_space/screens/lainnya/billing_screen.dart';
import 'package:ssr_space/screens/workspace/invite_screen.dart';
import 'package:ssr_space/screens/lainnya/notif_settings_screen.dart';
import 'package:ssr_space/screens/workspace/org_switcher_screen.dart';
import 'package:ssr_space/screens/auth/splash_screen.dart';
import 'package:ssr_space/screens/dompet/wallets_screen.dart';
import 'package:ssr_space/widgets/labeled_section_card.dart';
import 'package:ssr_space/widgets/nav_tile.dart';
import 'package:ssr_space/widgets/status_chip.dart';

class _OtherMeta {
  final String orgName;
  final String plan;
  final bool tracking;
  const _OtherMeta({
    required this.orgName,
    required this.plan,
    required this.tracking,
  });
}

class OtherScreen extends StatefulWidget {
  final SessionService session;
  const OtherScreen({super.key, required this.session});

  @override
  State<OtherScreen> createState() => _OtherScreenState();
}

class _OtherScreenState extends State<OtherScreen> {
  late Future<_OtherMeta> _metaFuture;

  @override
  void initState() {
    super.initState();
    _metaFuture = _meta();
  }

  Future<_OtherMeta> _meta() async {
    final p = await SharedPreferences.getInstance();
    final orgName = p.getString('active_org_name') ?? '-';
    final tracking = p.getBool('track_master') ?? false;
    final orgId = p.getString('active_org_id') ?? '';
    var plan = '';
    if (orgId.isNotEmpty) {
      try {
        plan = await currentPlan(orgId);
      } catch (_) {
        plan = '';
      }
    }
    return _OtherMeta(orgName: orgName, plan: plan, tracking: tracking);
  }

  void _refreshMeta() {
    setState(() => _metaFuture = _meta());
  }

  Future<void> _confirmLogout() async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Keluar dari akun?'),
        content: const Text(
          'Sesi berakhir. Workspace aktif di HP ini ikut dilepas.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Batal'),
          ),
          TextButton(
            style: TextButton.styleFrom(foregroundColor: SsrColors.danger),
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Keluar'),
          ),
        ],
      ),
    );
    if (ok != true || !mounted) return;
    await SupabaseConfig.client.auth.signOut();
    final p = await SharedPreferences.getInstance();
    await p.remove('active_org_id');
    await ForegroundTrack.stop();
    if (!mounted) return;
    Navigator.pushAndRemoveUntil(
      context,
      MaterialPageRoute(builder: (_) => SplashScreen(session: widget.session)),
      (_) => false,
    );
  }

  Future<void> _push(Widget screen) async {
    await Navigator.push(context, MaterialPageRoute(builder: (_) => screen));
    if (mounted) _refreshMeta();
  }

  bool backingUp = false;

  Future<void> _backup() async {
    if (backingUp) return;
    setState(() => backingUp = true);
    try {
      final p = await SharedPreferences.getInstance();
      final orgId = p.getString('active_org_id') ?? '';
      if (orgId.isEmpty) throw StateError('org kosong');
      final c = SupabaseConfig.client;
      final List<Map<String, dynamic>> wallets = await c
          .from('wallets')
          .select()
          .eq('org_id', orgId)
          .order('created_at');
      final List<Map<String, dynamic>> txs = await c
          .from('transactions')
          .select()
          .eq('org_id', orgId)
          .order('date')
          .limit(10000);
      final List<Map<String, dynamic>> budgets = await c
          .from('budgets')
          .select()
          .eq('org_id', orgId)
          .order('month');
      final contents = [
        walletsCsv(wallets),
        transactionsCsv(txs),
        budgetsCsv(budgets),
      ];
      final dir = await getTemporaryDirectory();
      final files = <XFile>[];
      for (var i = 0; i < contents.length; i++) {
        final f = File('${dir.path}/${backupFileNames()[i]}');
        await f.writeAsString(contents[i]);
        files.add(XFile(f.path));
      }
      await Share.shareXFiles(files, text: 'Cadangan data SSR SPACE (CSV)');
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('File cadangan siap dibagikan.')),
      );
    } catch (err, st) {
      ErrorReporter.capture(err, st, context: 'backup');
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Gagal membuat cadangan. Coba lagi.')),
      );
    } finally {
      if (mounted) setState(() => backingUp = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Lainnya')),
      body: FutureBuilder<_OtherMeta>(
        future: _metaFuture,
        builder: (_, snap) {
          final meta = snap.data;
          final planLabel = meta == null || meta.plan.isEmpty
              ? '-'
              : meta.plan == 'pro'
              ? 'Pro'
              : 'Gratis';
          return ListView(
            padding: const EdgeInsets.all(SsrSpace.lg),
            children: [
              _WorkspaceSection(
                orgName: meta?.orgName ?? '-',
                planLabel: planLabel,
                isPro: meta?.plan == 'pro',
                onSwitch: () =>
                    _push(OrgSwitcherScreen(session: widget.session)),
                onInvite: () => _push(const InviteScreen()),
                onWallets: () => _push(const WalletsScreen()),
              ),
              _TrackingSection(
                tracking: meta?.tracking == true,
                onOpen: () => _push(const NotifSettingsScreen()),
              ),
              _DataSection(onBackup: backingUp ? null : _backup),
              const _AppearanceSection(),
              _AccountSection(
                planLabel: planLabel,
                onBilling: () => _push(const BillingScreen()),
                onLogout: _confirmLogout,
              ),
            ],
          );
        },
      ),
    );
  }
}

/// Kartu "Workspace": nama org aktif, chip plan, dan 3 menu navigasi.
class _WorkspaceSection extends StatelessWidget {
  final String orgName;
  final String planLabel;
  final bool isPro;
  final VoidCallback onSwitch;
  final VoidCallback onInvite;
  final VoidCallback onWallets;

  const _WorkspaceSection({
    required this.orgName,
    required this.planLabel,
    required this.isPro,
    required this.onSwitch,
    required this.onInvite,
    required this.onWallets,
  });

  @override
  Widget build(BuildContext context) {
    return LabeledSectionCard(
      margin: const EdgeInsets.only(bottom: SsrSpace.md),
      label: 'Workspace',
      children: [
        Row(
          children: [
            Expanded(
              child: Text(
                orgName,
                style: Theme.of(context).textTheme.titleMedium,
              ),
            ),
            StatusChip(
              label: planLabel,
              tone: isPro ? StatusTone.accent : StatusTone.neutral,
            ),
          ],
        ),
        const Divider(height: SsrSpace.xl),
        NavTile(
          icon: AppIcons.workspaceSwitch,
          title: 'Ganti workspace',
          onTap: onSwitch,
        ),
        const Divider(height: 1),
        NavTile(
          icon: AppIcons.invite,
          title: 'Undang anggota',
          subtitle: 'Bagikan kode untuk gabung workspace',
          onTap: onInvite,
        ),
        const Divider(height: 1),
        NavTile(
          icon: AppIcons.wallet,
          title: 'Dompet',
          onTap: onWallets,
        ),
      ],
    );
  }
}

/// Kartu "Pelacakan": satu menu dengan chip on/off status tracking.
class _TrackingSection extends StatelessWidget {
  final bool tracking;
  final VoidCallback onOpen;

  const _TrackingSection({required this.tracking, required this.onOpen});

  @override
  Widget build(BuildContext context) {
    return LabeledSectionCard(
      margin: const EdgeInsets.only(bottom: SsrSpace.md),
      label: 'Pelacakan',
      children: [
        NavTile(
          icon: AppIcons.tracking,
          title: 'Pelacakan otomatis',
          subtitle: 'Notifikasi bank jadi transaksi',
          chip: StatusChip(
            label: tracking ? 'Menyala' : 'Mati',
            tone: tracking ? StatusTone.accent : StatusTone.neutral,
          ),
          onTap: onOpen,
        ),
      ],
    );
  }
}

/// Kartu "Data": ekspor CSV workspace (nonaktif saat proses berjalan).
class _DataSection extends StatelessWidget {
  final VoidCallback? onBackup;

  const _DataSection({required this.onBackup});

  @override
  Widget build(BuildContext context) {
    return LabeledSectionCard(
      margin: const EdgeInsets.only(bottom: SsrSpace.md),
      label: 'Data',
      children: [
        NavTile(
          icon: AppIcons.backup,
          title: 'Cadangkan data',
          subtitle: 'Ekspor seluruh workspace ke CSV',
          onTap: onBackup,
        ),
      ],
    );
  }
}

/// Kartu "Tampilan": toggle privacy mode samarkan nominal (state global).
class _AppearanceSection extends StatelessWidget {
  const _AppearanceSection();

  @override
  Widget build(BuildContext context) {
    return LabeledSectionCard(
      margin: const EdgeInsets.only(bottom: SsrSpace.md),
      label: 'Tampilan',
      children: [
        ValueListenableBuilder<bool>(
          valueListenable: maskAmounts,
          builder: (context, masked, _) => SwitchListTile(
            contentPadding: EdgeInsets.zero,
            title: const Text('Samarkan nominal'),
            subtitle: const Text('Sembunyikan saldo & nominal transaksi'),
            value: masked,
            onChanged: setMaskAmounts,
          ),
        ),
      ],
    );
  }
}

/// Kartu "Akun": billing + keluar.
class _AccountSection extends StatelessWidget {
  final String planLabel;
  final VoidCallback onBilling;
  final VoidCallback onLogout;

  const _AccountSection({
    required this.planLabel,
    required this.onBilling,
    required this.onLogout,
  });

  @override
  Widget build(BuildContext context) {
    return LabeledSectionCard(
      label: 'Akun',
      children: [
        NavTile(
          icon: AppIcons.billing,
          title: 'Billing',
          subtitle: 'Paket $planLabel',
          onTap: onBilling,
        ),
        const Divider(height: 1),
        NavTile(icon: AppIcons.logout, title: 'Keluar', onTap: onLogout),
      ],
    );
  }
}
