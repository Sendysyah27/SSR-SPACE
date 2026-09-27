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
import 'package:ssr_space/services/instant_correct.dart';
import 'package:ssr_space/services/supabase_config.dart';
import 'package:ssr_space/services/session_service.dart';
import 'package:ssr_space/theme/app_icons.dart';
import 'package:ssr_space/theme/app_theme.dart';
import 'package:ssr_space/utils/app_info.dart';
import 'package:ssr_space/screens/budget/budgets_screen.dart';
import 'package:ssr_space/screens/lainnya/billing_screen.dart';
import 'package:ssr_space/screens/lainnya/categories_screen.dart';
import 'package:ssr_space/screens/lainnya/import_preview_screen.dart';
import 'package:ssr_space/screens/lainnya/settings_screen.dart';
import 'package:ssr_space/screens/laporan/reports_screen.dart';
import 'package:ssr_space/screens/transaksi/transactions_screen.dart';
import 'package:ssr_space/screens/workspace/invite_screen.dart';
import 'package:ssr_space/screens/workspace/workspace_detail_screen.dart';
import 'package:ssr_space/screens/lainnya/notif_settings_screen.dart';
import 'package:ssr_space/screens/lainnya/settings_search.dart';
import 'package:ssr_space/screens/lainnya/update_log_screen.dart';
import 'package:ssr_space/screens/workspace/org_switcher_screen.dart';
import 'package:ssr_space/screens/auth/splash_screen.dart';
import 'package:ssr_space/screens/dompet/wallets_screen.dart';
import 'package:ssr_space/widgets/labeled_section_card.dart';
import 'package:ssr_space/widgets/nav_tile.dart';
import 'package:ssr_space/widgets/section_card.dart';
import 'package:ssr_space/utils/strings.dart';
import 'package:ssr_space/widgets/status_chip.dart';

class _OtherMeta {
  final String orgName;
  final String plan;
  final bool tracking;
  final bool popup;
  const _OtherMeta({
    required this.orgName,
    required this.plan,
    required this.tracking,
    required this.popup,
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
    final popup = p.getBool('correct_popup') ?? true;
    final orgId = p.getString('active_org_id') ?? '';
    var plan = '';
    if (orgId.isNotEmpty) {
      try {
        plan = await currentPlan(orgId);
      } catch (_) {
        plan = '';
      }
    }
    return _OtherMeta(
      orgName: orgName,
      plan: plan,
      tracking: tracking,
      popup: popup,
    );
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

  /// Dialog P2 generik: semua baris yang layarnya baru ada di Task 6/8
  /// atau belum ada sama sekali menunjuk ke sini. Bukan no-op diam.
  Future<void> _showP2() async {
    if (!mounted) return;
    await showDialog<void>(
      context: context,
      builder: (ctx) => AlertDialog(
        content: Text(tr('msg_p2')),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: Text(tr('back')),
          ),
        ],
      ),
    );
  }

