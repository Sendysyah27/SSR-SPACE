import 'dart:async';

import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:ssr_space/utils/mask.dart';
import 'package:ssr_space/services/foreground_track.dart';
import 'package:ssr_space/services/notif_parse.dart';
import 'package:ssr_space/services/notif_track_service.dart';
import 'package:ssr_space/services/wallet_service.dart';
import 'package:ssr_space/theme/app_icons.dart';
import 'package:ssr_space/theme/app_theme.dart';
import 'package:ssr_space/models/wallet.dart';
import 'package:ssr_space/widgets/bank_track_row.dart';
import 'package:ssr_space/widgets/section_card.dart';
import 'package:ssr_space/widgets/skeletons.dart';
import 'package:ssr_space/widgets/status_chip.dart';

class NotifSettingsScreen extends StatefulWidget {
  const NotifSettingsScreen({super.key});
  @override
  State<NotifSettingsScreen> createState() => _NotifSettingsScreenState();
}

class _NotifSettingsScreenState extends State<NotifSettingsScreen> {
  bool master = false;
  bool granted = false;
  bool serviceConnected = false;
  bool foregroundRunning = false;
  Map<String, bool> perApp = {};
  Map<String, String?> walletFor = {};
  Map<String, String> catFor = {};
  List<Wallet> wallets = [];
  bool loading = true;
  String scanStatus = '';
  bool scanning = false;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final prefs = await SharedPreferences.getInstance();
    final g = await NotifTrack.permissionGranted();
    final conn = g ? await NotifTrack.isServiceConnected() : false;
    final fr = await ForegroundTrack.isRunning;
    List<Wallet> ws = [];
    try {
      final orgId = prefs.getString('active_org_id') ?? '';
      if (orgId.isNotEmpty) ws = await WalletService().list(orgId);
    } catch (e) {
      debugPrint('wallet map load: $e');
    }
    if (!mounted) return;
    setState(() {
      master = prefs.getBool('track_master') ?? false;
      granted = g;
      serviceConnected = conn;
      foregroundRunning = fr;
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
    unawaited(_scan());
  }

  Future<void> _scan() async {
    if (scanning) return;
    setState(() => scanning = true);
    final msg = await NotifTrack.refreshActive();
    final conn = await NotifTrack.isServiceConnected();
    if (!mounted) return;
    setState(() {
      scanning = false;
      scanStatus = msg;
      serviceConnected = conn;
    });
  }

  Future<void> _setMaster(bool v) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('track_master', v);
    setState(() => master = v);
    await ForegroundTrack.syncFromPrefs();
    final fr = await ForegroundTrack.isRunning;
    if (!mounted) return;
    setState(() => foregroundRunning = fr);
  }

  Future<void> _setApp(String label, bool v) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('track_$label', v);
    setState(() => perApp[label] = v);
  }

  Future<void> _setWallet(String label, String? id) async {
    final prefs = await SharedPreferences.getInstance();
    if (id == null || id.isEmpty) {
      await prefs.remove(NotifTrack.walletPrefKey(label));
    } else {
      await prefs.setString(NotifTrack.walletPrefKey(label), id);
    }
    setState(() => walletFor[label] = (id == null || id.isEmpty) ? null : id);
  }

  Future<void> _setCat(String label, String value) async {
    final prefs = await SharedPreferences.getInstance();
    final v = value.trim();
    if (v.isEmpty) {
      await prefs.remove(NotifTrack.catPrefKey(label));
    } else {
      await prefs.setString(NotifTrack.catPrefKey(label), v);
    }
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

  Future<void> _requestPermission() async {
    await NotifTrack.requestPermission();
    await _load();
  }

  Future<void> _reconnect() async {
    await NotifTrack.reconnectService();
    await Future.delayed(const Duration(milliseconds: 900));
    if (!mounted) return;
    await _load();
  }

  void _onNotifSaved(String msg) {
    if (!mounted) return;
    setState(() {});
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(msg)));
  }

  @override
  Widget build(BuildContext context) {
    if (loading) {
      return Scaffold(
        appBar: AppBar(title: const Text('Pelacakan otomatis')),
        body: const NotifSettingsSkeleton(),
      );
    }
    return Scaffold(
      appBar: AppBar(title: const Text('Pelacakan otomatis')),
      body: ListView(
        padding: const EdgeInsets.all(SsrSpace.lg),
        children: [
          Text(
            'Aplikasi membaca notifikasi bank dan dompet di HP ini saja, lalu mencatatnya otomatis ke workspace aktif. Isi pesan tidak diunggah. Yang dikirim: nominal, jenis, nama app, dan hash.',
            style: Theme.of(context).textTheme.bodyMedium,
          ),
          const SizedBox(height: SsrSpace.md),
          _StatusCard(
            master: master,
            onMasterChanged: _setMaster,
            foregroundRunning: foregroundRunning,
            granted: granted,
            serviceConnected: serviceConnected,
            scanning: scanning,
            onRequestPermission: _requestPermission,
            onReconnect: _reconnect,
          ),
          _BankMappingCard(
            wallets: wallets,
            perApp: perApp,
            walletFor: walletFor,
            catFor: catFor,
            resolveWalletName: _autoMatchLabel,
            onToggle: _setApp,
            onWallet: _setWallet,
            onCategory: _setCat,
          ),
          _RecentCard(
            scanning: scanning,
            scanStatus: scanStatus,
            onScan: _scan,
            onSaved: _onNotifSaved,
          ),
        ],
      ),
    );
  }
}

