import 'package:flutter/material.dart';
import 'package:ssr_space/utils/org_prefs.dart';
import 'package:ssr_space/utils/money.dart';
import 'package:ssr_space/utils/datetime.dart';
import 'package:ssr_space/services/billing_service.dart';
import 'package:ssr_space/services/qris_payment_service.dart';
import 'package:ssr_space/widgets/qris_payment_sheet.dart';
import 'package:ssr_space/services/supabase_config.dart';
import 'package:ssr_space/theme/app_icons.dart';
import 'package:ssr_space/theme/app_theme.dart';
import 'package:ssr_space/theme/dribbble_tokens.dart';
import 'package:ssr_space/widgets/drib_card.dart';
import 'package:ssr_space/widgets/state_views.dart';
import 'package:ssr_space/widgets/status_chip.dart';
import 'package:ssr_space/services/plan_limits.dart';
import 'package:ssr_space/utils/strings.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class BillingScreen extends StatefulWidget {
  const BillingScreen({super.key});
  @override
  State<BillingScreen> createState() => _BillingScreenState();
}

class _BillingScreenState extends State<BillingScreen> {
  String plan = '';
  String? expiresAt;
  bool stale = false;
  bool loading = true;
  String? err;

  // Seksi paket QRIS: state sendiri — gagal memuat seksi ini TIDAK
  // menjatuhkan seluruh layar (state loading/error utama tak disentuh).
  List<Map<String, dynamic>> qrisPlans = [];
  bool qrisLoading = true;
  bool qrisError = false;
  String qrisOrgId = '';

  @override
  void initState() {
    super.initState();
    _load();
    _loadQris();
  }

  /// Muat daftar paket QRIS (plan_pricing) + org aktif untuk transaksi.
  Future<void> _loadQris() async {
    setState(() {
      qrisLoading = true;
      qrisError = false;
    });
    try {
      final orgId = await activeOrgId();
      final plans = await fetchQrisPlans();
      if (!mounted) return;
      setState(() {
        qrisOrgId = orgId;
        qrisPlans = plans;
        qrisLoading = false;
      });
    } catch (e) {
      // Kegagalan seksi saja: pesan jujur tampil di seksi QRIS dan
      // detailnya dicatat agar tetap terlacak.
      debugPrint('muat paket QRIS gagal: $e');
      if (!mounted) return;
      setState(() {
        qrisLoading = false;
        qrisError = true;
      });
    }
  }