  /// Hapus cache lokal saja (pending koreksi + pref popup overlay).
  /// Tak pernah menyentuh data Supabase.
  Future<void> _clearLocalCache() async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(tr('st_reset_correct')),
        content: Text(tr('st_reset_correct')),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: Text(tr('cancel')),
          ),
          TextButton(
            style: TextButton.styleFrom(foregroundColor: SsrColors.danger),
            onPressed: () => Navigator.pop(ctx, true),
            child: Text(tr('tx_delete')),
          ),
        ],
      ),
    );
    if (ok != true || !mounted) return;
    await InstantCorrect.clearMemory();
    _refreshMeta();
    if (!mounted) return;
    ScaffoldMessenger.of(context)
        .showSnackBar(SnackBar(content: Text(tr('st_reset_correct_done'))));
  }

  Future<void> _setPopup(bool v) async {
    await InstantCorrect.setPopupEnabled(v);
    if (mounted) _refreshMeta();
  }

  /// Buka detail workspace aktif (baris Kelola di switcher, dibuka langsung).
  Future<void> _openWorkspaceDetail() async {
    final p = await SharedPreferences.getInstance();
    final orgId = p.getString('active_org_id') ?? '';
    final uid = SupabaseConfig.client.auth.currentUser?.id;
    if (orgId.isEmpty || uid == null || !mounted) {
      if (mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text(tr('org_err_load'))));
      }
      return;
    }
    try {
      final rows = await SupabaseConfig.client
          .from('org_members')
          .select('org_id, role, organizations(id, name, plan)')
          .eq('user_id', uid)
          .eq('org_id', orgId);
      if (!mounted) return;
      final list = List<Map<String, dynamic>>.from(rows as List);
      if (list.isEmpty) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text(tr('org_err_load'))));
        return;
      }
      await Navigator.push(
        context,
        MaterialPageRoute(
          builder: (_) =>
              WorkspaceDetailScreen(org: list.first, session: widget.session),
        ),
      );
      if (mounted) _refreshMeta();
    } catch (_) {
      if (!mounted) return;
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text(tr('org_err_load'))));
    }
  }

  /// Hasil pencarian pengaturan: layar nyata di-push, aksi dijalankan,
  /// baris P2 menampilkan dialog msg_p2. 'hub' berarti sudah di sini.
  Future<void> _openSearch() async {
    final key = await showSearch<String?>(
      context: context,
      delegate: SettingsSearchDelegate(),
    );
    if (!mounted || key == null || key == kSearchHub) return;
    switch (key) {
      case 'wallets':
        await _push(const WalletsScreen());
      case 'categories':
        await _push(const CategoriesScreen());
      case 'budgets':
        await _push(const BudgetsScreen());
      case 'history':
        await _push(const TransactionsScreen());
      case 'tracking':
        await _push(const NotifSettingsScreen());
      case 'export':
        await _push(const ReportsScreen());
      case 'import':
        await _push(const ImportPreviewScreen());
      case 'switch':
        await _push(OrgSwitcherScreen(session: widget.session));
      case 'invite':
        await _push(const InviteScreen());
      case 'detail':
        await _openWorkspaceDetail();
      case 'billing':
        await _push(const BillingScreen());
      case 'settings':
        await _push(const SettingsScreen());
      case 'changelog':
        await _push(const UpdateLogScreen());
      case 'backup':
        await _backup();
      case 'clearCache':
        await _clearLocalCache();
      case 'logout':
        await _confirmLogout();
      default:
        await _showP2();
    }
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
      appBar: AppBar(
        title: Text(tr('nav_lainnya')),
        actions: [
          IconButton(
            icon: const Icon(Icons.search),
            tooltip: tr('search_settings_hint'),
            onPressed: _openSearch,
          ),
        ],
      ),
      body: FutureBuilder<_OtherMeta>(
        future: _metaFuture,
        builder: (_, snap) {
          final meta = snap.data;
          final planLabel = meta == null || meta.plan.isEmpty
              ? '-'
              : meta.plan == 'pro'
              ? tr('o_pro')
              : tr('o_free');
          return _HubList(
            orgName: meta?.orgName ?? '-',
            planLabel: planLabel,
            isPro: meta?.plan == 'pro',
            tracking: meta?.tracking == true,
            popup: meta?.popup != false,
            backupBusy: backingUp,
            onSwitch: () => _push(OrgSwitcherScreen(session: widget.session)),
            onInvite: () => _push(const InviteScreen()),
            onDetail: _openWorkspaceDetail,
            onBilling: () => _push(const BillingScreen()),
            onWallets: () => _push(const WalletsScreen()),
            onCategories: () => _push(const CategoriesScreen()),
            onBudgets: () => _push(const BudgetsScreen()),
            onHistory: () => _push(const TransactionsScreen()),
            onTracking: () => _push(const NotifSettingsScreen()),
            onPopupChanged: _setPopup,
            onBackup: _backup,
            onExport: () => _push(const ReportsScreen()),
            onImportP2: () => _push(const ImportPreviewScreen()),
            onClearCache: _clearLocalCache,
            onSettings: () => _push(const SettingsScreen()),
            onChangelog: () => _push(const UpdateLogScreen()),
            onLogout: _confirmLogout,
          );
        },
      ),
    );
  }
}

/// Daftar hub: HEADER meta + 9 seksi pf_* berurutan.
class _HubList extends StatelessWidget {
  final String orgName;
  final String planLabel;
  final bool isPro;
  final bool tracking;
  final bool popup;
  final bool backupBusy;
  final VoidCallback onSwitch;
  final VoidCallback onInvite;
  final VoidCallback onDetail;
  final VoidCallback onBilling;
  final VoidCallback onWallets;
  final VoidCallback onCategories;
  final VoidCallback onBudgets;
  final VoidCallback onHistory;
  final VoidCallback onTracking;
  final ValueChanged<bool> onPopupChanged;
  final VoidCallback onBackup;
  final VoidCallback onExport;
  final VoidCallback onImportP2;
  final VoidCallback onClearCache;
  final VoidCallback onSettings;
  final VoidCallback onChangelog;
  final VoidCallback onLogout;