/// Tone chip untuk status recent notif: sukses → accent, ada "gagal" → danger.
StatusTone _statusToneFor(String? status) {
  final s = (status ?? '').toLowerCase();
  if (s.startsWith('tersimpan')) return StatusTone.accent;
  if (s.contains('gagal')) return StatusTone.danger;
  return StatusTone.neutral;
}

/// Kartu "Status pelacakan": master switch + 3 baris status
/// (pemantauan latar, izin listener, koneksi service).
class _StatusCard extends StatelessWidget {
  final bool master;
  final ValueChanged<bool> onMasterChanged;
  final bool foregroundRunning;
  final bool granted;
  final bool serviceConnected;
  final bool scanning;
  final VoidCallback onRequestPermission;
  final VoidCallback onReconnect;

  const _StatusCard({
    required this.master,
    required this.onMasterChanged,
    required this.foregroundRunning,
    required this.granted,
    required this.serviceConnected,
    required this.scanning,
    required this.onRequestPermission,
    required this.onReconnect,
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
                  'Status pelacakan',
                  style: Theme.of(context).textTheme.titleMedium,
                ),
              ),
              StatusChip(
                label: master ? 'Menyala' : 'Mati',
                tone: master ? StatusTone.accent : StatusTone.neutral,
              ),
            ],
          ),
          const SizedBox(height: SsrSpace.xs),
          SwitchListTile(
            contentPadding: EdgeInsets.zero,
            title: const Text('Pelacakan otomatis'),
            subtitle: const Text('Mati = tidak ada yang dicatat'),
            value: master,
            onChanged: onMasterChanged,
          ),
          const Divider(height: 1),
          _StatusLines(
            foregroundRunning: foregroundRunning,
            granted: granted,
            serviceConnected: serviceConnected,
            scanning: scanning,
            onRequestPermission: onRequestPermission,
            onReconnect: onReconnect,
          ),
        ],
      ),
    );
  }
}

/// Tiga baris detail status: pemantauan latar, izin listener, koneksi service.
class _StatusLines extends StatelessWidget {
  final bool foregroundRunning;
  final bool granted;
  final bool serviceConnected;
  final bool scanning;
  final VoidCallback onRequestPermission;
  final VoidCallback onReconnect;

  const _StatusLines({
    required this.foregroundRunning,
    required this.granted,
    required this.serviceConnected,
    required this.scanning,
    required this.onRequestPermission,
    required this.onReconnect,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _StatusLine(
          label: 'Pemantauan latar',
          below: StatusChip(
            label: foregroundRunning ? 'Aktif' : 'Mati',
            tone: foregroundRunning ? StatusTone.accent : StatusTone.neutral,
          ),
          trailing: Flexible(
            child: Text(
              foregroundRunning
                  ? 'Transaksi tetap tercatat walau app ditutup'
                  : 'Buka app agar pelacakan berjalan',
              style: Theme.of(context).textTheme.bodySmall,
            ),
          ),
        ),
        const Divider(height: 1),
        _StatusLine(
          label: 'Izin baca notifikasi',
          below: StatusChip(
            label: granted ? 'Aktif' : 'Belum aktif',
            tone: granted ? StatusTone.accent : StatusTone.neutral,
          ),
          trailing: OutlinedButton(
            onPressed: onRequestPermission,
            child: Text(granted ? 'Cek lagi' : 'Aktifkan'),
          ),
        ),
        const Divider(height: 1),
        _ServiceLine(
          granted: granted,
          serviceConnected: serviceConnected,
          scanning: scanning,
          onReconnect: onReconnect,
        ),
      ],
    );
  }
}

/// Baris status koneksi service listener (sambung / chip koneksi / belum siap).
class _ServiceLine extends StatelessWidget {
  final bool granted;
  final bool serviceConnected;
  final bool scanning;
  final VoidCallback onReconnect;

