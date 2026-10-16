import 'dart:io';

import 'package:flutter/material.dart';
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:ssr_space/utils/mask.dart';
import 'package:ssr_space/services/backup_export.dart';
import 'package:ssr_space/services/budget_alerts.dart';
import 'package:ssr_space/services/billing_service.dart';
import 'package:ssr_space/services/error_reporter.dart';
import 'package:ssr_space/services/foreground_track.dart';
import 'package:ssr_space/services/wallet_service.dart';
import 'package:ssr_space/services/space_logic.dart';
import 'package:ssr_space/services/space_service.dart';
import 'package:ssr_space/services/supabase_config.dart';
import 'package:ssr_space/services/session_service.dart';
import 'package:ssr_space/services/month.dart';
import 'package:ssr_space/theme/app_icons.dart';
import 'package:ssr_space/theme/app_theme.dart';
import 'package:ssr_space/theme/dribbble_tokens.dart';
import 'package:ssr_space/utils/app_info.dart';
import 'package:ssr_space/screens/budget/budgets_screen.dart';
import 'package:ssr_space/screens/lainnya/billing_screen.dart';
import 'package:ssr_space/screens/lainnya/backup_screen.dart';
import 'package:ssr_space/screens/lainnya/categories_screen.dart';
import 'package:ssr_space/screens/lainnya/help_screen.dart';
import 'package:ssr_space/screens/lainnya/arcade_screen.dart';
import 'package:ssr_space/screens/lainnya/ai_chat_screen.dart';
import 'package:ssr_space/screens/lainnya/goals_screen.dart';
import 'package:ssr_space/screens/lainnya/save30_screen.dart';
import 'package:ssr_space/screens/lainnya/recurring_bills_screen.dart';
import 'package:ssr_space/screens/lainnya/bill_splits_screen.dart';
import 'package:ssr_space/screens/lainnya/debts_screen.dart';
import 'package:ssr_space/screens/lainnya/subscriptions_screen.dart';
import 'package:ssr_space/screens/lainnya/import_preview_screen.dart';
import 'package:ssr_space/screens/lainnya/settings_screen.dart';
import 'package:ssr_space/screens/laporan/reports_screen.dart';
import 'package:ssr_space/screens/transaksi/transactions_screen.dart';
import 'package:ssr_space/screens/workspace/invite_screen.dart';
import 'package:ssr_space/screens/workspace/family_screen.dart';
import 'package:ssr_space/screens/workspace/space_activity_screen.dart';
import 'package:ssr_space/screens/workspace/workspace_detail_screen.dart';
import 'package:ssr_space/screens/lainnya/notif_settings_screen.dart';
// E-Money NFC.
import 'package:ssr_space/screens/lainnya/nfc_cards_screen.dart';
import 'package:ssr_space/screens/lainnya/settings_search.dart';
import 'package:ssr_space/screens/lainnya/update_log_screen.dart';
import 'package:ssr_space/screens/workspace/org_switcher_screen.dart';
import 'package:ssr_space/screens/auth/splash_screen.dart';
import 'package:ssr_space/screens/dompet/wallets_screen.dart';
import 'package:ssr_space/widgets/labeled_section_card.dart';
import 'package:ssr_space/widgets/nav_tile.dart';
import 'package:ssr_space/utils/strings.dart';
import 'package:ssr_space/utils/org_prefs.dart';
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

  /// Naik tiap _openBudgets selesai: picu _DataSection ambil ulang badge.
  int _budgetNonce = 0;

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
    return _OtherMeta(
      orgName: orgName,
      plan: plan,
      tracking: tracking,
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
            style: TextButton.styleFrom(
              foregroundColor: Theme.of(ctx).colorScheme.error,
            ),
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

  /// Buka Budget lalu tandai seen (prefs saja, tanpa write server).
  /// Badge tile = count alerts bulan ini minus seen.
  Future<void> _openBudgets() async {
    await _push(const BudgetsScreen());
    try {
      final orgId = await activeOrgId();
      if (orgId.isEmpty) return;
      final m = currentMonth();
      final alerts = await fetchAlerts(orgId, m);
      await markBudgetAlertsSeen(orgId, m, alerts.length);
    } catch (_) {
      // Fail-open: badge dihitung ulang saat build berikut.
    }
    if (mounted) setState(() => _budgetNonce++);
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

  /// Dialog info hub (Tentang/Bantuan/Privasi): isi sama persis dengan
  /// dialog di seksi Tentang, supaya hasil search tak diam tak beraksi.
  /// [short] = 'about' | 'help' | 'privacy' (awalan 'hub_' sudah dikupas).
  Future<void> _showHubInfo(String short) async {
    if (!mounted) return;
    final key = 'ab_$short';
    final body = switch (short) {
      'help' => tr('ab_help_body'),
      'privacy' => tr('ab_privacy_body'),
      _ => '${tr('sp_tagline')}\n${AppInfo.version}',
    };
    await showDialog<void>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(tr(key)),
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

  /// Hapus cache lokal saja (cache dompet sheet + sisa pref koreksi lama).
  /// Tak pernah menyentuh data Supabase.
  Future<void> _clearLocalCache() async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(tr('o_clearcache_t')),
        content: Text(tr('o_clearcache_t')),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: Text(tr('cancel')),
          ),
          TextButton(
            style: TextButton.styleFrom(
              foregroundColor: Theme.of(ctx).colorScheme.error,
            ),
            onPressed: () => Navigator.pop(ctx, true),
            child: Text(tr('tx_delete')),
          ),
        ],
      ),
    );
    if (ok != true || !mounted) return;
    WalletCache.invalidate();
    try {
      final p = await SharedPreferences.getInstance();
      await p.remove('correct_popup');
      await p.remove('pending_correct_tx');
      await p.remove('last_detail_tx');
    } catch (_) {}
    if (!mounted) return;
    ScaffoldMessenger.of(context)
        .showSnackBar(SnackBar(content: Text(tr('o_clearcache_done'))));
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
  /// baris P2 menampilkan dialog msg_p2. Kunci hub (o_mask, tentang)
  /// langsung beraksi di sini supaya tak ada hasil yang diam tak beraksi.
  Future<void> _openSearch() async {
    final key = await showSearch<String?>(
      context: context,
      delegate: SettingsSearchDelegate(),
    );
    if (!mounted || key == null) return;
    if (key == 'hub_mask') {
      await setMaskAmounts(!maskAmounts.value);
      return;
    }
    if (key == 'hub_about' || key == 'hub_privacy') {
      await _showHubInfo(key.substring(4));
      return;
    }    if (key == 'hub_share') {
      Share.share('${tr('au_title')} - ${tr('in_brand_sub')}');
      return;
    }
    if (key == 'hub_feedback') {
      Share.share('${tr('ab_feedback')} ${tr('au_title')} ${AppInfo.version}');
      return;
    }
    if (key == 'settings' || key.startsWith('settings:')) {
      final focus = key.contains(':') ? key.split(':').last : null;
      await _push(SettingsScreen(focus: focus));
      return;
    }
    switch (key) {
      case 'wallets':
        await _push(const WalletsScreen());
      case 'categories':
        await _push(const CategoriesScreen());
      case 'budgets':
        await _openBudgets();
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
      case 'family':
        await _push(const FamilyScreen());
      case 'detail':
        await _openWorkspaceDetail();
      case 'space_activity':
        await _push(const SpaceActivityScreen());
      case 'billing':
        await _push(const BillingScreen());
      case 'changelog':
        await _push(const UpdateLogScreen());
      case 'help':
        await _push(const HelpScreen());
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

  /// AppBar hub: judul + aksi cari pengaturan.
  AppBar _appBar() {
    return AppBar(
      title: Text(tr('nav_profil')),
      actions: [
        IconButton(
          icon: const DuoIcon(AppIcons.search),
          tooltip: tr('search_settings_hint'),
          onPressed: _openSearch,
        ),
      ],
    );
  }

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
      backgroundColor: DribTokens.bg,
      appBar: _appBar(),
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
            tracking: meta?.tracking == true,
            backupBusy: backingUp,
            budgetNonce: _budgetNonce,
            onSwitch: () => _push(OrgSwitcherScreen(session: widget.session)),
            onInvite: () => _push(const InviteScreen()),
            onFamily: () => _push(const FamilyScreen()),
            onDetail: _openWorkspaceDetail,
            onActivity: () => _push(const SpaceActivityScreen()),
            onBilling: () => _push(const BillingScreen()),
            onWallets: () => _push(const WalletsScreen()),
            onCategories: () => _push(const CategoriesScreen()),
            onBudgets: _openBudgets,
            onHistory: () => _push(const TransactionsScreen()),
            onBills: () => _push(const RecurringBillsScreen()),
            onDebts: () => _push(const DebtsScreen()),
            onSplits: () => _push(const BillSplitsScreen()),
            onSubs: () => _push(const SubscriptionsScreen()),
            onGoals: () => _push(const GoalsScreen()),
            onSave30: () => _push(const Save30Screen()),
            onArcade: () => _push(const ArcadeScreen()),
            onChat: () => _push(const AiChatScreen()),
            onNfc: () => _push(const NfcCardsScreen()),
            onTracking: () => _push(const NotifSettingsScreen()),
            onBackup: _backup,
            onBackupJson: () => _push(const BackupScreen()),
            onExport: () => _push(const ReportsScreen()),
            onImportP2: () => _push(const ImportPreviewScreen()),
            onClearCache: _clearLocalCache,
            onSettings: (f) => _push(SettingsScreen(focus: f)),
            onChangelog: () => _push(const UpdateLogScreen()),
            onHelp: () => _push(const HelpScreen()),
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
  final bool tracking;
  final bool backupBusy;
  final int budgetNonce;
  final VoidCallback onSwitch;
  final VoidCallback onInvite;
  final VoidCallback onFamily;
  final VoidCallback onDetail;
  final VoidCallback onActivity;
  final VoidCallback onBilling;
  final VoidCallback onWallets;
  final VoidCallback onCategories;
  final VoidCallback onBudgets;
  final VoidCallback onHistory;
  final VoidCallback onBills;
  final VoidCallback onDebts;
  final VoidCallback onSplits;
  final VoidCallback onSubs;
  final VoidCallback onGoals;
  final VoidCallback onSave30;
  final VoidCallback onArcade;
  final VoidCallback onChat;
  final VoidCallback onNfc;
  final VoidCallback onTracking;
  final VoidCallback onBackup;
  final VoidCallback onBackupJson;
  final VoidCallback onExport;
  final VoidCallback onImportP2;
  final VoidCallback onClearCache;
  final void Function(String?) onSettings;
  final VoidCallback onChangelog;
  final VoidCallback onHelp;
  final VoidCallback onLogout;

  const _HubList({
    required this.orgName,
    required this.planLabel,
    required this.tracking,
    required this.backupBusy,
    required this.budgetNonce,
    required this.onSwitch,
    required this.onInvite,
    required this.onFamily,
    required this.onDetail,
    required this.onActivity,
    required this.onBilling,
    required this.onWallets,
    required this.onCategories,
    required this.onBudgets,
    required this.onHistory,
    required this.onBills,
    required this.onDebts,
    required this.onSplits,
    required this.onSubs,
    required this.onGoals,
    required this.onSave30,
    required this.onArcade,
    required this.onChat,
    required this.onNfc,
    required this.onTracking,
    required this.onBackup,
    required this.onBackupJson,
    required this.onExport,
    required this.onImportP2,
    required this.onClearCache,
    required this.onSettings,
    required this.onChangelog,
    required this.onHelp,
    required this.onLogout,
  });

  List<Widget> _upper() {
    return [
      _HeaderCard(
        orgName: orgName,
        planLabel: planLabel,
        tracking: tracking,
      ),
      _DataSection(
        onWallets: onWallets,
        onCategories: onCategories,
        onBudgets: onBudgets,
        onHistory: onHistory,
        onBills: onBills,
        onDebts: onDebts,
        onSplits: onSplits,
        onSubs: onSubs,
        onGoals: onGoals,
        onSave30: onSave30,
        onArcade: onArcade,
        onChat: onChat,
        onNfc: onNfc,
        budgetNonce: budgetNonce,
      ),
      _TrackingSection(
        tracking: tracking,
        onOpen: onTracking,
      ),
      _BackupSection(
        backupBusy: backupBusy,
        onBackup: onBackup,
        onBackupJson: onBackupJson,
        onExport: onExport,
        onImportP2: onImportP2,
        onClearCache: onClearCache,
      ),
      _WorkspaceSection(
        orgName: orgName,
        planLabel: planLabel,
        onSwitch: onSwitch,
        onInvite: onInvite,
        onFamily: onFamily,
        onDetail: onDetail,
        onActivity: onActivity,
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
      _AboutSection(onChangelog: onChangelog, onHelp: onHelp),
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

/// Kepala seksi hub: ikon kecil biru + label (pengganti header
/// LabeledSectionCard agar wadah bisa DribCard putih).
class _SectionLabel extends StatelessWidget {
  final IconData icon;
  final String label;
  const _SectionLabel({required this.icon, required this.label});

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        DuoIcon(icon, size: 14, color: DribTokens.primary),
        const SizedBox(width: SsrSpace.xs),
        Text(label, style: Theme.of(context).textTheme.bodySmall),
      ],
    );
  }
}
}

/// HEADER: kartu identitas hero (avatar inisial + nama + chip).
/// TAHAP 8: gradient navy Dribbble, teks putih.
class _HeaderCard extends StatelessWidget {
  final String orgName;
  final String planLabel;
  final bool tracking;

  const _HeaderCard({
    required this.orgName,
    required this.planLabel,
    required this.tracking,
  });

  @override
  Widget build(BuildContext context) {
    const onHero = DribTokens.onNavy;
    final initial = orgName.trim().isEmpty
        ? '?'
        : String.fromCharCode(orgName.trim().runes.first).toUpperCase();
    return Container(
      margin: const EdgeInsets.only(bottom: SsrSpace.md),
      padding: const EdgeInsets.all(SsrSpace.lg),
      decoration: BoxDecoration(
        gradient: DribTokens.balanceGradient,
        borderRadius:
            BorderRadius.circular(DribTokens.sheetRadius),
        boxShadow: DribTokens.cardShadow,
      ),
      child: Row(
        children: [
          Container(
            width: 52,
            height: 52,
            decoration: const BoxDecoration(
              color: DribTokens.accentOrange,
              shape: BoxShape.circle,
            ),
            child: Center(
              child: Text(
                initial,
                style: const TextStyle(
                  color: DribTokens.navy,
                  fontSize: 24,
                  fontWeight: FontWeight.w800,
                ),
              ),
            ),
          ),
          const SizedBox(width: SsrSpace.md),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  orgName,
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    color: onHero,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                const SizedBox(height: SsrSpace.xs),
                Container(
                  padding: const EdgeInsets.symmetric(
                      horizontal: 8, vertical: 3),
                  decoration: BoxDecoration(
                    color: onHero.withValues(alpha: 0.18),
                    borderRadius: BorderRadius.circular(999),
                  ),
                  child: Text(
                    planLabel,
                    style: const TextStyle(
                      color: onHero,
                      fontSize: 11,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
                const SizedBox(height: SsrSpace.xs),
                Text(
                  '${tr('o_tracking')} • ${tr(tracking ? 'nt_on' : 'nt_off')}',
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: onHero.withValues(alpha: 0.7),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

/// DATA: dompet, kategori, budget, riwayat transaksi.
class _DataSection extends StatefulWidget {
  final VoidCallback onWallets;
  final VoidCallback onCategories;
  final VoidCallback onBudgets;
  final VoidCallback onHistory;
  final VoidCallback onBills;
  final VoidCallback onDebts;
  final VoidCallback onSplits;
  final VoidCallback onSubs;
  final VoidCallback onGoals;
  final VoidCallback onSave30;
  final VoidCallback onArcade;
  final VoidCallback onChat;
  final VoidCallback onNfc;
  final int budgetNonce;

  const _DataSection({
    required this.onWallets,
    required this.onCategories,
    required this.onBudgets,
    required this.onHistory,
    required this.onBills,
    required this.onDebts,
    required this.onSplits,
    required this.onSubs,
    required this.onGoals,
    required this.onSave30,
    required this.onArcade,
    required this.onChat,
    required this.onNfc,
    required this.budgetNonce,
  });

  @override
  State<_DataSection> createState() => _DataSectionState();
}

class _DataSectionState extends State<_DataSection> {
  /// Future badge di-cache di State (bukan inline di build) supaya fetch
  /// tak berulang tiap rebuild. Diambil ulang bila nonce berubah.
  late Future<int> _budgetCount;

  @override
  void initState() {
    super.initState();
    _budgetCount = _budgetNewCount();
  }

  @override
  void didUpdateWidget(covariant _DataSection oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.budgetNonce != widget.budgetNonce) {
      _budgetCount = _budgetNewCount();
    }
  }

  /// Badge tile Budget: count alerts bulan ini minus seen. Fail-open 0.
  Future<int> _budgetNewCount() async {
    try {
      final orgId = await activeOrgId();
      if (orgId.isEmpty) return 0;
      final m = currentMonth();
      final alerts = await fetchAlerts(orgId, m);
      final seen = await budgetAlertsSeen(orgId, m);
      return unseenAlerts(alerts.length, seen);
    } catch (_) {
      return 0;
    }
  }

  @override
  Widget build(BuildContext context) {
    return DribCard(
      margin: const EdgeInsets.only(bottom: SsrSpace.md),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _SectionLabel(icon: AppIcons.transactions, label: tr('pf_data')),
          const SizedBox(height: SsrSpace.xs),
        NavTile(
          icon: AppIcons.wallet,
          title: tr('o_wallets'),
          onTap: widget.onWallets,
        ),
        const Divider(height: 1),
        NavTile(
          icon: AppIcons.categoryFallback,
          title: tr('o_cats'),
          subtitle: tr('o_cats_s'),
          onTap: widget.onCategories,
        ),
        const Divider(height: 1),
        FutureBuilder<int>(
          future: _budgetCount,
          builder: (context, snap) {
            final n = snap.data ?? 0;
            return NavTile(
              icon: AppIcons.budget,
              title: tr('nav_budget'),
              subtitle: n > 0 ? '$n ${tr('sp_new')}' : null,
              onTap: widget.onBudgets,
            );
          },
        ),
        const Divider(height: 1),
        NavTile(
          icon: AppIcons.transactions,
          title: tr('nav_transaksi'),
          onTap: widget.onHistory,
        ),
        const Divider(height: 1),
        NavTile(
          icon: AppIcons.bills,
          title: tr('rb_title'),
          onTap: widget.onBills,
        ),
        const Divider(height: 1),
        NavTile(
          icon: AppIcons.billing,
          title: tr('db_title'),
          subtitle: tr('db_sub'),
          onTap: widget.onDebts,
        ),
        const Divider(height: 1),
        NavTile(
          icon: AppIcons.transfer,
          title: tr('bs_title'),
          subtitle: tr('bs_sub'),
          onTap: widget.onSplits,
        ),
        const Divider(height: 1),
        NavTile(
          icon: AppIcons.calendar,
          title: tr('sub_title'),
          subtitle: tr('sub_sub'),
          onTap: widget.onSubs,
        ),
        const Divider(height: 1),
        NavTile(
          icon: AppIcons.topup,
          title: tr('goal_title'),
          subtitle: tr('goal_sub'),
          onTap: widget.onGoals,
        ),
        const Divider(height: 1),
        NavTile(
          icon: AppIcons.success,
          title: tr('sv30_title'),
          subtitle: tr('sv30_sub'),
          onTap: widget.onSave30,
        ),
        const Divider(height: 1),
        NavTile(
          icon: AppIcons.health,
          title: tr('game_title'),
          subtitle: tr('game_sub'),
          onTap: widget.onArcade,
        ),
        const Divider(height: 1),
        NavTile(
          icon: AppIcons.autoBadge,
          title: tr('chat_title'),
          onTap: widget.onChat,
        ),
        const Divider(height: 1),
        NavTile(
          icon: AppIcons.scan,
          title: tr('nfc_title'),
          subtitle: tr('nfc_sub'),
          onTap: widget.onNfc,
        ),
      ],
      ),
    );
  }
}

/// PELACAKAN: pintu pelacakan otomatis.
class _TrackingSection extends StatelessWidget {
  final bool tracking;
  final VoidCallback onOpen;

  const _TrackingSection({
    required this.tracking,
    required this.onOpen,
  });

  @override
  Widget build(BuildContext context) {
    return DribCard(
      margin: const EdgeInsets.only(bottom: SsrSpace.md),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _SectionLabel(icon: AppIcons.tracking, label: tr('pf_tracking')),
          const SizedBox(height: SsrSpace.xs),
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
      ),
    );
  }
}

/// DATA DAN CADANGAN: cadangkan, ekspor laporan, impor, hapus cache lokal.
class _BackupSection extends StatelessWidget {
  final bool backupBusy;
  final VoidCallback onBackup;
  final VoidCallback onBackupJson;
  final VoidCallback onExport;
  final VoidCallback onImportP2;
  final VoidCallback onClearCache;

  const _BackupSection({
    required this.backupBusy,
    required this.onBackup,
    required this.onBackupJson,
    required this.onExport,
    required this.onImportP2,
    required this.onClearCache,
  });

  @override
  Widget build(BuildContext context) {
    return DribCard(
      margin: const EdgeInsets.only(bottom: SsrSpace.md),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _SectionLabel(icon: AppIcons.backup, label: tr('pf_backup')),
          const SizedBox(height: SsrSpace.xs),
        NavTile(
          icon: AppIcons.backup,
          title: tr('o_backup'),
          subtitle: tr('o_backup_s'),
          onTap: backupBusy ? null : onBackup,
        ),
        const Divider(height: 1),
        NavTile(
          icon: AppIcons.backup,
          title: tr('bx_title'),
          subtitle: tr('bx_sub'),
          onTap: onBackupJson,
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
          title: tr('o_clearcache_t'),
          onTap: onClearCache,
        ),
      ],
      ),
    );
  }
}

/// WORKSPACE: undang, ganti, kelola detail, billing paket.
class _WorkspaceSection extends StatelessWidget {
  final String orgName;
  final String planLabel;
  final VoidCallback onSwitch;
  final VoidCallback onInvite;
  final VoidCallback onFamily;
  final VoidCallback onDetail;
  final VoidCallback onActivity;
  final VoidCallback onBilling;

  const _WorkspaceSection({
    required this.orgName,
    required this.planLabel,
    required this.onSwitch,
    required this.onInvite,
    required this.onFamily,
    required this.onDetail,
    required this.onActivity,
    required this.onBilling,
  });

  /// Jumlah log aktivitas lebih baru dari terakhir dibaca. Fail-open 0.
  Future<int> _newCount() async {
    try {
      final orgId = await activeOrgId();
      if (orgId.isEmpty) return 0;
      final svc = SpaceService();
      final rows = await svc.activity(orgId);
      final seen = await svc.lastSeen(orgId);
      return unseenCount(rows.map((r) => r.at).toList(), seen);
    } catch (_) {
      return 0;
    }
  }

  @override
  Widget build(BuildContext context) {
    return DribCard(
      margin: const EdgeInsets.only(bottom: SsrSpace.md),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _SectionLabel(icon: AppIcons.workspace, label: tr('pf_workspace')),
          const SizedBox(height: SsrSpace.xs),
        NavTile(
          icon: AppIcons.invite,
          title: tr('o_invite'),
          subtitle: tr('o_invite_s'),
          onTap: onInvite,
        ),
        const Divider(height: 1),
        NavTile(
          icon: AppIcons.members,
          title: tr('fam_title'),
          subtitle: tr('fam_sub'),
          onTap: onFamily,
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
        FutureBuilder<int>(
          future: _newCount(),
          builder: (context, snap) {
            final n = snap.data ?? 0;
            return NavTile(
              icon: AppIcons.history,
              title: tr('sp_activity'),
              subtitle: n > 0 ? '$n ${tr('sp_new')}' : null,
              onTap: onActivity,
            );
          },
        ),
        const Divider(height: 1),
        NavTile(
          icon: AppIcons.billing,
          title: tr('o_billing'),
          subtitle: tr('o_plan').replaceFirst('{p}', planLabel),
          onTap: onBilling,
        ),
      ],
      ),
    );
  }
}

/// TAMPILAN: toggle samarkan nominal + pintu pengaturan.
class _AppearanceSection extends StatelessWidget {
  final void Function(String?) onSettings;

  const _AppearanceSection({required this.onSettings});

  @override
  Widget build(BuildContext context) {
    return DribCard(
      margin: const EdgeInsets.only(bottom: SsrSpace.md),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _SectionLabel(icon: AppIcons.eye, label: tr('pf_appearance')),
          const SizedBox(height: SsrSpace.xs),
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
          title: tr('st_font'),
          onTap: () => onSettings('font'),
        ),
      ],
      ),
    );
  }
}