  const _HubList({
    required this.orgName,
    required this.planLabel,
    required this.isPro,
    required this.tracking,
    required this.popup,
    required this.backupBusy,
    required this.onSwitch,
    required this.onInvite,
    required this.onDetail,
    required this.onBilling,
    required this.onWallets,
    required this.onCategories,
    required this.onBudgets,
    required this.onHistory,
    required this.onTracking,
    required this.onPopupChanged,
    required this.onBackup,
    required this.onExport,
    required this.onImportP2,
    required this.onClearCache,
    required this.onSettings,
    required this.onChangelog,
    required this.onLogout,
  });

  List<Widget> _upper() {
    return [
      _HeaderCard(
        orgName: orgName,
        planLabel: planLabel,
        isPro: isPro,
        tracking: tracking,
      ),
      _DataSection(
        onWallets: onWallets,
        onCategories: onCategories,
        onBudgets: onBudgets,
        onHistory: onHistory,
      ),
      _TrackingSection(
        tracking: tracking,
        popup: popup,
        onOpen: onTracking,
        onPopupChanged: onPopupChanged,
      ),
      _BackupSection(
        backupBusy: backupBusy,
        onBackup: onBackup,
        onExport: onExport,
        onImportP2: onImportP2,
        onClearCache: onClearCache,
      ),
      _WorkspaceSection(
        orgName: orgName,
        planLabel: planLabel,
        onSwitch: onSwitch,
        onInvite: onInvite,
        onDetail: onDetail,
        onBilling: onBilling,
      ),
    ];
  }

  List<Widget> _lower() {
    return [
      _AppearanceSection(onSettings: onSettings),
      _LangMoneySection(onSettings: onSettings),
      _ReminderSection(onSettings: onSettings),
      _SecuritySection(onSettings: onSettings, onLogout: onLogout),
      _AboutSection(onChangelog: onChangelog),
    ];
  }

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.all(SsrSpace.lg),
      children: [..._upper(), ..._lower()],
    );
  }
}

/// HEADER: kartu meta tanpa label (nama org, chip plan, status pelacakan).
class _HeaderCard extends StatelessWidget {
  final String orgName;
  final String planLabel;
  final bool isPro;
  final bool tracking;

  const _HeaderCard({
    required this.orgName,
    required this.planLabel,
    required this.isPro,
    required this.tracking,
  });

  @override
  Widget build(BuildContext context) {
    return SectionCard(
      margin: const EdgeInsets.only(bottom: SsrSpace.md),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
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
          Row(
            children: [
              Expanded(
                child: Text(
                  tr('o_tracking'),
                  style: Theme.of(context).textTheme.bodySmall,
                ),
              ),
              StatusChip(
                label: tracking ? tr('nt_on') : tr('nt_off'),
                tone: tracking ? StatusTone.accent : StatusTone.neutral,
              ),
            ],
          ),
        ],
      ),
    );
  }
}

/// DATA: dompet, kategori, budget, riwayat transaksi.
class _DataSection extends StatelessWidget {
  final VoidCallback onWallets;
  final VoidCallback onCategories;
  final VoidCallback onBudgets;
  final VoidCallback onHistory;

  const _DataSection({
    required this.onWallets,
    required this.onCategories,
    required this.onBudgets,
    required this.onHistory,
  });

  @override
  Widget build(BuildContext context) {
    return LabeledSectionCard(
      margin: const EdgeInsets.only(bottom: SsrSpace.md),
      label: tr('pf_data'),
      children: [
        NavTile(
          icon: AppIcons.wallet,
          title: tr('o_wallets'),
          onTap: onWallets,
        ),
        const Divider(height: 1),
        NavTile(
          icon: AppIcons.categoryFallback,
          title: tr('o_cats'),
          subtitle: tr('o_cats_s'),
          onTap: onCategories,
        ),
        const Divider(height: 1),
        NavTile(
          icon: AppIcons.budget,
          title: tr('nav_budget'),
          onTap: onBudgets,
        ),
        const Divider(height: 1),
        NavTile(
          icon: AppIcons.transactions,
          title: tr('nav_transaksi'),
          onTap: onHistory,
        ),
      ],
    );
  }
}