  /// Buka sheet pembayaran QRIS untuk satu paket; setelah terbayar
  /// (onPaid) status paket utama dimuat ulang.
  Future<void> _openQrisSheet(Map<String, dynamic> plan) async {
    var orgId = qrisOrgId;
    if (orgId.isEmpty) orgId = await activeOrgId();
    if (!mounted) return;
    if (orgId.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(tr('bl_qris_err'))),
      );
      return;
    }
    await showQrisPaymentSheet(
      context,
      orgId: orgId,
      plan: plan,
      onPaid: () {
        _load();
      },
    );
  }

  Future<void> _load() async {
    setState(() {
      loading = true;
      err = null;
    });
    try {
      final orgId = await activeOrgId();
      if (orgId.isEmpty) {
        if (!mounted) return;
        setState(() => loading = false);
        return;
      }
      final status = await planStatus(orgId);
      if (!mounted) return;
      setState(() {
        plan = (status['plan'] ?? 'free').toString();
        final exp = status['expiresAt'];
        expiresAt = exp?.toString();
        stale = status['stale'] == true;
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

  /// Label paket aktif: "Pro sampai {tgl}" bila ada expiry,
  /// "Pro" bila permanen, tampilan Gratis existing bila free.
  String _planLabel() {
    if (plan != 'pro') return tr('bl_free');
    final exp = expiresAt;
    if (exp == null || exp.isEmpty) return tr('bl_pro');
    final d = exp.length >= 10 ? dayLabel(exp.substring(0, 10)) : exp;
    return tr('bl_pro_until').replaceFirst('{d}', d);
  }

  /// Dialog tukar kode VIP → RPC redeem_vip_code → snackbar jujur → reload.
  Future<void> _redeemVip() async {
    final controller = TextEditingController();
    final code = await showDialog<String>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: Text(tr('bl_vip_title')),
        content: TextField(
          controller: controller,
          autofocus: true,
          textCapitalization: TextCapitalization.characters,
          decoration: InputDecoration(hintText: tr('bl_vip_hint')),
          onSubmitted: (v) => Navigator.pop(dialogContext, v),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext),
            child: Text(tr('cancel')),
          ),
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, controller.text),
            child: Text(tr('bl_vip_redeem')),
          ),
        ],
      ),
    );
    controller.dispose();
    if (code == null) return;
    final trimmed = code.trim();
    if (trimmed.isEmpty) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(tr('bl_vip_hint'))),
      );
      return;
    }
    try {
      await SupabaseConfig.client.rpc(
        'redeem_vip_code',
        params: {'p_code': trimmed},
      );
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(tr('bl_vip_ok'))),
      );
      await _load();
    } on PostgrestException catch (e) {
      if (!mounted) return;
      final msg = e.message;
      String key = 'bl_failed';
      if (msg.contains('VIP_INVALID')) {
        key = 'bl_vip_invalid';
      } else if (msg.contains('VIP_EXHAUSTED')) {
        key = 'bl_vip_exhausted';
      } else {
        // Double-tap/race (23505/unique-violation) atau error tak dikenal
        // lain: baris mungkin sudah tercatat — verifikasi via reload,
        // klaim sukses HANYA bila plan kini pro, jangan klaim buta.
        await _load();
        if (!mounted) return;
        if (plan == 'pro') {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text(tr('bl_vip_ok'))),
          );
          return;
        }
      }
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(tr(key))),
      );
    } catch (_) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(tr('bl_failed'))),
      );
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
    final isPermanentPro = isPro && (expiresAt == null || expiresAt!.isEmpty);
    return _BillingScaffold(
      ListView(
        padding: const EdgeInsets.all(SsrSpace.lg),
        children: [
          Text(
            tr('bl_active').replaceFirst(
                '{p}', plan.isEmpty ? '-' : _planLabel()),
            style: Theme.of(context)
                .textTheme
                .titleLarge
                ?.copyWith(fontWeight: FontWeight.w800),
          ),
          if (stale) ...[
            const SizedBox(height: SsrSpace.xs),
            Text(
              tr('conn_error'),
              style: const TextStyle(
                fontSize: 11,
                fontWeight: FontWeight.w600,
                color: DribTokens.textSecondary,
              ),
            ),
          ],
          const SizedBox(height: SsrSpace.lg),
          _FreePlanCard(isPro: isPro),
          if (isPermanentPro) ...[
            const SizedBox(height: SsrSpace.lg),
            Text(
              tr('bl_pro_permanent_note'),
              style: const TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w600,
                color: DribTokens.textSecondary,
              ),
            ),
          ] else
            _QrisPlansSection(
              loading: qrisLoading,
              error: qrisError,
              plans: qrisPlans,
              onRetry: _loadQris,
              onPay: _openQrisSheet,
            ),
          _VipCodeTile(onTap: _redeemVip),
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
      backgroundColor: DribTokens.bgOf(context),
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        title: Text(
          tr('o_billing'),
          style: Theme.of(context)
              .textTheme
              .titleLarge
              ?.copyWith(fontWeight: FontWeight.w800),
        ),
      ),
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
      price: Text(
        'Rp0',
        style: AppTheme.money.copyWith(
          fontSize: 18,
          fontWeight: FontWeight.w800,
          color: DribTokens.navy,
        ),
      ),
      features: [
        tr('bl_f_free1'),
        tr('bl_f_free2').replaceFirst('{n}', '${PlanLimits.freeWorkspaces}'),
        tr('bl_limit_wallets'),
        tr('bl_limit_budgets'),
        tr('bl_limit_ai'),
        tr('bl_limit_goals'),
        tr('bl_limit_debts'),
        tr('bl_limit_bills'),
      ],
    );
  }
}

