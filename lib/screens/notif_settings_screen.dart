import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:ssr_space/core/saas/notif_parse.dart';
import 'package:ssr_space/core/saas/notif_track_service.dart';
import 'package:ssr_space/core/saas/supabase_config.dart';
import 'package:ssr_space/core/saas/wallet_service.dart';
import 'package:ssr_space/models/wallet.dart';
import 'package:ssr_space/widgets/state_views.dart';

class NotifSettingsScreen extends StatefulWidget {
  const NotifSettingsScreen({super.key});
  @override
  State<NotifSettingsScreen> createState() => _NotifSettingsScreenState();
}

class _NotifSettingsScreenState extends State<NotifSettingsScreen> {
  bool master = false;
  bool granted = false;
  Map<String, bool> perApp = {};
  Map<String, String?> walletFor = {};
  Map<String, String> catFor = {};
  List<Wallet> wallets = [];
  bool loading = true;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final prefs = await SharedPreferences.getInstance();
    final g = await NotifTrack.permissionGranted();
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
      wallets = ws;
      perApp = {for (final a in watchedApps) a.label: prefs.getBool('track_${a.label}') ?? true};
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

  Future<void> _setMaster(bool v) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('track_master', v);
    setState(() => master = v);
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

  @override
  Widget build(BuildContext context) {
    if (loading) {
      return Scaffold(appBar: AppBar(title: const Text('Pelacakan otomatis')), body: const LoadingView(label: 'Memuat pengaturan...'));
    }
    final time = DateFormat('HH:mm');
    return Scaffold(
      appBar: AppBar(title: const Text('Pelacakan otomatis')),
      body: ListView(padding: const EdgeInsets.all(16), children: [
        Text(
          'Aplikasi membaca notifikasi bank dan dompet di HP ini saja, lalu mencatatnya otomatis ke workspace aktif. Isi pesan tidak diunggah; yang dikirim: nominal, jenis, nama app, dan hash.',
          style: Theme.of(context).textTheme.bodyMedium,
        ),
        const SizedBox(height: 12),
        ListTile(
          contentPadding: EdgeInsets.zero,
          title: const Text('Izin baca notifikasi'),
          subtitle: Text(granted ? 'Aktif' : 'Belum aktif'),
          trailing: ElevatedButton(
            onPressed: () async {
              await NotifTrack.requestPermission();
              await _load();
            },
            child: Text(granted ? 'Cek lagi' : 'Aktifkan'),
          ),
        ),
        const Divider(height: 1),
        SwitchListTile(
          contentPadding: EdgeInsets.zero,
          title: const Text('Pelacakan otomatis'),
          subtitle: const Text('Mati = tidak ada yang dicatat'),
          value: master,
          onChanged: _setMaster,
        ),
        const Divider(height: 1),
        Text('App, dompet tujuan, kategori', style: Theme.of(context).textTheme.titleMedium),
        const SizedBox(height: 4),
        if (wallets.isEmpty)
          Text(
            'Belum ada dompet. Buat dulu di Lainnya → Dompet, lalu petakan di sini.',
            style: Theme.of(context).textTheme.bodySmall,
          ),
        for (final app in watchedApps) ...[
          const Divider(height: 1),
          SwitchListTile(
            contentPadding: EdgeInsets.zero,
            title: Text(app.label),
            subtitle: Text([
              'Dompet: ${_autoMatchLabel(app.label) ?? 'belum cocok'}',
              if ((catFor[app.label] ?? '').isNotEmpty) 'Kategori: ${catFor[app.label]}',
            ].join(' · ')),
            value: perApp[app.label] ?? true,
            onChanged: (v) => _setApp(app.label, v),
          ),
          if (wallets.isNotEmpty)
            Padding(
              padding: const EdgeInsets.only(left: 16, bottom: 8),
              child: Row(children: [
                Expanded(
                  child: DropdownButtonFormField<String?>(
                    value: walletFor[app.label],
                    isExpanded: true,
                    decoration: const InputDecoration(labelText: 'Masuk ke dompet', isDense: true),
                    items: [
                      const DropdownMenuItem<String?>(value: null, child: Text('Otomatis / ikut nama')),
                      for (final w in wallets)
                        DropdownMenuItem<String?>(value: w.id, child: Text(w.name)),
                    ],
                    onChanged: (v) => _setWallet(app.label, v),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: TextFormField(
                    initialValue: catFor[app.label] ?? '',
                    decoration: const InputDecoration(labelText: 'Kategori', isDense: true),
                    onChanged: (v) => _setCat(app.label, v),
                  ),
                ),
              ]),
            ),
        ],
        const Divider(height: 1),
        const SizedBox(height: 8),
        Text('Terakhir terlihat', style: Theme.of(context).textTheme.titleMedium),
        TextButton(
          onPressed: () async {
            await NotifTrack.refreshActive();
            setState(() {});
          },
          child: const Text('Pindai notifikasi aktif sekarang'),
        ),
        Builder(builder: (_) {
          final shown = NotifTrack.recent
              .where((n) => n.appLabel != null || n.amount != null)
              .toList();
          if (shown.isEmpty) {
            return Text(
              'Belum ada notifikasi keuangan tertangkap sesi ini.',
              style: Theme.of(context).textTheme.bodyMedium,
            );
          }
          return Column(
            children: [
              for (final n in shown)
                ListTile(
                  contentPadding: EdgeInsets.zero,
                  title: Text(n.title.isEmpty ? (n.appLabel ?? n.package) : n.title),
                  subtitle: Text(
                    '${n.appLabel ?? n.package} | ${time.format(n.at)}\n${n.content}\nStatus: ${n.status ?? 'melewati filter'}',
                  ),
                  isThreeLine: true,
                  trailing: (n.status != 'Tersimpan' &&
                          !(n.status?.startsWith('Tersimpan') ?? false) &&
                          n.amount != null &&
                          n.type != null)
                      ? TextButton(
                          onPressed: () async {
                            await NotifTrack.forceSave(n);
                            setState(() {});
                          },
                          child: const Text('Simpan'),
                        )
                      : null,
                ),
            ],
          );
        }),
      ]),
    );
  }
}