/// PELACAKAN: pintu pelacakan otomatis + toggle popup koreksi instan.
class _TrackingSection extends StatelessWidget {
  final bool tracking;
  final bool popup;
  final VoidCallback onOpen;
  final ValueChanged<bool> onPopupChanged;

  const _TrackingSection({
    required this.tracking,
    required this.popup,
    required this.onOpen,
    required this.onPopupChanged,
  });

  @override
  Widget build(BuildContext context) {
    return LabeledSectionCard(
      margin: const EdgeInsets.only(bottom: SsrSpace.md),
      label: tr('pf_tracking'),
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
        const Divider(height: 1),
        SwitchListTile(
          contentPadding: EdgeInsets.zero,
          title: Text(tr('ic_popup')),
          subtitle: Text(tr('ic_popup_s')),
          value: popup,
          onChanged: onPopupChanged,
        ),
      ],
    );
  }
}

/// DATA DAN CADANGAN: cadangkan, ekspor laporan, impor, hapus cache lokal.
class _BackupSection extends StatelessWidget {
  final bool backupBusy;
  final VoidCallback onBackup;
  final VoidCallback onExport;
  final VoidCallback onImportP2;
  final VoidCallback onClearCache;

  const _BackupSection({
    required this.backupBusy,
    required this.onBackup,
    required this.onExport,
    required this.onImportP2,
    required this.onClearCache,
  });

  @override
  Widget build(BuildContext context) {
    return LabeledSectionCard(
      margin: const EdgeInsets.only(bottom: SsrSpace.md),
      label: tr('pf_backup'),
      children: [
        NavTile(
          icon: AppIcons.backup,
          title: tr('o_backup'),
          subtitle: tr('o_backup_s'),
          onTap: backupBusy ? null : onBackup,
        ),
        const Divider(height: 1),
        NavTile(
          icon: AppIcons.reports,
          title: tr('nav_laporan'),
          subtitle: tr('r_dl').replaceFirst('{l}', 'CSV / PDF'),
          onTap: onExport,
        ),
        const Divider(height: 1),
        NavTile(
          icon: AppIcons.arrowDown,
          title: tr('imp_title'),
          subtitle: tr('imp_title'),
          onTap: onImportP2,
        ),
        const Divider(height: 1),
        NavTile(
          icon: AppIcons.revoke,
          title: tr('st_reset_correct'),
          onTap: onClearCache,
        ),
      ],
    );
  }
}

/// WORKSPACE: undang, ganti, kelola detail, billing paket.
class _WorkspaceSection extends StatelessWidget {
  final String orgName;
  final String planLabel;
  final VoidCallback onSwitch;
  final VoidCallback onInvite;
  final VoidCallback onDetail;
  final VoidCallback onBilling;

  const _WorkspaceSection({
    required this.orgName,
    required this.planLabel,
    required this.onSwitch,
    required this.onInvite,
    required this.onDetail,
    required this.onBilling,
  });

  @override
  Widget build(BuildContext context) {
    return LabeledSectionCard(
      margin: const EdgeInsets.only(bottom: SsrSpace.md),
      label: tr('pf_workspace'),
      children: [
        NavTile(
          icon: AppIcons.invite,
          title: tr('o_invite'),
          subtitle: tr('o_invite_s'),
          onTap: onInvite,
        ),
        const Divider(height: 1),
        NavTile(
          icon: AppIcons.workspaceSwitch,
          title: tr('o_switch'),
          onTap: onSwitch,
        ),
        const Divider(height: 1),
        NavTile(
          icon: AppIcons.workspace,
          title: tr('wsm_detail'),
          subtitle: orgName,
          onTap: onDetail,
        ),
        const Divider(height: 1),
        NavTile(
          icon: AppIcons.billing,
          title: tr('o_billing'),
          subtitle: tr('o_plan').replaceFirst('{p}', planLabel),
          onTap: onBilling,
        ),
      ],
    );
  }
}

/// TAMPILAN: toggle samarkan nominal + pintu pengaturan.
class _AppearanceSection extends StatelessWidget {
  final VoidCallback onSettings;