/// Tile "Masukkan kode VIP": ketuk → dialog tukar kode.
class _VipCodeTile extends StatelessWidget {
  final VoidCallback onTap;

  const _VipCodeTile({required this.onTap});

  @override
  Widget build(BuildContext context) {
    return DribCard(
      margin: const EdgeInsets.only(top: SsrSpace.md),
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
      child: ListTile(
        contentPadding: EdgeInsets.zero,
        title: Text(
          tr('bl_vip_title'),
          style: const TextStyle(
            fontSize: 13,
            fontWeight: FontWeight.w800,
            color: DribTokens.navy,
          ),
        ),
        subtitle: Text(
          tr('bl_vip_hint'),
          style: const TextStyle(
            fontSize: 11,
            fontWeight: FontWeight.w600,
            color: DribTokens.textSecondary,
          ),
        ),
        trailing: StatusChip(
          label: tr('bl_vip_redeem'),
          tone: StatusTone.accent,
        ),
        onTap: onTap,
      ),
    );
  }
}

/// Kartu paket billing (Gratis / Pro): judul + chip status, harga,
/// daftar fitur bertanda centang, dan blok opsional (pesan + tombol).
class _PlanCard extends StatelessWidget {
  final EdgeInsetsGeometry margin;
  final String title;
  final Widget? statusChip;
  final Widget price;
  final List<String> features;
  final List<Widget> extra;
  final bool highlight;

  const _PlanCard({
    this.margin = EdgeInsets.zero,
    required this.title,
    required this.statusChip,
    required this.price,
    required this.features,
    this.extra = const [],
    this.highlight = false,
  });

