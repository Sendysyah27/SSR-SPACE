import 'package:flutter/material.dart';
import 'package:ssr_space/utils/org_prefs.dart';
import 'package:ssr_space/utils/money.dart';
import 'package:ssr_space/services/billing_service.dart';
import 'package:ssr_space/theme/app_theme.dart';
import 'package:ssr_space/widgets/primary_button.dart';
import 'package:ssr_space/widgets/section_card.dart';
import 'package:ssr_space/widgets/state_views.dart';
import 'package:ssr_space/widgets/status_chip.dart';

class BillingScreen extends StatefulWidget {
  const BillingScreen({super.key});
  @override
  State<BillingScreen> createState() => _BillingScreenState();
}

class _BillingScreenState extends State<BillingScreen> {
  String plan = '';
  bool loading = true;
  bool upgrading = false;
  String? msg;
  String? err;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() {
      loading = true;
      err = null;
    });
    try {
      final orgId = await activeOrgId();
      if (orgId.isEmpty) {
        setState(() => loading = false);
        return;
      }
      final p = await currentPlan(orgId);
      if (!mounted) return;
      setState(() {
        plan = p;
        loading = false;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        loading = false;
        err = 'Gagal memuat paket. Periksa koneksi.';
      });
    }
  }

  Future<void> _upgrade() async {
    if (upgrading) return;
    setState(() {
      upgrading = true;
      msg = null;
    });
    try {
      await requestUpgrade(await activeOrgId(), 'pro', proPrice);
      if (!mounted) return;
      setState(() {
        msg = 'Permintaan Pro tercatat. Aktivasi menyusul setelah pembayaran terkonfirmasi.';
      });
    } catch (_) {
      if (!mounted) return;
      setState(() => msg = 'Gagal mengirim permintaan. Coba lagi nanti.');
    } finally {
      if (mounted) setState(() => upgrading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    if (loading) {
      return Scaffold(
        appBar: AppBar(title: const Text('Billing')),
        body: const LoadingView(label: 'Memuat paket...'),
      );
    }
    if (err != null) {
      return Scaffold(
        appBar: AppBar(title: const Text('Billing')),
        body: ErrorView(message: err!, onRetry: _load),
      );
    }
    final isPro = plan == 'pro';
    return Scaffold(
      appBar: AppBar(title: const Text('Billing')),
      body: ListView(
        padding: const EdgeInsets.all(SsrSpace.lg),
        children: [
          Text(
            'Paket aktif: ${plan.isEmpty ? '-' : (isPro ? 'Pro' : 'Gratis')}',
            style: Theme.of(context).textTheme.titleLarge,
          ),
          const SizedBox(height: SsrSpace.lg),
          _PlanCard(
            margin: const EdgeInsets.only(bottom: SsrSpace.md),
            title: 'Gratis',
            statusChip: !isPro
                ? const StatusChip(
                    label: 'Paket aktif',
                    tone: StatusTone.accent,
                  )
                : null,
            price: Text('Rp0', style: SsrTheme.money.copyWith(fontSize: 18)),
            features: const ['Catat transaksi', '1 workspace'],
          ),
          _PlanCard(
            borderColor: SsrColors.accent,
            title: 'Pro',
            statusChip: isPro
                ? const StatusChip(
                    label: 'Paket aktif',
                    tone: StatusTone.accent,
                  )
                : const StatusChip(label: 'Upgrade', tone: StatusTone.neutral),
            price: Text(
              '${rp(proPrice)}/bulan',
              style: SsrTheme.money.copyWith(
                fontSize: 18,
                color: SsrColors.accent,
              ),
            ),
            features: const [
              'Workspace banyak',
              'Export laporan',
              'Tanpa batas',
            ],
            extra: [
              if (msg != null) ...[
                const SizedBox(height: SsrSpace.md),
                StatusChip(
                  label: msg!.startsWith('Permintaan')
                      ? 'Permintaan terkirim'
                      : 'Gagal',
                  tone: msg!.startsWith('Permintaan')
                      ? StatusTone.accent
                      : StatusTone.danger,
                ),
                const SizedBox(height: SsrSpace.sm),
                Text(msg!, style: Theme.of(context).textTheme.bodySmall),
              ],
              const SizedBox(height: SsrSpace.lg),
              PrimaryButton(
                label: 'Naik ke Pro',
                loading: upgrading,
                onPressed: isPro ? null : _upgrade,
              ),
            ],
          ),
        ],
      ),
    );
  }
}

/// Kartu paket billing (Gratis / Pro): judul + chip status, harga,
/// daftar fitur bertanda centang, dan blok opsional (pesan + tombol).
class _PlanCard extends StatelessWidget {
  final EdgeInsetsGeometry margin;
  final Color? borderColor;
  final String title;
  final Widget? statusChip;
  final Widget price;
  final List<String> features;
  final List<Widget> extra;

  const _PlanCard({
    this.margin = EdgeInsets.zero,
    this.borderColor,
    required this.title,
    required this.statusChip,
    required this.price,
    required this.features,
    this.extra = const [],
  });

  Widget _checkItem(BuildContext context, String label) {
    return Padding(
      padding: const EdgeInsets.only(bottom: SsrSpace.sm),
      child: Row(
        children: [
          const Icon(Icons.check, size: 18, color: SsrColors.accent),
          const SizedBox(width: SsrSpace.sm),
          Expanded(
            child: Text(label, style: Theme.of(context).textTheme.bodyMedium),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final chip = statusChip;
    return SectionCard(
      margin: margin,
      borderColor: borderColor,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  title,
                  style: Theme.of(context).textTheme.titleLarge,
                ),
              ),
              if (chip != null) chip,
            ],
          ),
          const SizedBox(height: SsrSpace.xs),
          price,
          const SizedBox(height: SsrSpace.md),
          for (final f in features) _checkItem(context, f),
          ...extra,
        ],
      ),
    );
  }
}