/// BAHASA DAN UANG: pintu pengaturan (Task 4 isi kartu bahasanya).
class _LangMoneySection extends StatelessWidget {
  final void Function(String?) onSettings;

  const _LangMoneySection({required this.onSettings});

  @override
  Widget build(BuildContext context) {
    return DribCard(
      margin: const EdgeInsets.only(bottom: SsrSpace.md),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _SectionLabel(icon: AppIcons.billing, label: tr('pf_langmoney')),
          const SizedBox(height: SsrSpace.xs),
        NavTile(
          icon: AppIcons.menu,
          title: tr('st_lang'),
          onTap: () => onSettings('lang'),
        ),
      ],
      ),
    );
  }
}

/// PENGINGAT: pintu pengaturan (Task 7 isi kartu pengingatnya).
class _ReminderSection extends StatelessWidget {
  final void Function(String?) onSettings;

  const _ReminderSection({required this.onSettings});

  @override
  Widget build(BuildContext context) {
    return DribCard(
      margin: const EdgeInsets.only(bottom: SsrSpace.md),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _SectionLabel(icon: AppIcons.clock, label: tr('pf_reminder')),
          const SizedBox(height: SsrSpace.xs),
        NavTile(
          icon: AppIcons.menu,
          title: tr('st_reminder_on'),
          onTap: () => onSettings('reminder'),
        ),
      ],
      ),
    );
  }
}

