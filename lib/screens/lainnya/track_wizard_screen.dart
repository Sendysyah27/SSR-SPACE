import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:ssr_space/services/foreground_track.dart';
import 'package:ssr_space/services/notif_parse.dart';
import 'package:ssr_space/services/notif_track_service.dart';
import 'package:ssr_space/services/wallet_service.dart';
import 'package:ssr_space/models/wallet.dart';
import 'package:ssr_space/theme/app_theme.dart';
import 'package:ssr_space/utils/strings.dart';
import 'package:ssr_space/widgets/bank_track_row.dart';
import 'package:ssr_space/widgets/primary_button.dart';
import 'package:ssr_space/widgets/section_card.dart';
import 'package:ssr_space/widgets/status_chip.dart';

/// Kunci prefs: wizard 3 langkah sudah selesai/dilewati (tak ditawar lagi).
const trackWizardDoneKey = 'track_wizard_done';

/// Wizard auto-track 3 langkah (Batch 2 Sprint): izin listener → master
/// switch → mapping dompet. Fail-open: tak ada langkah yang mengunci;
/// Lewati/Selesai selalu tersedia. Nulis kunci prefs yang sama dengan
/// NotifSettingsScreen (satu sumber kebenaran, tanpa state ganda).
class TrackWizardScreen extends StatefulWidget {
  const TrackWizardScreen({super.key});
  @override
  State<TrackWizardScreen> createState() => _TrackWizardScreenState();
}

class _TrackWizardScreenState extends State<TrackWizardScreen> {
  final _pages = PageController();
  int step = 0;
  bool loading = true;
  bool granted = false;
  bool master = false;
  List<Wallet> wallets = [];
  Map<String, bool> perApp = {};
  Map<String, String?> walletFor = {};
  Map<String, String> catFor = {};

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void dispose() {
    _pages.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    final prefs = await SharedPreferences.getInstance();
    final g = await NotifTrack.permissionGranted();
    List<Wallet> ws = [];
    try {
      final orgId = prefs.getString('active_org_id') ?? '';
      if (orgId.isNotEmpty) ws = await WalletService().list(orgId);
    } catch (e) {
      debugPrint('wizard wallet load: $e');
    }
    if (!mounted) return;
    setState(() {
      granted = g;
      master = prefs.getBool('track_master') ?? false;
      wallets = ws;
      perApp = {
        for (final a in watchedApps)
          a.label: prefs.getBool('track_${a.label}') ?? true,
      };
      walletFor = {
        for (final a in watchedApps)
          a.label: prefs.getString(NotifTrack.walletPrefKey(a.label)),
      };
      catFor = {
        for (final a in watchedApps)
          a.label: prefs.getString(NotifTrack.catPrefKey(a.label)) ?? '',
      };
      loading = false;
    });
  }

  Future<void> _requestPermission() async {
    await NotifTrack.requestPermission();
    await _load();
  }

