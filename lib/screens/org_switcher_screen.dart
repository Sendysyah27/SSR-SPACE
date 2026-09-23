import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
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
  final nameC = TextEditingController();

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() => loading = true);
    try {
      final uid = SupabaseConfig.client.auth.currentUser!.id;
      final rows = await SupabaseConfig.client
          .from('org_members')
          .select('org_id, role, organizations(id, name, plan)')
          .eq('user_id', uid);
      setState(() => orgs = List<Map<String, dynamic>>.from(rows));
    } catch (_) {
      setState(() => orgs = []);
    } finally {
      setState(() => loading = false);
    }
  }

  Future<void> _create() async {
    if (nameC.text.isEmpty) return;
    final c = SupabaseConfig.client;
    final org = await c.from('organizations').insert({'name': nameC.text}).select().single();
    await c.from('org_members').insert({
      'org_id': org['id'],
      'user_id': c.auth.currentUser!.id,
      'role': 'owner',
    });
    nameC.clear();
    await _load();
  }

  Future<void> _select(Map<String, dynamic> org) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('active_org_id', (org['organizations'] ?? org)['id']);
    await prefs.setString('active_org_name', (org['organizations'] ?? org)['name']);
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
              ElevatedButton(onPressed: _create, child: const Text('Buat')),
            ]),
    );
  }
}
