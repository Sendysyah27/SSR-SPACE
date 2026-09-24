import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:ssr_space/core/saas/wallet_service.dart';
import 'package:ssr_space/core/session/session_service.dart';
import 'package:ssr_space/models/wallet.dart';
import 'package:ssr_space/widgets/state_views.dart';

class WalletsScreen extends StatefulWidget {
  final SessionService? session;
  const WalletsScreen({super.key, this.session});
  @override
  State<WalletsScreen> createState() => _WalletsScreenState();
}

class _WalletsScreenState extends State<WalletsScreen> {
  List<Wallet> items = [];
  bool noOrg = false;
  bool loading = true;
  String? err;
  final nameC = TextEditingController();
  String type = 'cash';

  @override
  void initState() { super.initState(); _load(); }

  Future<String> _orgId() async => (await SharedPreferences.getInstance()).getString('active_org_id') ?? '';

  Future<void> _load() async {
    setState(() { loading = true; err = null; });
    try {
      final orgId = await _orgId();
      if (orgId.isEmpty) {
        setState(() { noOrg = true; loading = false; });
        return;
      }
      final data = await WalletService().list(orgId);
      if (!mounted) return;
      setState(() { noOrg = false; items = data; loading = false; });
    } catch (e) {
      if (!mounted) return;
      final msg = e.toString();
      final short = msg.contains('recursion')
          ? 'Gagal memuat dompet: RLS recursion. Jalankan migration_08 di Supabase.'
          : msg.contains('permission')
              ? 'Gagal memuat dompet: izin RLS. Cek membership workspace.'
              : 'Gagal memuat dompet. Periksa koneksi.';
      setState(() { loading = false; err = short; });
    }
  }

  @override
  Widget build(BuildContext context) {
    if (noOrg) {
      return Scaffold(
        appBar: AppBar(title: const Text('Dompet')),
        body: const Center(child: Text('Pilih atau buat workspace dulu')),
      );
    }
    if (loading) {
      return Scaffold(appBar: AppBar(title: const Text('Dompet')), body: const LoadingView(label: 'Memuat dompet...'));
    }
    if (err != null) {
      return Scaffold(appBar: AppBar(title: const Text('Dompet')), body: ErrorView(message: err!, onRetry: _load));
    }
    return Scaffold(
      appBar: AppBar(title: const Text('Dompet')),
      body: ListView(padding: const EdgeInsets.all(16), children: [
        if (items.isEmpty)
          Padding(
            padding: const EdgeInsets.only(bottom: 8),
            child: Text('Belum ada dompet. Tambah dompet pertama di bawah.', style: Theme.of(context).textTheme.bodyMedium),
          ),
        for (final w in items) ...[
          ListTile(
            contentPadding: EdgeInsets.zero,
            leading: const Icon(Icons.account_balance_wallet_outlined),
            title: Text(w.name, style: Theme.of(context).textTheme.titleMedium),
            subtitle: Text(w.type),
          ),
          const Divider(height: 1),
        ],
        const SizedBox(height: 16),
        Text('Dompet baru', style: Theme.of(context).textTheme.titleMedium),
        const SizedBox(height: 8),
        TextField(controller: nameC, decoration: const InputDecoration(labelText: 'Nama dompet (Kas, Dana, Bank)')),
        const SizedBox(height: 8),
        DropdownButtonFormField<String>(
          value: type,
          decoration: const InputDecoration(labelText: 'Jenis'),
          items: const [
            DropdownMenuItem(value: 'cash', child: Text('Tunai')),
            DropdownMenuItem(value: 'ewallet', child: Text('E-wallet')),
            DropdownMenuItem(value: 'bank', child: Text('Bank')),
          ],
          onChanged: (v) => setState(() => type = v ?? 'cash'),
        ),
        const SizedBox(height: 12),
        ElevatedButton(
          onPressed: () async {
            if (nameC.text.trim().isEmpty) return;
            final orgId = await _orgId();
            await WalletService().create(orgId, nameC.text.trim(), type);
            nameC.clear();
            await _load();
          },
          child: const Text('Simpan dompet'),
        ),
      ]),
    );
  }
}
