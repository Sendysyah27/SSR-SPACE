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
import 'package:ssr_space/widgets/entry/ollo_entry_sheet.dart';
import 'package:ssr_space/widgets/entry/voice_draft_sheet.dart';
import 'package:ssr_space/widgets/entry/ocr_scan_sheet.dart';
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

  /// FAB '+' tengah: buka sheet "Aksi Cepat" gaya Ollo berisi 4 pintasan.
  /// - Tambah Transaksi -> entry sheet Ollo.
  /// - Scan Struk -> entry sheet Ollo + langsung picu scan struk.
  /// - Asisten Suara -> alur voice gaya Ollo (listening -> draft -> simpan).
  /// - Chat AI -> route Mang AI (_openMangAi).
  Future<void> _openQuickActions() async {
    final act = await _showQuickActionsSheet();
    if (act == null || !mounted) return;
    switch (act) {
      case _QuickAction.addTx:
        // Nilai balik showOlloEntrySheet sengaja diabaikan agar aman
        // terhadap signature apapun dari TASK A; muat ulang selalu.
        await showOlloEntrySheet(context);
        if (mounted) _reloadAll();
        break;
      case _QuickAction.scan:
        // Sheet Ollo sudah punya tombol kamera; autoScan langsung
        // membuka dialog sumber lalu scan (logika existing _scan).
        await showOlloEntrySheet(context, autoScan: true);
        if (mounted) _reloadAll();
        break;
      case _QuickAction.ocr:
        // Scan OCR on-device (tanpa AI/cloud): kamera/galeri -> parse -> draft.
        if (await openOcrFlow(context) && mounted) _reloadAll();
        break;
      case _QuickAction.voice:
        if (await openOlloVoiceFlow(context) && mounted) _reloadAll();
        break;
      case _QuickAction.chat:
        await _openMangAi();
        break;
    }
  }

  /// Sheet bawah "Aksi Cepat": 5 lingkaran pastel (ikon + label).
  /// Urutan muncul: tengah dulu lalu menyebar (index 2, 1, 3, 0, 4);
  /// satu AnimationController 380ms (scale + fade), tetap ringan.
  Future<_QuickAction?> _showQuickActionsSheet() {
    return showModalBottomSheet<_QuickAction>(
      context: context,
      useSafeArea: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => _QaSheet(
        items: [
          _QaItem(_QuickAction.addTx, tr('qa_add_tx'), AppIcons.add,
              const Color(0xFF5B9BF5)),
          _QaItem(_QuickAction.scan, tr('qa_scan'), AppIcons.scan,
              const Color(0xFF22B07D)),
          _QaItem(_QuickAction.ocr, tr('qa_ocr'),
              Icons.text_snippet_outlined, const Color(0xFFC07A1A)),
          _QaItem(_QuickAction.voice, tr('qa_voice'), AppIcons.voice,
              const Color(0xFFFF9F43)),
          _QaItem(_QuickAction.chat, tr('qa_chat'),
              Icons.smart_toy_outlined, const Color(0xFF00A19A)),
        ],
        onSelect: (act) => Navigator.pop(ctx, act),
      ),
    );
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
        onPressed: _openQuickActions,
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

/// Pilihan item sheet Aksi Cepat (FAB '+').
enum _QuickAction { addTx, scan, ocr, voice, chat }

/// Item lingkaran pastel untuk sheet aksi cepat gaya Ollo.
class _QaItem {
  final _QuickAction action;
  final String label;
  final IconData icon;
  final Color color;
  const _QaItem(this.action, this.label, this.icon, this.color);
}

/// Sheet aksi cepat 5 item dengan stagger animasi (1 AnimationController,
/// 380ms). Urutan muncul: tengah dulu (index 2), lalu 1, 3, 0, 4 menyebar.
/// Background lingkaran transparan soft (light 0.16 / dark 0.30), ikon
/// dicerahkan 25% di dark mode agar terbaca.
class _QaSheet extends StatefulWidget {
  final List<_QaItem> items;
  final ValueChanged<_QuickAction?> onSelect;
  const _QaSheet({required this.items, required this.onSelect});
  @override
  State<_QaSheet> createState() => _QaSheetState();
}

class _QaSheetState extends State<_QaSheet>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 380),
    )..forward();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  /// Urutan stagger: tengah (2) dulu, lalu menyebar (1, 3, 0, 4).
  int _orderIndex(int i) {
    const order = [2, 1, 3, 0, 4];
    return order.indexOf(i);
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Container(
      decoration: BoxDecoration(
        color: DribTokens.cardOf(context),
        borderRadius: const BorderRadius.vertical(
          top: Radius.circular(DribTokens.sheetRadius),
        ),
      ),
      padding: const EdgeInsets.fromLTRB(20, 10, 20, 28),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 40,
            height: 4,
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(2),
              color: scheme.outlineVariant,
            ),
          ),
          const SizedBox(height: 12),
          Text(
            tr('qa_sheet_title'),
            style: Theme.of(context)
                .textTheme
                .titleMedium
                ?.copyWith(fontWeight: FontWeight.w700),
          ),
          const SizedBox(height: 16),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceEvenly,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              for (var i = 0; i < widget.items.length; i++)
                _staggerItem(widget.items[i], i),
            ],
          ),
        ],
      ),
    );
  }

  /// Satu item lingkaran pastel dengan animasi stagger (scale + fade).
  Widget _staggerItem(_QaItem it, int index) {
    final step = _orderIndex(index) / widget.items.length;
    final start = (step * 0.6).clamp(0.0, 0.6);
    final anim = CurvedAnimation(
      parent: _controller,
      curve: Interval(start, (start + 0.4).clamp(0.0, 1.0),
          curve: Curves.easeOut),
    );
    // Rounded square (bukan lingkaran), background BENAR-BENAR transparan:
    // alpha 0.10-0.12 + border 1px alpha 0.2, di light & dark.
    final bg = it.color.withValues(alpha: 0.11);
    final border = it.color.withValues(alpha: 0.20);
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final iconColor =
        isDark ? Color.lerp(it.color, Colors.white, 0.25)! : it.color;
    return AnimatedBuilder(
      animation: anim,
      builder: (ctx, _) {
        final t = anim.value;
        return Opacity(
          opacity: t,
          child: Transform.scale(
            scale: 0.5 + 0.5 * t,
            child: GestureDetector(
              onTap: () => widget.onSelect(it.action),
              child: SizedBox(
                width: 64,
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Container(
                      width: 64,
                      height: 64,
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(20),
                        color: bg,
                        border: Border.all(color: border, width: 1),
                      ),
                      alignment: Alignment.center,
                      child: Icon(it.icon, size: 28, color: iconColor),
                    ),
                    const SizedBox(height: 6),
                    Text(
                      it.label,
                      maxLines: 2,
                      textAlign: TextAlign.center,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        fontSize: 10.5,
                        color: Theme.of(ctx).colorScheme.onSurface,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        );
      },
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
      color: DribTokens.cardOf(context),
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
        : Theme.of(context).colorScheme.onSurfaceVariant;
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