  Future<void> _setMaster(bool v) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('track_master', v);
    if (!mounted) return;
    setState(() => master = v);
    await ForegroundTrack.syncFromPrefs();
  }

  Future<void> _setApp(String label, bool v) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('track_$label', v);
    if (!mounted) return;
    setState(() => perApp[label] = v);
  }

  Future<void> _setWallet(String label, String? id) async {
    final prefs = await SharedPreferences.getInstance();
    if (id == null || id.isEmpty) {
      await prefs.remove(NotifTrack.walletPrefKey(label));
    } else {
      await prefs.setString(NotifTrack.walletPrefKey(label), id);
    }
    if (!mounted) return;
    setState(
      () => walletFor[label] = (id == null || id.isEmpty) ? null : id,
    );
  }

  Future<void> _setCat(String label, String value) async {
    final prefs = await SharedPreferences.getInstance();
    final v = value.trim();
    if (v.isEmpty) {
      await prefs.remove(NotifTrack.catPrefKey(label));
    } else {
      await prefs.setString(NotifTrack.catPrefKey(label), v);
    }
    if (!mounted) return;
    setState(() => catFor[label] = v);
  }

  String? _autoMatchLabel(String label) {
    final mapped = walletFor[label];
    if (mapped != null && mapped.isNotEmpty) {
      for (final w in wallets) {
        if (w.id == mapped) return w.name;
      }
    }
    final target = label.toLowerCase();
    for (final w in wallets) {
      final n = w.name.toLowerCase();
      if (n == target || n.contains(target)) return w.name;
    }
    return null;
  }

  void _go(int s) {
    setState(() => step = s.clamp(0, 2));
    _pages.animateToPage(
      step,
      duration: const Duration(milliseconds: 250),
      curve: Curves.easeOut,
    );
  }

  Future<void> _close() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setBool(trackWizardDoneKey, true);
    } catch (_) {}
    if (mounted) Navigator.pop(context, true);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(tr('wz_title')),
        actions: [
          TextButton(
            onPressed: _close,
            child: Text(tr('wz_skip')),
          ),
        ],
      ),
      body: loading
          ? const Center(child: CircularProgressIndicator())
          : Column(
              children: [
                const SizedBox(height: SsrSpace.md),
                _StepDots(step: step),
                const SizedBox(height: SsrSpace.sm),
                Text(
                  tr('wz_step').replaceFirst('{n}', '${step + 1}'),
                  style: Theme.of(context).textTheme.bodySmall,
                ),
                const SizedBox(height: SsrSpace.md),
                Expanded(
                  child: PageView(
                    controller: _pages,
                    physics: const NeverScrollableScrollPhysics(),
                    onPageChanged: (s) => setState(() => step = s),
                    children: [
                      _StepPermission(
                        granted: granted,
                        onRequest: _requestPermission,
                        onRecheck: _load,
                      ),
                      _StepMaster(master: master, onChanged: _setMaster),
                      _StepMapping(
                        wallets: wallets,
                        perApp: perApp,
                        walletFor: walletFor,
                        catFor: catFor,
                        resolveWalletName: _autoMatchLabel,
                        onToggle: _setApp,
                        onWallet: _setWallet,
                        onCategory: _setCat,
                      ),
                    ],
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.all(SsrSpace.lg),
                  child: Row(
                    children: [
                      if (step > 0)
                        TextButton(
                          onPressed: () => _go(step - 1),
                          child: Text(tr('wz_back')),
                        ),
                      const Spacer(),
                      SizedBox(
                        width: 180,
                        child: PrimaryButton(
                          label: tr(step == 2 ? 'wz_done' : 'wz_next'),
                          onPressed: () =>
                              step == 2 ? _close() : _go(step + 1),
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

/// Tiga titik progres langkah.
class _StepDots extends StatelessWidget {
  final int step;
  const _StepDots({required this.step});

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        for (var i = 0; i < 3; i++) ...[
          if (i > 0) const SizedBox(width: SsrSpace.sm),
          Container(
            width: step == i ? 24 : 8,
            height: 8,
            decoration: BoxDecoration(
              color: step == i
                  ? scheme.primary
                  : scheme.primary.withValues(alpha: 0.25),
              borderRadius: BorderRadius.circular(999),
            ),
          ),
        ],
      ],
    );
  }
}

/// Langkah 1: izin baca notifikasi (pintu utama; tanpa ini tak ada yang
/// tercatat). Status jujur + tombol buka pengaturan + cek lagi.
class _StepPermission extends StatelessWidget {
  final bool granted;
  final Future<void> Function() onRequest;
  final Future<void> Function() onRecheck;

  const _StepPermission({
    required this.granted,
    required this.onRequest,
    required this.onRecheck,
  });

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.all(SsrSpace.lg),
      children: [
        SectionCard(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                tr('wz_s1_t'),
                style: Theme.of(context).textTheme.titleMedium,
              ),
              const SizedBox(height: SsrSpace.xs),
              Text(
                tr('wz_s1_s'),
                style: Theme.of(context).textTheme.bodyMedium,
              ),
              const SizedBox(height: SsrSpace.md),
              StatusChip(
                label: granted ? tr('nt_active') : tr('nt_notactive'),
                tone: granted ? StatusTone.accent : StatusTone.neutral,
              ),
              const SizedBox(height: SsrSpace.md),
              Row(
                children: [
                  Expanded(
                    child: PrimaryButton(
                      label: tr('wz_s1_open'),
                      onPressed: onRequest,
                    ),
                  ),
                  const SizedBox(width: SsrSpace.sm),
                  OutlinedButton(
                    onPressed: onRecheck,
                    child: Text(tr('wz_s1_recheck')),
                  ),
                ],
              ),
            ],
          ),
        ),
      ],
    );
  }
}

