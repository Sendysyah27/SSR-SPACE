import 'dart:async';

import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:ssr_space/utils/mask.dart';
import 'package:ssr_space/services/announcement_notify.dart';
import 'package:ssr_space/services/announcement_service.dart';
import 'package:ssr_space/services/app_settings.dart';
import 'package:ssr_space/services/auto_saved_notify.dart';
import 'package:ssr_space/services/budget_alert_notify.dart';
import 'package:ssr_space/services/foreground_track.dart';
import 'package:ssr_space/services/notif_track_service.dart';
import 'package:ssr_space/services/offline_cache.dart';
import 'package:ssr_space/services/realtime_sync.dart';
import 'package:ssr_space/services/share_intake.dart';
import 'package:ssr_space/services/pin_link_verify.dart';
import 'package:ssr_space/services/session_service.dart';
import 'package:ssr_space/services/transaction_service.dart';
import 'package:ssr_space/theme/app_icons.dart';
import 'package:ssr_space/theme/dribbble_tokens.dart';
import 'package:ssr_space/screens/lainnya/ai_chat_screen.dart';
import 'package:ssr_space/utils/org_prefs.dart';
import 'package:ssr_space/utils/strings.dart';
import 'package:ssr_space/widgets/tx_detail_sheet.dart';
import 'package:ssr_space/widgets/tx_input_sheet.dart';
import 'package:ssr_space/widgets/input_mode_sheet.dart';
import 'package:ssr_space/screens/auth/lock_screen.dart';
import 'package:ssr_space/screens/auth/set_password_screen.dart';
import 'package:ssr_space/screens/beranda/beranda_screen.dart';
import 'package:ssr_space/screens/budget/budgets_screen.dart';
import 'package:ssr_space/screens/lainnya/other_screen.dart';
import 'package:ssr_space/screens/laporan/reports_screen.dart';
import 'package:ssr_space/screens/transaksi/transactions_screen.dart';

class MainShell extends StatefulWidget {
  final SessionService session;
  const MainShell({super.key, required this.session});
  @override
  State<MainShell> createState() => _MainShellState();
}