  const _AppearanceSection({required this.onSettings});

  @override
  Widget build(BuildContext context) {
    return LabeledSectionCard(
      margin: const EdgeInsets.only(bottom: SsrSpace.md),
      label: tr('pf_appearance'),
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
        NavTile(icon: AppIcons.menu, title: tr('st_font'), onTap: onSettings),
      ],
    );
  }
}

/// BAHASA DAN UANG: pintu pengaturan (Task 4 isi kartu bahasanya).
class _LangMoneySection extends StatelessWidget {
  final VoidCallback onSettings;

  const _LangMoneySection({required this.onSettings});

  @override
  Widget build(BuildContext context) {
    return LabeledSectionCard(
      margin: const EdgeInsets.only(bottom: SsrSpace.md),
      label: tr('pf_langmoney'),
      children: [
        NavTile(icon: AppIcons.menu, title: tr('st_lang'), onTap: onSettings),
      ],
    );
  }
}

/// PENGINGAT: pintu pengaturan (Task 7 isi kartu pengingatnya).
class _ReminderSection extends StatelessWidget {
  final VoidCallback onSettings;

  const _ReminderSection({required this.onSettings});

  @override
  Widget build(BuildContext context) {
    return LabeledSectionCard(
      margin: const EdgeInsets.only(bottom: SsrSpace.md),
      label: tr('pf_reminder'),
      children: [
        NavTile(
          icon: AppIcons.menu,
          title: tr('st_reminder_on'),
          onTap: onSettings,
        ),
      ],
    );
  }
}

/// KEAMANAN: pintu PIN + keluar sesi.
class _SecuritySection extends StatelessWidget {
  final VoidCallback onSettings;
  final VoidCallback onLogout;

  const _SecuritySection({required this.onSettings, required this.onLogout});

  @override
  Widget build(BuildContext context) {
    return LabeledSectionCard(
      margin: const EdgeInsets.only(bottom: SsrSpace.md),
      label: tr('pf_security'),
      children: [
        NavTile(icon: AppIcons.lock, title: tr('st_pin'), onTap: onSettings),
        const Divider(height: 1),
        NavTile(icon: AppIcons.logout, title: tr('o_logout'), onTap: onLogout),
      ],
    );
  }
}

/// TENTANG: changelog membuka layar log; bagikan dan masukan via
/// share sheet; bantuan, privasi, dan tentang berupa dialog statis.
class _AboutSection extends StatelessWidget {
  final VoidCallback onChangelog;

  const _AboutSection({required this.onChangelog});

  Future<void> _info(BuildContext context, String titleKey, String body) {
    return showDialog<void>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(tr(titleKey)),
        content: Text(body),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: Text(tr('back')),
          ),
        ],
      ),
    );
  }

  void _shareApp() {
    Share.share('${tr('au_title')} - ${tr('in_brand_sub')}');
  }

  void _feedback() {
    Share.share('${tr('ab_feedback')} ${tr('au_title')} ${AppInfo.version}');
  }

  @override
  Widget build(BuildContext context) {
    return LabeledSectionCard(
      label: tr('pf_about'),
      children: [
        NavTile(
          icon: AppIcons.menu,
          title: tr('ab_about'),
          subtitle: AppInfo.version,
          onTap: () => _info(
            context,
            'ab_about',
            '${tr('sp_tagline')}\n${AppInfo.version}',
          ),
        ),
        const Divider(height: 1),
        NavTile(
          icon: AppIcons.reports,
          title: tr('ab_changelog'),
          onTap: onChangelog,
        ),
        const Divider(height: 1),
        NavTile(
          icon: AppIcons.error,
          title: tr('ab_help'),
          onTap: () => _info(context, 'ab_help', tr('ab_help_body')),
        ),
        const Divider(height: 1),
        NavTile(
          icon: AppIcons.invite,
          title: tr('ab_feedback'),
          onTap: _feedback,
        ),
        const Divider(height: 1),
        NavTile(
          icon: AppIcons.addUser,
          title: tr('ab_share'),
          onTap: _shareApp,
        ),
        const Divider(height: 1),
        NavTile(
          icon: AppIcons.lock,
          title: tr('ab_privacy'),
          onTap: () => _info(context, 'ab_privacy', tr('ab_privacy_body')),
        ),
      ],
    );
  }
}
