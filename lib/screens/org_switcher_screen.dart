import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:uuid/uuid.dart';
import 'package:ssr_space/core/saas/supabase_config.dart';
import 'package:ssr_space/core/session/session_service.dart';
import 'package:ssr_space/screens/home_screen.dart';

class OrgSwitcherScreen extends StatefulWidget {
  final SessionService session;
  const OrgSwitcherScreen({super.key, required this.session});
  @override
  State<OrgSwitcherScreen> createState() => _OrgSwitcherScreenState();
}

class _OrgSwitcherScreenState extends State<OrgSwitcherScreen> {
  List<Map<String, dynamic>> orgs = [];
  bool loading = true;
  bool busy = false;
  String? err;
  final nameC = TextEditingController();

  @override
  void initState() {
    super.initState();
    _load();
  }

  void _fail(Object e) {
    setState(() => err = 'Gagal: ${e.toString().split('\n').first}');
  }

  Future<void> _load() async {
    setState(() { loading = true; err = null; });
    try {
      final uid = SupabaseConfig.client.auth.currentUser!.id;
      final rows = await SupabaseConfig.client
          .from('org_members')
          .select('org_id, role, organizations(id, name, plan)')
          .eq('user_id', uid);
      setState(() => orgs = List<Map<String, dynamic>>.from(rows));
    } catch (e) {
      _fail(e);
      setState(() => orgs = []);
    } finally {
      setState(() => loading = false);
    }
  }

  Future<void> _create() async {
    final name = nameC.text.trim();
    if (name.isEmpty || busy) return;
    setState(() { busy = true; err = null; });
    try {
      final c = SupabaseConfig.client;
      final newId = const Uuid().v4();
      await c.from('organizations').insert({'id': newId, 'name': name});
      await c.from('org_members').insert({
        'org_id': newId,
        'user_id': c.auth.currentUser!.id,
        'role': 'owner',
      });
      nameC.clear();
      await _select({'id': newId, 'name': name});
    } catch (e) {
      _fail(e);
    } finally {
      if (mounted) setState(() => busy = false);
    }
  }

  Future<void> _select(Map<String, dynamic> org) async {
    final o = (org['organizations'] ?? org) as Map<String, dynamic>;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('active_org_id', o['id'].toString());
    await prefs.setString('active_org_name', (o['name'] ?? '-').toString());
    if (!mounted) return;
    Navigator.pushReplacement(context,
        MaterialPageRoute(builder: (_) => HomeScreen(session: widget.session)));
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Pilih Workspace')),
      body: loading
          ? const Center(child: CircularProgressIndicator())
          : ListView(padding: const EdgeInsets.all(16), children: [
              for (final m in orgs)
                ListTile(
                  title: Text((m['organizations']?['name'] ?? '-').toString()),
                  subtitle: Text('role: ${m['role']}'),
                  onTap: () => _select(m),
                ),
              const Divider(),
              const Text('Buat workspace baru'),
              TextField(controller: nameC, decoration: const InputDecoration(labelText: 'Nama workspace')),
              if (err != null)
                Padding(
                  padding: const EdgeInsets.only(top: 8),
                  child: Text(err!, style: const TextStyle(color: Colors.red)),
                ),
              const SizedBox(height: 8),
              busy
                  ? const Center(child: CircularProgressIndicator())
                  : ElevatedButton(onPressed: _create, child: const Text('Buat')),
            ]),
    );
  }
}