  const _ServiceLine({
    required this.granted,
    required this.serviceConnected,
    required this.scanning,
    required this.onReconnect,
  });

  @override
  Widget build(BuildContext context) {
    return _StatusLine(
      label: 'Service listener',
      below: Text(
        connectionLabel(
          permissionGranted: granted,
          serviceConnected: serviceConnected,
        ),
        style: Theme.of(context).textTheme.bodySmall,
      ),
      trailing: granted && !serviceConnected
          ? OutlinedButton(
              onPressed: scanning ? null : onReconnect,
              child: const Text('Sambung'),
            )
          : granted
          ? StatusChip(
              label: serviceConnected ? 'Terhubung' : 'Terputus',
              tone: serviceConnected ? StatusTone.accent : StatusTone.danger,
            )
          : const StatusChip(label: 'Belum siap', tone: StatusTone.neutral),
    );
  }
}

/// Satu baris status berlabel: judul (labelLarge) + isi di bawahnya +
/// elemen trailing (chip / tombol) — dipakai 3× di kartu status.
class _StatusLine extends StatelessWidget {
  final String label;
  final Widget below;
  final Widget trailing;

  const _StatusLine({
    required this.label,
    required this.below,
    required this.trailing,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: SsrSpace.sm),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(label, style: Theme.of(context).textTheme.labelLarge),
                const SizedBox(height: 2),
                below,
              ],
            ),
          ),
          trailing,
        ],
      ),
    );
  }
}

/// Kartu "Bank & dompet": hint bila belum ada dompet + satu BankTrackRow
/// per app di allowlist (switch + mapping dompet/kategori).
class _BankMappingCard extends StatelessWidget {
  final List<Wallet> wallets;
  final Map<String, bool> perApp;
  final Map<String, String?> walletFor;
  final Map<String, String> catFor;
  final String? Function(String label) resolveWalletName;
  final Future<void> Function(String label, bool value) onToggle;
  final Future<void> Function(String label, String? id) onWallet;
  final Future<void> Function(String label, String value) onCategory;

  const _BankMappingCard({
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
    return SectionCard(
      margin: const EdgeInsets.only(bottom: SsrSpace.md),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('Bank & dompet', style: Theme.of(context).textTheme.titleMedium),
          const SizedBox(height: SsrSpace.xs),
          if (wallets.isEmpty)
            Text(
              'Belum ada dompet. Buat dulu di menu Lainnya, lalu Dompet, lalu petakan di sini.',
              style: Theme.of(context).textTheme.bodySmall,
            ),
          for (final app in watchedApps) ...[
            const Divider(height: 1),
            BankTrackRow(
              label: app.label,
              subtitle: [
                'Dompet: ${resolveWalletName(app.label) ?? 'belum cocok'}',
                if ((catFor[app.label] ?? '').isNotEmpty)
                  'Kategori: ${catFor[app.label]}',
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
        ],
      ),
    );
  }
}

/// Kartu "Terakhir terlihat": tombol pindai, status pindai, dan daftar
/// recent notif sesi ini (RAM saja, dari NotifTrack.recent).
class _RecentCard extends StatelessWidget {
  final bool scanning;
  final String scanStatus;
  final Future<void> Function() onScan;
  final ValueChanged<String> onSaved;

  const _RecentCard({
    required this.scanning,
    required this.scanStatus,
    required this.onScan,
    required this.onSaved,
  });

  @override
  Widget build(BuildContext context) {
    return SectionCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Terakhir terlihat',
            style: Theme.of(context).textTheme.titleMedium,
          ),
          const SizedBox(height: SsrSpace.xs),
          Text(
            'Pindai notifikasi yang masih ada di panel HP.',
            style: Theme.of(context).textTheme.bodySmall,
          ),
          const SizedBox(height: SsrSpace.sm),
          Align(
            alignment: Alignment.centerLeft,
            child: TextButton.icon(
              onPressed: scanning ? null : onScan,
              icon: scanning
                  ? const SizedBox(
                      width: 16,
                      height: 16,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : DuoIcon(AppIcons.scan),
              label: Text(
                scanning ? 'Memindai...' : 'Pindai notifikasi aktif sekarang',
              ),
            ),
          ),
          if (scanStatus.isNotEmpty)
            Text(scanStatus, style: Theme.of(context).textTheme.bodySmall),
          _RecentList(onSaved: onSaved),
        ],
      ),
    );
  }
}

/// Daftar recent notif sesi ini (atau pesan kosong bila belum ada).
class _RecentList extends StatelessWidget {
  final ValueChanged<String> onSaved;

