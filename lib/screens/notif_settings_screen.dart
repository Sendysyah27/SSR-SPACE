import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:ssr_space/core/saas/notif_parse.dart';
import 'package:ssr_space/core/saas/notif_track_service.dart';
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
  bool loading = true;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final prefs = await SharedPreferences.getInstance();
    final g = await NotifTrack.permissionGranted();
    if (!mounted) return;
    setState(() {
      master = prefs.getBool('track_master') ?? false;
      granted = g;
      perApp = {for (final a in watchedApps) a.label: prefs.getBool('track_${a.label}') ?? true};
      loading = false;
    });
    setState(() {});
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
          'Aplikasi membaca notifikasi bank dan dompet di HP ini saja, lalu mencatatnya otomatis. Tidak dikirim ke mana-mana selain workspace kamu.',
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
        for (final app in watchedApps)
          SwitchListTile(
            contentPadding: EdgeInsets.zero,
            title: Text(app.label),
            value: perApp[app.label] ?? true,
            onChanged: (v) => _setApp(app.label, v),
          ),
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
                  trailing: (n.status != 'Tersimpan' && n.amount != null && n.type != null)
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