class _MainShellState extends State<MainShell> with WidgetsBindingObserver {
  int index = 0;
  final berandaKey = GlobalKey<BerandaScreenState>();
  final budgetKey = GlobalKey<BudgetsScreenState>();
  final reportsKey = GlobalKey<ReportsScreenState>();
  final txKey = GlobalKey<TransactionsScreenState>();
  bool _resumed = true;
  bool _detailOpen = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    // force: resubscribe bila stream sempat error / app resume dari background
    NotifTrack.ensureListening(force: true);
    unawaited(ForegroundTrack.syncFromPrefs());
    unawaited(_ensureRealtime());
    // Pengumuman baru: notif sekali per id + segarkan badge hub (fail-silent).
    unawaited(_checkAnnouncements());
    netOnline.addListener(_onNetChanged);
    // Probe kunci untuk ShareIntake (jalur hangat tak punya SessionService).
    ShareIntake.isLocked = () {
      final s = widget.session;
      return s.hasPin &&
          s.shouldRelock(
            timeout: Duration(minutes: lockTimeoutMinutes.value),
          );
    };
    WidgetsBinding.instance.addPostFrameCallback((_) => _checkRecovery());
    WidgetsBinding.instance.addPostFrameCallback(
      (_) => _checkDetailThenQuick(),
    );
  }

  @override
  void dispose() {
    netOnline.removeListener(_onNetChanged);
    ShareIntake.isLocked = () => false;
    ShareIntake.detachWarm();
    unawaited(RealtimeSync.stop());
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  /// Internet kembali setelah offline: sinkron ulang semua tab.
  void _onNetChanged() {
    if (mounted && netOnline.value) _reloadAll();
  }

  /// Langganan realtime org aktif; ledakan event → muat ulang semua tab.
  /// Ganti workspace = MainShell baru → resubscribe otomatis.
  Future<void> _ensureRealtime() async {
    if (!mounted) return;
    try {
      final orgId = await activeOrgId();
      if (!mounted || orgId.isEmpty) return;
      await RealtimeSync.ensure(
        orgId,
        onBurst: () {
          if (mounted) _reloadAll();
        },
      );
    } catch (_) {}
  }

  /// Muat ulang semua tab (dipakai burst realtime).
  void _reloadAll() {
    berandaKey.currentState?.reload();
    txKey.currentState?.reload();
    budgetKey.currentState?.reload();
    reportsKey.currentState?.reload();
  }

  /// Alert budget baru (mis. dicatat perangkat lain). Idempoten.
  Future<void> _checkBudgetAlerts() async {
    try {
      final orgId = await activeOrgId();
      if (!mounted || orgId.isEmpty) return;
      await BudgetAlertNotify.check(orgId);
    } catch (_) {}
  }

  /// Pengumuman baru: notif lokal sekali per id + segarkan angka badge di
  /// hub. Idempoten, fail-silent (RPC belum dimigrasi / offline aman).
  Future<void> _checkAnnouncements() async {
    try {
      await AnnouncementNotify.checkAndNotify();
      await refreshUnreadBadge();
    } catch (_) {}
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    super.didChangeAppLifecycleState(state);
    if (state == AppLifecycleState.resumed) {
      _resumed = true;
      unawaited(_checkRelock());
      NotifTrack.ensureListening(force: true);
      unawaited(ForegroundTrack.syncFromPrefs());
      // Realtime bisa putus saat background: pastikan ulang + muat ulang
      // (reload ini juga fallback bila realtime mati total).
      unawaited(_ensureRealtime());
      // Alert budget baru dari perangkat lain (idempoten, fail-silent).
      unawaited(_checkBudgetAlerts());
      // Pengumuman baru + segarkan badge (idempoten, fail-silent).
      unawaited(_checkAnnouncements());
      unawaited(_checkDetailThenQuick());
      _checkRecovery();
      // Poll budget alerts tiap resume supaya banner/badge segar
      // walau tab Budget sedang tidak aktif.
      budgetKey.currentState?.reload();
      _reloadTab(index);
    } else {
      _resumed = false;
      widget.session.touch();
    }
  }

  /// Kunci ulang saat kembali dari background melewati timeout
  /// (hanya bila PIN terpasang). Sebelumnya shouldRelock tak dipanggil
  /// siapa pun — timeout 5 menit cuma tulisan.
  Future<void> _checkRelock() async {
    if (!mounted) return;
    final session = widget.session;
    if (!session.hasPin) return;
    if (!session.shouldRelock(
      timeout: Duration(minutes: lockTimeoutMinutes.value),
    )) {
      return;
    }
    await Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => LockScreen(session: session),
      ),
    );
    session.touch();
  }

  /// Detail dulu, quick-entry sesudahnya (SERIAL, anti-tumpuk sheet):
  /// _checkDetail mengklaim _detailOpen sinkron di entry; quick-entry
  /// jalan setelah detail selesai (ditutup/tanpa antrean). Tanpa interleave.
  Future<void> _checkDetailThenQuick() async {
    await _checkDetail();
    await _checkQuickEntry();
  }

  /// Konsumsi antrean quick-entry/share (dingin + hangat): buka sheet
  /// bila ada; tersimpan -> muat ulang semua tab. Dilewati bila detail
  /// tersimpan sedang dibuka (hindari tumpuk sheet dengan _checkDetail).
  Future<void> _checkQuickEntry() async {
    if (!mounted || _detailOpen) return;
    // Timeout lewat (relock tertunda) -> biarkan antre; dikonsumsi
    // resume berikutnya sesudah unlock (terkunci tak boleh buka sheet).
    final session = widget.session;
    if (session.hasPin &&
        session.shouldRelock(
          timeout: Duration(minutes: lockTimeoutMinutes.value),
        )) {
      return;
    }
    ShareIntake.attachWarm(context);
    final saved = await ShareIntake.consumeAll(context);
    if (saved && mounted) _reloadAll();
  }

  /// Link lupa-password diketuk saat app sudah masuk (hangat): arahkan ke
  /// layar password baru. Flag di-reset layar itu setelah tersimpan.
  void _checkRecovery() {
    if (!mounted || !passwordRecovery.value) return;
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => SetPasswordScreen(session: widget.session),
      ),
    );
  }

  /// Buka detail read-only bila ada ketuk notif tersimpan.  /// Prefs ditulis AutoSavedNotify saat notif tampil maupun diketuk.
  Future<void> _checkDetail() async {
    if (_detailOpen || !_resumed || !mounted) return;
    // Klaim sinkron SEBELUM await pertama: cegah interleave _checkQuickEntry
    // (keduanya dipicu bingkai/resume yang sama). finally mengembalikan.
    _detailOpen = true;
    try {
      final prefs = await SharedPreferences.getInstance();
      final txId = prefs.getString(AutoSavedNotify.lastDetailKey);
      if (txId == null || txId.isEmpty || !mounted) return;
      final orgId = await activeOrgId();
      if (orgId.isEmpty || !mounted) return;
      final tx = await TransactionService().getById(orgId, txId);
      await prefs.remove(AutoSavedNotify.lastDetailKey);
      if (!mounted) return;
      if (tx == null) return;
      final go = await showTxDetailSheet(context, tx, orgId);
      if (go == true && mounted) _select(1);
    } catch (_) {
    } finally {
      _detailOpen = false;
    }
  }

  Future<void> _openInput() async {
    final mode = await showInputModeSheet(context);
    if (mode == null || !mounted) return;
    if (await openTxInputSheet(
      context,
      initialMode: mode == TxInputMode.live ? null : mode,
    )) {
      berandaKey.currentState?.reload();
      txKey.currentState?.reload();
      budgetKey.currentState?.reload();
      reportsKey.currentState?.reload();
    }
  }

  /// Profil dibuka sebagai route (bukan tab): avatar kiri-atas Beranda.
  /// Kembali dari Profil = muat ulang tab aktif (pengaturan bisa berubah).
  Future<void> _openProfil() async {
    await Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => OtherScreen(session: widget.session),
      ),
    );
    if (mounted) _reloadTab(index);
  }

  /// Mang AI dibuka sebagai route (bukan tab): dari sheet Aksi Cepat.
  /// Kembali = muat ulang tab aktif.
  Future<void> _openMangAi() async {
    await Navigator.of(context).push(
      MaterialPageRoute(builder: (_) => const AiChatScreen()),
    );
    if (mounted) _reloadTab(index);
  }

  void _select(int i) {
    setState(() => index = i);
    _reloadTab(i);
  }

  /// Muat ulang tab yang dibuka supaya data baru (otomatis/manual)
  /// langsung tampil tanpa keluar-masuk app.
  void _reloadTab(int i) {
    if (i == 0) berandaKey.currentState?.reload();
    if (i == 1) txKey.currentState?.reload();
    if (i == 2) budgetKey.currentState?.reload();
    if (i == 3) reportsKey.currentState?.reload();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Column(
        children: [
          ValueListenableBuilder<bool>(
            valueListenable: netOnline,
            builder: (context, online, _) => online
                ? const SizedBox.shrink()
                : _OfflineBar(onRetry: () => _reloadAll()),
          ),
          Expanded(
            child: ValueListenableBuilder<bool>(
              valueListenable: maskAmounts,
              builder: (context, masked, child) => IndexedStack(
                index: index,
                children: [
                  BerandaScreen(
                    key: berandaKey,
                    onCatat: () => _select(1),
                    onBudget: () => _select(2),
                    onLaporan: () => _select(3),
                    onProfil: _openProfil,
                  ),
                  TransactionsScreen(key: txKey),
                  BudgetsScreen(key: budgetKey),
                  ReportsScreen(key: reportsKey),
                ],
              ),
            ),
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton(
        heroTag: 'catat',
        onPressed: _openInput,
        backgroundColor: DribTokens.primary,
        foregroundColor: DribTokens.navy,
        tooltip: tr('act_catat'),
        child: const DuoIcon(AppIcons.add),
      ),
      floatingActionButtonLocation:
          FloatingActionButtonLocation.centerDocked,
      bottomNavigationBar: _DockedNav(
        index: index,
        onSelect: _select,
      ),
    );
  }
}

/// Strip offline global: data terakhir tersimpan + tombol muat ulang.
/// Muncul bila panggilan jaringan gagal (tanpa plugin konektivitas).
class _OfflineBar extends StatelessWidget {
  final VoidCallback onRetry;

  const _OfflineBar({required this.onRetry});

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Container(
      width: double.infinity,
      color: scheme.error.withValues(alpha: 0.12),
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
      child: SafeArea(
        bottom: false,
        child: Row(
          children: [
            Expanded(
              child: Text(
                tr('off_s'),
                style: Theme.of(context)
                    .textTheme
                    .bodySmall
                    ?.copyWith(color: scheme.error),
              ),
            ),
            TextButton(
              onPressed: onRetry,
              style: TextButton.styleFrom(
                visualDensity: VisualDensity.compact,
              ),
              child: Text(tr('off_retry')),
            ),
          ],
        ),
      ),
    );
  }
}