  Widget _checkItem(BuildContext context, String label) {
    return Padding(
      padding: const EdgeInsets.only(bottom: SsrSpace.sm),
      child: Row(
        children: [
          const Container(
            width: 20,
            height: 20,
            decoration: BoxDecoration(
              color: DribTokens.success,
              borderRadius: BorderRadius.all(Radius.circular(7)),
            ),
            child: DuoIcon(
              AppIcons.check,
              size: 12,
              color: Colors.white,
            ),
          ),
          const SizedBox(width: SsrSpace.sm),
          Expanded(
            child: Text(
              label,
              style: const TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w600,
                color: DribTokens.navy,
              ),
            ),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final chip = statusChip;
    return Container(
      margin: margin,
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      decoration: BoxDecoration(
        color: DribTokens.cardOf(context),
        borderRadius: BorderRadius.circular(DribTokens.cardRadius),
        boxShadow: DribTokens.cardShadow,
        border: highlight
            ? Border.all(color: DribTokens.primary, width: 2)
            : null,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  title,
                  style: const TextStyle(
                    fontSize: 15.5,
                    fontWeight: FontWeight.w800,
                    color: DribTokens.navy,
                  ),
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

/// Seksi "Bayar Pro via QRIS": daftar paket dari `plan_pricing`
/// (server) dengan tombol bayar per paket. Punya state muat sendiri:
/// loading kecil / pesan error + coba lagi, tanpa menjatuhkan layar.
class _QrisPlansSection extends StatelessWidget {
  final bool loading;
  final bool error;
  final List<Map<String, dynamic>> plans;
  final VoidCallback onRetry;
  final void Function(Map<String, dynamic> plan) onPay;

  const _QrisPlansSection({
    required this.loading,
    required this.error,
    required this.plans,
    required this.onRetry,
    required this.onPay,
  });

  Widget _benefitItem(BuildContext context, String label) {
    return Padding(
      padding: const EdgeInsets.only(bottom: SsrSpace.sm),
      child: Row(
        children: [
          const Container(
            width: 20,
            height: 20,
            decoration: BoxDecoration(
              color: DribTokens.success,
              borderRadius: BorderRadius.all(Radius.circular(7)),
            ),
            child: DuoIcon(
              AppIcons.check,
              size: 12,
              color: Colors.white,
            ),
          ),
          const SizedBox(width: SsrSpace.sm),
          Expanded(
            child: Text(
              label,
              style: const TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w600,
                color: DribTokens.navy,
              ),
            ),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const SizedBox(height: SsrSpace.lg),
        Text(
          tr('bl_qris_title'),
          style: const TextStyle(
            fontSize: 15.5,
            fontWeight: FontWeight.w800,
            color: DribTokens.navy,
          ),
        ),
        const SizedBox(height: SsrSpace.xs),
        Text(
          tr('bl_qris_sub'),
          style: const TextStyle(
            fontSize: 11,
            fontWeight: FontWeight.w600,
            color: DribTokens.textSecondary,
          ),
        ),
        const SizedBox(height: SsrSpace.md),
        Text(
          tr('bl_benefit_title'),
          style: const TextStyle(
            fontSize: 13,
            fontWeight: FontWeight.w800,
            color: DribTokens.navy,
          ),
        ),
        const SizedBox(height: SsrSpace.sm),
        for (final k in const [
          'bl_ben1',
          'bl_ben2',
          'bl_ben3',
          'bl_ben4',
          'bl_ben5',
          'bl_ben6',
          'bl_ben7',
          'bl_ben8',
          'bl_ben9',
        ])
          _benefitItem(context, tr(k)),
        const SizedBox(height: SsrSpace.sm),
        if (loading)
          const Center(
            child: Padding(
              padding: EdgeInsets.all(SsrSpace.md),
              child: CircularProgressIndicator(),
            ),
          )
        else if (error)
          DribCard(
            padding:
                const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
            child: Row(
              children: [
                Expanded(child: Text(tr('bl_qris_load_err'))),
                TextButton(
                  onPressed: onRetry,
                  child: Text(tr('retry')),
                ),
              ],
            ),
          )
        else
          for (final p in plans)
            _QrisPlanCard(plan: p, onPay: () => onPay(p)),
      ],
    );
  }
}

/// Kartu satu paket QRIS: nama, harga, durasi (+ benefit dari server
/// bila ada), dan tombol "Bayar QRIS" yang membuka sheet pembayaran.
class _QrisPlanCard extends StatelessWidget {
  final Map<String, dynamic> plan;
  final VoidCallback onPay;

  const _QrisPlanCard({required this.plan, required this.onPay});

  @override
  Widget build(BuildContext context) {
    final name = (plan['name'] ?? '').toString();
    final price = (plan['price_idr'] as num?)?.toInt() ?? 0;
    final durationDays = (plan['duration_days'] as num?)?.toInt();
    final durationLabel = durationDays == null
        ? tr('bl_qris_perm')
        : tr('bl_qris_days').replaceFirst('{n}', '$durationDays');
    final benefitsRaw = plan['benefits'];
    final benefits = <String>[
      durationLabel,
      if (benefitsRaw is List)
        for (final b in benefitsRaw) b.toString(),
    ];
    return _PlanCard(
      margin: const EdgeInsets.only(bottom: SsrSpace.md),
      title: name,
      highlight: durationDays == null,
      statusChip: durationDays == null
          ? StatusChip(label: tr('bl_qris_perm'), tone: StatusTone.accent)
          : null,
      price: Text(
        rp(price),
        style: AppTheme.money.copyWith(
          fontSize: 18,
          fontWeight: FontWeight.w800,
          color: DribTokens.navy,
        ),
      ),
      features: benefits,
      extra: [
        const SizedBox(height: SsrSpace.sm),
        _QrisPayButton(label: tr('bl_qris_pay'), onTap: onPay),
      ],
    );
  }
}


/// Tombol bayar gradient navy plek frame (.btn.navyb) untuk kartu paket QRIS.
class _QrisPayButton extends StatelessWidget {
  final String label;
  final VoidCallback onTap;

  const _QrisPayButton({required this.label, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(16),
        child: Container(
          width: double.infinity,
          padding: const EdgeInsets.symmetric(vertical: 12),
          decoration: const BoxDecoration(
            gradient: DribTokens.balanceGradient,
            borderRadius: BorderRadius.all(Radius.circular(16)),
          ),
          child: Text(
            label,
            textAlign: TextAlign.center,
            style: const TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w800,
              color: Colors.white,
            ),
          ),
        ),
      ),
    );
  }
}
