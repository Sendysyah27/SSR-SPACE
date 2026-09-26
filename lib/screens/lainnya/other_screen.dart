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
import 'package:ssr_space/screens/lainnya/categories_screen.dart';
import 'package:ssr_space/screens/lainnya/settings_screen.dart';
import 'package:ssr_space/screens/workspace/invite_screen.dart';
import 'package:ssr_space/screens/lainnya/notif_settings_screen.dart';
import 'package:ssr_space/screens/workspace/org_switcher_screen.dart';
import 'package:ssr_space/screens/auth/splash_screen.dart';
import 'package:ssr_space/screens/dompet/wallets_screen.dart';
import 'package:ssr_space/widgets/labeled_section_card.dart';
import 'package:ssr_space/widgets/nav_tile.dart';
import 'package:ssr_space/utils/strings.dart';
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
        title: Text(tr('o_logout_t')),
        content: const Text(
          'Sesi berakhir. Workspace aktif di HP ini ikut dilepas.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: Text(tr('cancel')),
          ),
          TextButton(
            style: TextButton.styleFrom(foregroundColor: SsrColors.danger),
            onPressed: () => Navigator.pop(ctx, true),
            child: Text(tr('o_logout')),
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
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text(tr('o_backup_ok'))));
    } catch (err, st) {
      ErrorReporter.capture(err, st, context: 'backup');
      if (!mounted) return;
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text(tr('o_backup_fail'))));
    } finally {
      if (mounted) setState(() => backingUp = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text(tr('nav_lainnya'))),
      body: FutureBuilder<_OtherMeta>(
        future: _metaFuture,
        builder: (_, snap) {
          final meta = snap.data;
          final planLabel = meta == null || meta.plan.isEmpty
              ? '-'
              : meta.plan == 'pro'
              ? tr('o_pro')
              : tr('o_free');
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
              _DataSection(
                onBackup: backingUp ? null : _backup,
                onCategories: () => _push(const CategoriesScreen()),
              ),
              _AppearanceSection(
                onSettings: () => _push(const SettingsScreen()),
              ),
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
      label: tr('o_sec_workspace'),
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
          title: tr('o_switch'),
          onTap: onSwitch,
        ),
        const Divider(height: 1),
        NavTile(
          icon: AppIcons.invite,
          title: tr('o_invite'),
          subtitle: tr('o_invite_s'),
          onTap: onInvite,
        ),
        const Divider(height: 1),
        NavTile(
          icon: AppIcons.wallet,
          title: tr('o_wallets'),
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
      label: tr('o_sec_tracking'),
      children: [
        NavTile(
          icon: AppIcons.tracking,
          title: tr('o_tracking'),
          subtitle: tr('o_tracking_s'),
          chip: StatusChip(
            label: tracking ? tr('nt_on') : tr('nt_off'),
            tone: tracking ? StatusTone.accent : StatusTone.neutral,
          ),
          onTap: onOpen,
        ),
      ],
    );
  }
}

/// Kartu "Data": daftar kategori + ekspor CSV workspace.
class _DataSection extends StatelessWidget {
  final VoidCallback? onBackup;
  final VoidCallback onCategories;

  const _DataSection({required this.onBackup, required this.onCategories});

  @override
  Widget build(BuildContext context) {
    return LabeledSectionCard(
      margin: const EdgeInsets.only(bottom: SsrSpace.md),
      label: tr('o_sec_data'),
      children: [
        NavTile(
          icon: AppIcons.categoryFallback,
          title: tr('o_cats'),
          subtitle: tr('o_cats_s'),
          onTap: onCategories,
        ),
        const Divider(height: 1),
        NavTile(
          icon: AppIcons.backup,
          title: tr('o_backup'),
          subtitle: tr('o_backup_s'),
          onTap: onBackup,
        ),
      ],
    );
  }
}

/// Kartu "Tampilan": toggle privacy mode + pintu ke Pengaturan.
class _AppearanceSection extends StatelessWidget {
  final VoidCallback onSettings;

  const _AppearanceSection({required this.onSettings});

  @override
  Widget build(BuildContext context) {
    return LabeledSectionCard(
      margin: const EdgeInsets.only(bottom: SsrSpace.md),
      label: tr('o_sec_display'),
      children: [
        ValueListenableBuilder<bool>(
          valueListenable: maskAmounts,
          builder: (context, masked, _) => SwitchListTile(
            contentPadding: EdgeInsets.zero,
            title: Text(tr('o_mask')),
            subtitle: Text(tr('o_mask_s')),
            value: masked,
            onChanged: setMaskAmounts,
          ),
        ),
        const Divider(height: 1),
        NavTile(
          icon: AppIcons.menu,
          title: tr('st_title'),
          subtitle: tr('o_settings_s'),
          onTap: onSettings,
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
      label: tr('o_sec_account'),
      children: [
        NavTile(
          icon: AppIcons.billing,
          title: tr('o_billing'),
          subtitle: tr('o_plan').replaceFirst('{p}', planLabel),
          onTap: onBilling,
        ),
        const Divider(height: 1),
        NavTile(icon: AppIcons.logout, title: tr('o_logout'), onTap: onLogout),
      ],
    );
  }
}