/// Navigasi bawah TAHAP 2 restyle: BottomAppBar putih dengan coakan (notch)
/// untuk FAB '+' di tengah dan 4 tab (2 kiri + 2 kanan coakan).
/// Chat AI tidak lagi di navbar; dibuka dari sheet "Aksi Cepat" (FAB '+').
class _DockedNav extends StatelessWidget {
  final int index;
  final ValueChanged<int> onSelect;

  const _DockedNav({
    required this.index,
    required this.onSelect,
  });

  @override
  Widget build(BuildContext context) {
    return BottomAppBar(
      shape: const CircularNotchedRectangle(),
      notchMargin: 8,
      color: DribTokens.card,
      child: Row(
        children: [
          _NavBtn(
            icon: AppIcons.home,
            label: tr('nav_beranda'),
            selected: index == 0,
            onTap: () => onSelect(0),
          ),
          _NavBtn(
            icon: AppIcons.transactions,
            label: tr('nav_transaksi'),
            selected: index == 1,
            onTap: () => onSelect(1),
          ),
          // Ruang coakan FAB tengah.
          const SizedBox(width: 72),
          _NavBtn(
            icon: AppIcons.budget,
            label: tr('nav_budget'),
            selected: index == 2,
            onTap: () => onSelect(2),
          ),
          _NavBtn(
            icon: AppIcons.reports,
            label: tr('nav_laporan'),
            selected: index == 3,
            onTap: () => onSelect(3),
          ),
        ],
      ),
    );
  }
}

/// Satu tombol tab: ikon + label, aktif biru, nonaktif navy redup.
class _NavBtn extends StatelessWidget {
  final IconData icon;
  final String label;
  final bool selected;
  final VoidCallback onTap;

  const _NavBtn({
    required this.icon,
    required this.label,
    required this.selected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final color = selected
        ? DribTokens.primary
        : DribTokens.navy.withValues(alpha: 0.55);
    return Expanded(
      child: InkWell(
        customBorder: const CircleBorder(),
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 8),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              DuoIcon(icon, color: color),
              const SizedBox(height: 2),
              Text(
                label,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  fontSize: 11,
                  fontWeight:
                      selected ? FontWeight.w700 : FontWeight.w500,
                  color: color,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