  const _RecentList({required this.onSaved});

  @override
  Widget build(BuildContext context) {
    final shown = NotifTrack.recent;
    if (shown.isEmpty) {
      return Padding(
        padding: const EdgeInsets.only(top: SsrSpace.sm),
        child: Text(
          'Belum ada notifikasi keuangan tertangkap sesi ini.',
          style: Theme.of(context).textTheme.bodyMedium,
        ),
      );
    }
    return Column(
      children: [
        for (var i = 0; i < shown.length; i++) ...[
          if (i > 0) const Divider(height: 1),
          RecentNotifTile(n: shown[i], onSaved: onSaved),
        ],
      ],
    );
  }
}

/// Satu baris recent notif: judul/app/waktu, isi pesan, chip status +
/// nominal + jenis, dan tombol Simpan (bila belum tercatat & nominal valid).
class RecentNotifTile extends StatelessWidget {
  final CapturedNotif n;
  final ValueChanged<String> onSaved;

  const RecentNotifTile({super.key, required this.n, required this.onSaved});

  Future<void> _forceSave({String? forceType}) async {
    final msg = await NotifTrack.forceSave(n, forceType: forceType);
    onSaved(msg);
  }

  Future<void> _pickTypeAndSave(BuildContext ctx) async {
    final type = await showModalSheetOfType(ctx, n);
    if (type == null || !ctx.mounted) return;
    await _forceSave(forceType: type);
  }

  Widget? _saveButton(BuildContext ctx) {
    final saved =
        n.status == 'Tersimpan' || (n.status?.startsWith('Tersimpan') ?? false);
    if (saved) return null;
    if (n.amount == null || n.amount! <= 0) return null;
    if (n.type != null) {
      return TextButton(
        onPressed: () async => _forceSave(),
        child: const Text('Simpan'),
      );
    }
    return TextButton(
      onPressed: () => _pickTypeAndSave(ctx),
      child: const Text('Simpan...'),
    );
  }

  @override
  Widget build(BuildContext context) {
    final time = DateFormat('HH:mm');
    final saveBtn = _saveButton(context);
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: SsrSpace.sm),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  n.title.isEmpty ? (n.appLabel ?? n.package) : n.title,
                  style: Theme.of(context).textTheme.titleMedium,
                ),
                const SizedBox(height: 2),
                Text(
                  '${n.appLabel ?? n.package} | ${time.format(n.at)}',
                  style: Theme.of(context).textTheme.bodySmall,
                ),
                if (n.content.isNotEmpty)
                  Text(n.content, style: Theme.of(context).textTheme.bodySmall),
                const SizedBox(height: SsrSpace.xs),
                _RecentChips(n: n),
              ],
            ),
          ),
          if (saveBtn != null) ...[const SizedBox(width: SsrSpace.sm), saveBtn],
        ],
      ),
    );
  }
}

/// Chip status + nominal + jenis untuk satu notif recent.
class _RecentChips extends StatelessWidget {
  final CapturedNotif n;

  const _RecentChips({required this.n});

  StatusTone get _statusTone => _statusToneFor(n.status);

  @override
  Widget build(BuildContext context) {
    final statusLabel = (n.status == null || n.status!.isEmpty)
        ? 'Melewati filter'
        : n.status!;
    return Wrap(
      spacing: SsrSpace.sm,
      runSpacing: SsrSpace.xs,
      children: [
        StatusChip(label: statusLabel, tone: _statusTone),
        if (n.amount != null)
          StatusChip(label: amt(n.amount!), tone: StatusTone.neutral),
        if (n.type != null)
          StatusChip(
            label: n.type == 'in' ? 'Masuk' : 'Keluar',
            tone: n.type == 'in' ? StatusTone.accent : StatusTone.danger,
          ),
      ],
    );
  }
}

Future<String?> showModalSheetOfType(BuildContext context, CapturedNotif n) {
  return showModalBottomSheet<String>(
    context: context,
    builder: (ctx) => SafeArea(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Padding(
            padding: const EdgeInsets.all(16),
            child: Text(
              'Jenis transaksi untuk ${amt(n.amount ?? 0)}',
              style: Theme.of(ctx).textTheme.titleMedium,
            ),
          ),
          ListTile(
            leading: DuoIcon(AppIcons.arrowDown),
            title: const Text('Masuk (pemasukan)'),
            onTap: () => Navigator.pop(ctx, 'in'),
          ),
          ListTile(
            leading: DuoIcon(AppIcons.arrowUp),
            title: const Text('Keluar (pengeluaran)'),
            onTap: () => Navigator.pop(ctx, 'out'),
          ),
        ],
      ),
    ),
  );
}
