import 'dart:async';

import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:ssr_space/core/format/mask.dart';
import 'package:ssr_space/core/saas/foreground_track.dart';
import 'package:ssr_space/core/saas/notif_parse.dart';
import 'package:ssr_space/core/saas/notif_track_service.dart';
import 'package:ssr_space/core/saas/wallet_service.dart';
import 'package:ssr_space/core/theme/app_theme.dart';
import 'package:ssr_space/models/wallet.dart';
import 'package:ssr_space/widgets/section_card.dart';
import 'package:ssr_space/widgets/state_views.dart';
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

  StatusTone _statusTone(String? status) {
    final s = (status ?? '').toLowerCase();
    if (s.startsWith('tersimpan')) return StatusTone.accent;
    if (s.contains('gagal')) return StatusTone.danger;
    return StatusTone.neutral;
  }

  @override
  Widget build(BuildContext context) {
    if (loading) {
      return Scaffold(
        appBar: AppBar(title: const Text('Pelacakan otomatis')),
        body: const LoadingView(label: 'Memuat pengaturan...'),
      );
    }
    final time = DateFormat('HH:mm');
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
          SectionCard(
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
                  onChanged: _setMaster,
                ),
                const Divider(height: 1),
                Padding(
                  padding: const EdgeInsets.symmetric(vertical: SsrSpace.sm),
                  child: Row(
                    children: [
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Pemantauan latar',
                              style: Theme.of(context).textTheme.labelLarge,
                            ),
                            const SizedBox(height: 2),
                            StatusChip(
                              label: foregroundRunning ? 'Aktif' : 'Mati',
                              tone: foregroundRunning
                                  ? StatusTone.accent
                                  : StatusTone.neutral,
                            ),
                          ],
                        ),
                      ),
                      Flexible(
                        child: Text(
                          foregroundRunning
                              ? 'Transaksi tetap tercatat walau app ditutup'
                              : 'Buka app agar pelacakan berjalan',
                          style: Theme.of(context).textTheme.bodySmall,
                        ),
                      ),
                    ],
                  ),
                ),
                const Divider(height: 1),
                Padding(
                  padding: const EdgeInsets.symmetric(vertical: SsrSpace.sm),
                  child: Row(
                    children: [
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Izin baca notifikasi',
                              style: Theme.of(context).textTheme.labelLarge,
                            ),
                            const SizedBox(height: 2),
                            StatusChip(
                              label: granted ? 'Aktif' : 'Belum aktif',
                              tone: granted
                                  ? StatusTone.accent
                                  : StatusTone.neutral,
                            ),
                          ],
                        ),
                      ),
                      OutlinedButton(
                        onPressed: () async {
                          await NotifTrack.requestPermission();
                          await _load();
                        },
                        child: Text(granted ? 'Cek lagi' : 'Aktifkan'),
                      ),
                    ],
                  ),
                ),
                const Divider(height: 1),
                Padding(
                  padding: const EdgeInsets.symmetric(vertical: SsrSpace.sm),
                  child: Row(
                    children: [
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Service listener',
                              style: Theme.of(context).textTheme.labelLarge,
                            ),
                            const SizedBox(height: 2),
                            Text(
                              connectionLabel(
                                permissionGranted: granted,
                                serviceConnected: serviceConnected,
                              ),
                              style: Theme.of(context).textTheme.bodySmall,
                            ),
                          ],
                        ),
                      ),
                      if (granted && !serviceConnected)
                        OutlinedButton(
                          onPressed: scanning
                              ? null
                              : () async {
                                  await NotifTrack.reconnectService();
                                  await Future.delayed(
                                    const Duration(milliseconds: 900),
                                  );
                                  if (!mounted) return;
                                  await _load();
                                },
                          child: const Text('Sambung'),
                        )
                      else if (granted)
                        StatusChip(
                          label: serviceConnected ? 'Terhubung' : 'Terputus',
                          tone: serviceConnected
                              ? StatusTone.accent
                              : StatusTone.danger,
                        )
                      else
                        const StatusChip(
                          label: 'Belum siap',
                          tone: StatusTone.neutral,
                        ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          SectionCard(
            margin: const EdgeInsets.only(bottom: SsrSpace.md),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Bank & dompet',
                  style: Theme.of(context).textTheme.titleMedium,
                ),
                const SizedBox(height: SsrSpace.xs),
                if (wallets.isEmpty)
                  Text(
                    'Belum ada dompet. Buat dulu di menu Lainnya, lalu Dompet, lalu petakan di sini.',
                    style: Theme.of(context).textTheme.bodySmall,
                  ),
                for (final app in watchedApps) ...[
                  const Divider(height: 1),
                  SwitchListTile(
                    contentPadding: EdgeInsets.zero,
                    title: Text(app.label),
                    subtitle: Text(
                      [
                        'Dompet: ${_autoMatchLabel(app.label) ?? 'belum cocok'}',
                        if ((catFor[app.label] ?? '').isNotEmpty)
                          'Kategori: ${catFor[app.label]}',
                      ].join(' | '),
                    ),
                    value: perApp[app.label] ?? true,
                    onChanged: (v) => _setApp(app.label, v),
                  ),
                  if (wallets.isNotEmpty)
                    Padding(
                      padding: const EdgeInsets.only(
                        left: 4,
                        bottom: SsrSpace.md,
                      ),
                      child: Row(
                        children: [
                          Expanded(
                            child: DropdownButtonFormField<String?>(
                              initialValue: walletFor[app.label],
                              isExpanded: true,
                              decoration: const InputDecoration(
                                labelText: 'Masuk ke dompet',
                                isDense: true,
                              ),
                              items: [
                                const DropdownMenuItem<String?>(
                                  value: null,
                                  child: Text('Otomatis / ikut nama'),
                                ),
                                for (final w in wallets)
                                  DropdownMenuItem<String?>(
                                    value: w.id,
                                    child: Text(w.name),
                                  ),
                              ],
                              onChanged: (v) => _setWallet(app.label, v),
                            ),
                          ),
                          const SizedBox(width: SsrSpace.sm),
                          Expanded(
                            child: TextFormField(
                              initialValue: catFor[app.label] ?? '',
                              decoration: const InputDecoration(
                                labelText: 'Kategori',
                                isDense: true,
                              ),
                              onChanged: (v) => _setCat(app.label, v),
                            ),
                          ),
                        ],
                      ),
                    ),
                ],
              ],
            ),
          ),
          SectionCard(
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
                    onPressed: scanning ? null : _scan,
                    icon: scanning
                        ? const SizedBox(
                            width: 16,
                            height: 16,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          )
                        : const Icon(Icons.refresh),
                    label: Text(
                      scanning
                          ? 'Memindai...'
                          : 'Pindai notifikasi aktif sekarang',
                    ),
                  ),
                ),
                if (scanStatus.isNotEmpty)
                  Text(
                    scanStatus,
                    style: Theme.of(context).textTheme.bodySmall,
                  ),
                Builder(
                  builder: (_) {
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
                          _recentTile(shown[i], time),
                        ],
                      ],
                    );
                  },
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _recentTile(CapturedNotif n, DateFormat time) {
    final statusLabel = (n.status == null || n.status!.isEmpty)
        ? 'Melewati filter'
        : n.status!;
    final saveBtn = _saveButton(n);
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
                Wrap(
                  spacing: SsrSpace.sm,
                  runSpacing: SsrSpace.xs,
                  children: [
                    StatusChip(label: statusLabel, tone: _statusTone(n.status)),
                    if (n.amount != null)
                      StatusChip(
                        label: amt(n.amount!),
                        tone: StatusTone.neutral,
                      ),
                    if (n.type != null)
                      StatusChip(
                        label: n.type == 'in' ? 'Masuk' : 'Keluar',
                        tone: n.type == 'in'
                            ? StatusTone.accent
                            : StatusTone.danger,
                      ),
                  ],
                ),
              ],
            ),
          ),
          if (saveBtn != null) ...[const SizedBox(width: SsrSpace.sm), saveBtn],
        ],
      ),
    );
  }

  Widget? _saveButton(CapturedNotif n) {
    final saved =
        n.status == 'Tersimpan' || (n.status?.startsWith('Tersimpan') ?? false);
    if (saved) return null;
    if (n.amount == null || n.amount! <= 0) return null;
    if (n.type != null) {
      return TextButton(
        onPressed: () async {
          final msg = await NotifTrack.forceSave(n);
          if (!mounted) return;
          setState(() {});
          ScaffoldMessenger.of(context)
              .showSnackBar(SnackBar(content: Text(msg)));
        },
        child: const Text('Simpan'),
      );
    }
    return TextButton(
      onPressed: () => _pickTypeAndSave(n),
      child: const Text('Simpan...'),
    );
  }

  Future<void> _pickTypeAndSave(CapturedNotif n) async {
    final type = await showModalSheetOfType(context, n);
    if (type == null || !mounted) return;
    final msg = await NotifTrack.forceSave(n, forceType: type);
    if (!mounted) return;
    setState(() {});
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(msg)));
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
            leading: const Icon(Icons.arrow_downward),
            title: const Text('Masuk (pemasukan)'),
            onTap: () => Navigator.pop(ctx, 'in'),
          ),
          ListTile(
            leading: const Icon(Icons.arrow_upward),
            title: const Text('Keluar (pengeluaran)'),
            onTap: () => Navigator.pop(ctx, 'out'),
          ),
        ],
      ),
    ),
  );
}
