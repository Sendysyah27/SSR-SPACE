import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:ssr_space/core/saas/billing_service.dart';
import 'package:ssr_space/core/saas/supabase_config.dart';
import 'package:ssr_space/core/session/session_service.dart';
import 'package:ssr_space/core/theme/app_theme.dart';
import 'package:ssr_space/screens/billing_screen.dart';
import 'package:ssr_space/screens/notif_settings_screen.dart';
import 'package:ssr_space/screens/org_switcher_screen.dart';
import 'package:ssr_space/screens/splash_screen.dart';
import 'package:ssr_space/screens/wallets_screen.dart';
import 'package:ssr_space/widgets/section_card.dart';
import 'package:ssr_space/widgets/status_chip.dart';

class _OtherMeta {
  final String orgName;
  final String plan;
  final bool tracking;
  const _OtherMeta({
    required this.orgName,
    required this.plan,
    required this.tracking,
  });
}

class OtherScreen extends StatefulWidget {
  final SessionService session;
  const OtherScreen({super.key, required this.session});

  @override
  State<OtherScreen> createState() => _OtherScreenState();
}

class _OtherScreenState extends State<OtherScreen> {
  late Future<_OtherMeta> _metaFuture;

  @override
  void initState() {
    super.initState();
    _metaFuture = _meta();
  }

  Future<_OtherMeta> _meta() async {
    final p = await SharedPreferences.getInstance();
    final orgName = p.getString('active_org_name') ?? '-';
    final tracking = p.getBool('track_master') ?? false;
    final orgId = p.getString('active_org_id') ?? '';
    var plan = '';
    if (orgId.isNotEmpty) {
      try {
        plan = await currentPlan(orgId);
      } catch (_) {
        plan = '';
      }
    }
    return _OtherMeta(orgName: orgName, plan: plan, tracking: tracking);
  }

  void _refreshMeta() {
    setState(() => _metaFuture = _meta());
  }

  Future<void> _confirmLogout() async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Keluar dari akun?'),
        content: const Text(
          'Sesi berakhir. Workspace aktif di HP ini ikut dilepas.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Batal'),
          ),
          TextButton(
            style: TextButton.styleFrom(foregroundColor: SsrColors.danger),
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Keluar'),
          ),
        ],
      ),
    );
    if (ok != true || !mounted) return;
    await SupabaseConfig.client.auth.signOut();
    final p = await SharedPreferences.getInstance();
    await p.remove('active_org_id');
    if (!mounted) return;
    Navigator.pushAndRemoveUntil(
      context,
      MaterialPageRoute(builder: (_) => SplashScreen(session: widget.session)),
      (_) => false,
    );
  }

  Future<void> _push(Widget screen) async {
    await Navigator.push(context, MaterialPageRoute(builder: (_) => screen));
    if (mounted) _refreshMeta();
  }

  Widget _iconTile(IconData icon) {
    return Container(
      width: 44,
      height: 44,
      decoration: BoxDecoration(
        color: SsrColors.accentSoft,
        borderRadius: BorderRadius.circular(SsrRadius.tile),
      ),
      child: Icon(icon, color: SsrColors.accent, size: 20),
    );
  }

  Widget _navTile({
    required IconData icon,
    required String title,
    String? subtitle,
    StatusChip? chip,
    required VoidCallback onTap,
  }) {
    return ListTile(
      contentPadding: EdgeInsets.zero,
      leading: _iconTile(icon),
      title: Text(title),
      subtitle: subtitle != null ? Text(subtitle) : null,
      trailing: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (chip != null) ...[chip, const SizedBox(width: SsrSpace.sm)],
          const Icon(Icons.chevron_right, color: SsrColors.secondary),
        ],
      ),
      onTap: onTap,
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Lainnya')),
      body: FutureBuilder<_OtherMeta>(
        future: _metaFuture,
        builder: (_, snap) {
          final meta = snap.data;
          final planLabel = meta == null || meta.plan.isEmpty
              ? '-'
              : meta.plan == 'pro'
              ? 'Pro'
              : 'Gratis';
          return ListView(
            padding: const EdgeInsets.all(SsrSpace.lg),
            children: [
              SectionCard(
                margin: const EdgeInsets.only(bottom: SsrSpace.md),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Workspace',
                      style: Theme.of(context).textTheme.bodySmall,
                    ),
                    const SizedBox(height: SsrSpace.xs),
                    Row(
                      children: [
                        Expanded(
                          child: Text(
                            meta?.orgName ?? '-',
                            style: Theme.of(context).textTheme.titleMedium,
                          ),
                        ),
                        StatusChip(
                          label: planLabel,
                          tone: meta?.plan == 'pro'
                              ? StatusTone.accent
                              : StatusTone.neutral,
                        ),
                      ],
                    ),
                    const Divider(height: SsrSpace.xl),
                    _navTile(
                      icon: Icons.swap_horiz_outlined,
                      title: 'Ganti workspace',
                      onTap: () =>
                          _push(OrgSwitcherScreen(session: widget.session)),
                    ),
                    const Divider(height: 1),
                    _navTile(
                      icon: Icons.account_balance_wallet_outlined,
                      title: 'Dompet',
                      onTap: () => _push(const WalletsScreen()),
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
                      'Pelacakan',
                      style: Theme.of(context).textTheme.bodySmall,
                    ),
                    const SizedBox(height: SsrSpace.xs),
                    _navTile(
                      icon: Icons.notifications_active_outlined,
                      title: 'Pelacakan otomatis',
                      subtitle: 'Notifikasi bank jadi transaksi',
                      chip: StatusChip(
                        label: meta?.tracking == true ? 'Menyala' : 'Mati',
                        tone: meta?.tracking == true
                            ? StatusTone.accent
                            : StatusTone.neutral,
                      ),
                      onTap: () => _push(const NotifSettingsScreen()),
                    ),
                  ],
                ),
              ),
              SectionCard(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('Akun', style: Theme.of(context).textTheme.bodySmall),
                    const SizedBox(height: SsrSpace.xs),
                    _navTile(
                      icon: Icons.receipt_outlined,
                      title: 'Billing',
                      subtitle: 'Paket $planLabel',
                      onTap: () => _push(const BillingScreen()),
                    ),
                    const Divider(height: 1),
                    _navTile(
                      icon: Icons.logout_outlined,
                      title: 'Keluar',
                      onTap: _confirmLogout,
                    ),
                  ],
                ),
              ),
            ],
          );
        },
      ),
    );
  }
}
