import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:ssr_space/core/saas/supabase_config.dart';
import 'package:ssr_space/core/session/session_service.dart';
import 'package:ssr_space/screens/billing_screen.dart';
import 'package:ssr_space/screens/org_switcher_screen.dart';
import 'package:ssr_space/screens/splash_screen.dart';
import 'package:ssr_space/screens/wallets_screen.dart';

class OtherScreen extends StatelessWidget {
  final SessionService session;
  const OtherScreen({super.key, required this.session});

  Future<String> _orgName() async {
    final p = await SharedPreferences.getInstance();
    return p.getString('active_org_name') ?? '-';
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Lainnya')),
      body: ListView(padding: const EdgeInsets.all(16), children: [
        FutureBuilder<String>(
          future: _orgName(),
          builder: (_, s) => Text('Workspace: ${s.data ?? '-'}', style: Theme.of(context).textTheme.titleMedium),
        ),
        const SizedBox(height: 8),
        ListTile(
          contentPadding: EdgeInsets.zero,
          leading: const Icon(Icons.account_balance_wallet_outlined),
          title: const Text('Dompet'),
          onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const WalletsScreen())),
        ),
        const Divider(height: 1),
        ListTile(
          contentPadding: EdgeInsets.zero,
          leading: const Icon(Icons.swap_horiz_outlined),
          title: const Text('Ganti workspace'),
          onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => OrgSwitcherScreen(session: session))),
        ),
        const Divider(height: 1),
        ListTile(
          contentPadding: EdgeInsets.zero,
          leading: const Icon(Icons.receipt_outlined),
          title: const Text('Billing'),
          onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const BillingScreen())),
        ),
        const Divider(height: 1),
        ListTile(
          contentPadding: EdgeInsets.zero,
          leading: const Icon(Icons.logout_outlined),
          title: const Text('Keluar'),
          onTap: () async {
            await SupabaseConfig.client.auth.signOut();
            final p = await SharedPreferences.getInstance();
            await p.remove('active_org_id');
            if (!context.mounted) return;
            Navigator.pushAndRemoveUntil(context, MaterialPageRoute(builder: (_) => SplashScreen(session: session)), (_) => false);
          },
        ),
        const Divider(height: 1),
      ]),
    );
  }
}