/// Langkah 2: master switch (satu tombol untuk seluruh pelacakan).
class _StepMaster extends StatelessWidget {
  final bool master;
  final ValueChanged<bool> onChanged;

  const _StepMaster({required this.master, required this.onChanged});

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.all(SsrSpace.lg),
      children: [
        SectionCard(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                tr('wz_s2_t'),
                style: Theme.of(context).textTheme.titleMedium,
              ),
              const SizedBox(height: SsrSpace.xs),
              Text(
                tr('wz_s2_s'),
                style: Theme.of(context).textTheme.bodyMedium,
              ),
              const SizedBox(height: SsrSpace.sm),
              SwitchListTile(
                contentPadding: EdgeInsets.zero,
                title: Text(tr('nt_title')),
                value: master,
                onChanged: onChanged,
              ),
            ],
          ),
        ),
      ],
    );
  }
}

/// Langkah 3: petakan tiap bank ke dompet (pakai ulang BankTrackRow agar
/// identik dengan layar pengaturan).
class _StepMapping extends StatelessWidget {
  final List<Wallet> wallets;
  final Map<String, bool> perApp;
  final Map<String, String?> walletFor;
  final Map<String, String> catFor;
  final String? Function(String) resolveWalletName;
  final void Function(String, bool) onToggle;
  final void Function(String, String?) onWallet;
  final void Function(String, String) onCategory;

  const _StepMapping({
    required this.wallets,
    required this.perApp,
    required this.walletFor,
    required this.catFor,
    required this.resolveWalletName,
    required this.onToggle,
    required this.onWallet,
    required this.onCategory,
  });

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.all(SsrSpace.lg),
      children: [
        Text(
          tr('wz_s3_t'),
          style: Theme.of(context).textTheme.titleMedium,
        ),
        const SizedBox(height: SsrSpace.xs),
        Text(
          tr('wz_s3_s'),
          style: Theme.of(context).textTheme.bodyMedium,
        ),
        const SizedBox(height: SsrSpace.md),
        if (wallets.isEmpty)
          Text(
            tr('nt_nowallet'),
            style: Theme.of(context).textTheme.bodySmall,
          ),
        for (final app in watchedApps) ...[
          const Divider(height: 1),
          BankTrackRow(
            label: app.label,
            subtitle: [
              tr('nt_wallet').replaceFirst(
                '{w}',
                resolveWalletName(app.label) ?? tr('nt_wallet_unset'),
              ),
              if ((catFor[app.label] ?? '').isNotEmpty)
                tr('nt_cat').replaceFirst('{c}', catFor[app.label] ?? ''),
            ].join(' | '),
            value: perApp[app.label] ?? true,
            onChanged: (v) => onToggle(app.label, v),
            showMapping: wallets.isNotEmpty,
            walletValue: walletFor[app.label],
            wallets: wallets,
            onWalletChanged: (v) => onWallet(app.label, v),
            categoryValue: catFor[app.label] ?? '',
            onCategoryChanged: (v) => onCategory(app.label, v),
          ),
        ],
        const SizedBox(height: SsrSpace.xl),
      ],
    );
  }
}