/// KEAMANAN: pintu PIN + keluar sesi.
class _SecuritySection extends StatelessWidget {
  final void Function(String?) onSettings;
  final VoidCallback onLogout;

  const _SecuritySection({required this.onSettings, required this.onLogout});

  @override
  Widget build(BuildContext context) {
    return DribCard(
      margin: const EdgeInsets.only(bottom: SsrSpace.md),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _SectionLabel(icon: AppIcons.lock, label: tr('pf_security')),
          const SizedBox(height: SsrSpace.xs),
        NavTile(
          icon: AppIcons.lock,
          title: tr('st_pin'),
          onTap: () => onSettings('pin'),
        ),
        const Divider(height: 1),
        NavTile(icon: AppIcons.logout, title: tr('o_logout'), onTap: onLogout),
      ],
      ),
    );
  }
}

/// TENTANG: changelog membuka layar log; bantuan membuka layar tutorial;
/// bagikan dan masukan via share sheet; privasi dan tentang dialog statis.
class _AboutSection extends StatelessWidget {
  final VoidCallback onChangelog;
  final VoidCallback onHelp;

  const _AboutSection({required this.onChangelog, required this.onHelp});

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
    return DribCard(
      margin: const EdgeInsets.only(bottom: SsrSpace.md),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _SectionLabel(icon: AppIcons.menu, label: tr('pf_about')),
          const SizedBox(height: SsrSpace.xs),
        NavTile(
          icon: AppIcons.menu,
          title: tr('ab_about'),
          subtitle: AppInfo.version,
          onTap: () => _info(
            context,
            'ab_about',
            '${tr('sp_tagline')}\n${AppInfo.version}\n${tr('ab_credits')}',
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
          onTap: onHelp,
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
