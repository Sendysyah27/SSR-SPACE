import 'package:flutter/material.dart';
import 'package:ssr_space/utils/org_prefs.dart';
import 'package:ssr_space/utils/money.dart';
import 'package:ssr_space/services/billing_service.dart';
import 'package:ssr_space/theme/app_icons.dart';
import 'package:ssr_space/theme/app_theme.dart';
import 'package:ssr_space/widgets/section_card.dart';
import 'package:ssr_space/widgets/state_views.dart';
import 'package:ssr_space/widgets/status_chip.dart';
import 'package:ssr_space/services/plan_limits.dart';
import 'package:ssr_space/utils/strings.dart';

class BillingScreen extends StatefulWidget {
  const BillingScreen({super.key});
  @override
  State<BillingScreen> createState() => _BillingScreenState();
}

class _BillingScreenState extends State<BillingScreen> {
  String plan = '';
  bool loading = true;
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
        err = tr('bl_err_load');
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    if (loading) {
      return _BillingScaffold(LoadingView(label: tr('bl_loading')));
    }
    if (err != null) {
      return _BillingScaffold(ErrorView(message: err!, onRetry: _load));
    }
    final isPro = plan == 'pro';
    return _BillingScaffold(
      ListView(
        padding: const EdgeInsets.all(SsrSpace.lg),
        children: [
          Text(
            tr('bl_active').replaceFirst('{p}', plan.isEmpty ? '-' : (isPro ? tr('bl_pro') : tr('bl_free'))),
            style: Theme.of(context).textTheme.titleLarge,
          ),
          const SizedBox(height: SsrSpace.lg),
          _FreePlanCard(isPro: isPro),
          _ProPlanCard(isPro: isPro),
        ],
      ),
    );
  }
}

/// Kerangka layar Billing: AppBar "Billing" + body (state / daftar paket).
class _BillingScaffold extends StatelessWidget {
  final Widget body;
  const _BillingScaffold(this.body);

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text(tr('o_billing'))),
      body: body,
    );
  }
}

/// Kartu paket Gratis: chip "Paket aktif" bila bukan Pro.
class _FreePlanCard extends StatelessWidget {
  final bool isPro;

  const _FreePlanCard({required this.isPro});

  @override
  Widget build(BuildContext context) {
    return _PlanCard(
      margin: const EdgeInsets.only(bottom: SsrSpace.md),
      title: tr('bl_free'),
      statusChip: !isPro
          ? StatusChip(label: tr('bl_active_chip'), tone: StatusTone.accent)
          : null,
      price: Text('Rp0', style: AppTheme.money.copyWith(fontSize: 18)),
      features: [
        tr('bl_f_free1'),
        tr('bl_f_free2').replaceFirst('{n}', '${PlanLimits.freeWorkspaces}'),
      ],
    );
  }
}

/// Kartu paket Pro: harga, fitur, chip status. Tanpa tombol bayar —
/// pembayaran dalam persiapan ("segera hadir", Batch 3 Sprint): tak ada
/// lagi baris `pending` palsu yang tak pernah diproses.
class _ProPlanCard extends StatelessWidget {
  final bool isPro;

  const _ProPlanCard({required this.isPro});

  @override
  Widget build(BuildContext context) {
    return _PlanCard(
      borderColor: Theme.of(context).colorScheme.primary,
      title: tr('bl_pro'),
      statusChip: isPro
          ? StatusChip(label: tr('bl_active_chip'), tone: StatusTone.accent)
          : StatusChip(label: tr('bl_soon'), tone: StatusTone.neutral),
      price: Text(
        '${rp(proPrice)}/bulan',
        style: AppTheme.money.copyWith(
          fontSize: 18,
          color: Theme.of(context).colorScheme.primary,
        ),
      ),
      features: [tr('bl_f_pro1'), tr('bl_f_pro2'), tr('bl_f_pro3')],
      extra: [
        if (!isPro) ...[
          const SizedBox(height: SsrSpace.sm),
          Text(tr('bl_soon_s'), style: Theme.of(context).textTheme.bodySmall),
        ],
      ],
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
          DuoIcon(
            AppIcons.check,
            size: 18,
            color: Theme.of(context).colorScheme.primary,
          ),
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
