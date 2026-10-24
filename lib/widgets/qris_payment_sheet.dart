import 'dart:async';

import 'package:flutter/material.dart';
import 'package:qr_flutter/qr_flutter.dart';
import 'package:ssr_space/services/qris_payment_service.dart';
import 'package:ssr_space/theme/app_theme.dart';
import 'package:ssr_space/theme/dribbble_tokens.dart';
import 'package:ssr_space/utils/money.dart';
import 'package:ssr_space/utils/strings.dart';
import 'package:ssr_space/widgets/status_chip.dart';

/// Buka sheet pembayaran QRIS untuk satu paket [plan] (baris
/// `plan_pricing`) pada workspace [orgId]. [onPaid] dipanggil sekali
/// saat status order terverifikasi `paid` agar pemanggil me-reload
/// status paketnya.
Future<void> showQrisPaymentSheet(
  BuildContext context, {
  required String orgId,
  required Map<String, dynamic> plan,
  required VoidCallback onPaid,
}) {
  return showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    backgroundColor: DribTokens.cardOf(context),
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
    ),
    builder: (_) => QrisPaymentSheet(orgId: orgId, plan: plan, onPaid: onPaid),
  );
}

/// Sheet pembayaran QRIS: buat order → tampilkan QR + nominal persis →
/// konfirmasi "Saya sudah bayar" → polling status sampai paid/expired.
///
/// Alur status order (dari server): pending → awaiting_confirmation →
/// paid. Kedaluwarsa ditegakkan countdown lokal dari `expires_at` dan
/// dikonfirmasi polling (status expired/rejected dari server).
class QrisPaymentSheet extends StatefulWidget {
  final String orgId;
  final Map<String, dynamic> plan;
  final VoidCallback onPaid;

  const QrisPaymentSheet({
    super.key,
    required this.orgId,
    required this.plan,
    required this.onPaid,
  });

  @override
  State<QrisPaymentSheet> createState() => _QrisPaymentSheetState();
}

class _QrisPaymentSheetState extends State<QrisPaymentSheet> {
  Map<String, dynamic>? _order;
  String _status = '';
  String? _createError;
  bool _creating = true;
  bool _confirming = false;
  bool _paidNotified = false;
  DateTime? _expiresAt;
  Duration _remaining = Duration.zero;
  Timer? _countdownTimer;
  Timer? _pollTimer;

  String get _planCode => (widget.plan['plan_code'] ?? '').toString();
  String get _planName => (widget.plan['name'] ?? '').toString();

  bool get _isFinal =>
      _status == 'paid' || _status == 'expired' || _status == 'rejected';

  @override
  void initState() {
    super.initState();
    _createOrder();
  }

  @override
  void dispose() {
    _countdownTimer?.cancel();
    _pollTimer?.cancel();
    super.dispose();
  }

  Future<void> _createOrder() async {
    _countdownTimer?.cancel();
    _pollTimer?.cancel();
    setState(() {
      _creating = true;
      _createError = null;
      _order = null;
      _status = '';
      _paidNotified = false;
    });
    final res = await createQrisOrder(widget.orgId, _planCode);
    if (!mounted) return;
    if (!res.ok || res.data == null) {
      setState(() {
        _creating = false;
        _createError = res.error ?? tr('bl_qris_err');
      });
      return;
    }
    final order = res.data!;
    setState(() {
      _creating = false;
      _order = order;
      _status = (order['status'] ?? 'pending').toString();
      _expiresAt = DateTime.tryParse((order['expires_at'] ?? '').toString());
    });
    _tickCountdown();
    _countdownTimer = Timer.periodic(
      const Duration(seconds: 1),
      (_) => _tickCountdown(),
    );
    _pollTimer = Timer.periodic(
      const Duration(seconds: 15),
      (_) => _pollStatus(),
    );
  }

  void _tickCountdown() {
    if (!mounted) return;
    final exp = _expiresAt;
    if (exp == null) return;
    final left = exp.difference(DateTime.now());
    setState(() => _remaining = left.isNegative ? Duration.zero : left);
    if (left.isNegative && !_isFinal) {
      // Countdown habis: tandai kedaluwarsa lokal; polling berikutnya
      // mengonfirmasi status dari server.
      setState(() => _status = 'expired');
      _countdownTimer?.cancel();
    }
  }

  Future<void> _pollStatus() async {
    final order = _order;
    if (order == null || _isFinal) return;
    final fresh = await fetchQrisOrder((order['id'] ?? '').toString());
    if (!mounted || fresh == null) return;
    final st = (fresh['status'] ?? '').toString();
    if (st.isEmpty || st == _status) return;
    setState(() {
      _status = st;
      _order = fresh;
    });
    if (st == 'paid') {
      _countdownTimer?.cancel();
      _pollTimer?.cancel();
      if (!_paidNotified) {
        _paidNotified = true;
        widget.onPaid();
      }
    } else if (st == 'expired' || st == 'rejected') {
      _countdownTimer?.cancel();
      _pollTimer?.cancel();
    }
  }

  Future<void> _confirm() async {
    final order = _order;
    if (order == null || _status != 'pending' || _confirming) return;
    setState(() => _confirming = true);
    final res = await confirmQrisOrder((order['id'] ?? '').toString());
    if (!mounted) return;
    setState(() => _confirming = false);
    if (res.ok && res.data != null) {
      setState(() {
        _order = res.data;
        _status = (res.data!['status'] ?? 'awaiting_confirmation').toString();
      });
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(res.error ?? tr('bl_qris_err'))),
      );
    }
  }

  String _countdownLabel() {
    final d = _remaining;
    final mm = d.inMinutes.remainder(60).toString().padLeft(2, '0');
    final ss = d.inSeconds.remainder(60).toString().padLeft(2, '0');
    if (d.inHours > 0) {
      return '${d.inHours}:$mm:$ss';
    }
    return '$mm:$ss';
  }

  /// Nominal rp() dengan 3 digit terakhir ditebalkan + warna aksen:
  /// tiga digit itu kode unik yang membedakan order ini.
  Widget _amountText(BuildContext context) {
    final total = (_order?['amount_total'] as num?)?.toInt() ?? 0;
    final full = rp(total);
    final base = Theme.of(context).textTheme.headlineSmall?.copyWith(
          fontWeight: FontWeight.w600,
        ) ??
        const TextStyle(fontSize: 22, fontWeight: FontWeight.w600);
    if (full.length <= 3) return Text(full, style: base);
    final head = full.substring(0, full.length - 3);
    final tail = full.substring(full.length - 3);
    return Text.rich(
      TextSpan(
        children: [
          TextSpan(text: head, style: base),
          TextSpan(
            text: tail,
            style: base.copyWith(
              color: Theme.of(context).colorScheme.primary,
              fontWeight: FontWeight.w800,
            ),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(
          SsrSpace.lg,
          SsrSpace.lg,
          SsrSpace.lg,
          SsrSpace.xxl,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const Center(
              child: Container(
                width: 42,
                height: 4,
                decoration: BoxDecoration(
                  color: Color(0xFFD5E0F2),
                  borderRadius: BorderRadius.circular(99),
                ),
              ),
            ),
            const SizedBox(height: SsrSpace.md),
            Row(
              children: [
                Expanded(
                  child: Text(
                    _planName,
                    style: Theme.of(context)
                        .textTheme
                        .titleLarge
                        ?.copyWith(fontWeight: FontWeight.w800),
                  ),
                ),
                IconButton(
                  icon: const Icon(Icons.close),
                  onPressed: () => Navigator.of(context).pop(),
                ),
              ],
            ),
            const SizedBox(height: SsrSpace.md),
            ..._body(context),
          ],
        ),
      ),
    );
  }

  List<Widget> _body(BuildContext context) {
    if (_creating) {
      return [
        const SizedBox(height: SsrSpace.xxl),
        const Center(child: CircularProgressIndicator()),
        const SizedBox(height: SsrSpace.md),
        Center(child: Text(tr('bl_qris_creating'))),
        const SizedBox(height: SsrSpace.xxl),
      ];
    }
    if (_createError != null) {
      return [
        const SizedBox(height: SsrSpace.lg),
        Center(child: Text(_createError!, textAlign: TextAlign.center)),
        const SizedBox(height: SsrSpace.md),
        FilledButton(
          onPressed: _createOrder,
          child: Text(tr('retry')),
        ),
        const SizedBox(height: SsrSpace.lg),
      ];
    }
    if (_status == 'paid') {
      return [
        const SizedBox(height: SsrSpace.lg),
        Icon(
          Icons.check_circle,
          size: 64,
          color: DribTokens.success,
        ),
        const SizedBox(height: SsrSpace.md),
        Center(
          child: Text(
            tr('bl_qris_success'),
            textAlign: TextAlign.center,
            style: const TextStyle(
              fontSize: 15.5,
              fontWeight: FontWeight.w800,
              color: DribTokens.navy,
            ),
          ),
        ),
        const SizedBox(height: SsrSpace.lg),
        FilledButton(
          onPressed: () => Navigator.of(context).pop(),
          child: Text(tr('bl_qris_done')),
        ),
        const SizedBox(height: SsrSpace.lg),
      ];
    }

    final order = _order!;
    final payload = (order['qris_payload'] ?? '').toString();
    final expired = _status == 'expired';
    final rejected = _status == 'rejected';
    final children = <Widget>[
      Center(child: _amountText(context)),
      const SizedBox(height: SsrSpace.sm),
      Center(
        child: Text(
          tr('bl_qris_exact'),
          textAlign: TextAlign.center,
          style: const TextStyle(
            fontSize: 11,
            fontWeight: FontWeight.w600,
            color: DribTokens.textSecondary,
          ),
        ),
      ),
      const SizedBox(height: SsrSpace.lg),
      Center(
        child: Container(
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            color: Colors.white,
            border: Border.all(color: DribTokens.border, width: 1.5),
            borderRadius: BorderRadius.circular(18),
          ),
          child: Stack(
            alignment: Alignment.center,
            children: [
              Opacity(
                opacity: expired || rejected ? 0.25 : 1,
                child: QrImageView(
                  data: payload,
                  version: QrVersions.auto,
                  size: 240,
                  backgroundColor: Colors.white,
                  padding: const EdgeInsets.all(SsrSpace.md),
                ),
              ),
            if (expired)
              Text(
                tr('bl_qris_expired'),
                textAlign: TextAlign.center,
                style: Theme.of(context).textTheme.titleMedium,
              ),
              if (rejected)
                Text(
                  tr('bl_qris_rejected'),
                  textAlign: TextAlign.center,
                  style: Theme.of(context).textTheme.titleMedium,
                ),
            ],
          ),
        ),
      ),
      const SizedBox(height: SsrSpace.md),
      Center(
        child: Text(
          tr('bl_qris_scan_hint'),
          style: const TextStyle(
            fontSize: 11,
            fontWeight: FontWeight.w600,
            color: DribTokens.textSecondary,
          ),
        ),
      ),
    ];

    if (!expired && !rejected) {
      children.addAll([
        const SizedBox(height: SsrSpace.md),
        Center(
          child: StatusChip(
            label: _status == 'awaiting_confirmation'
                ? tr('bl_qris_waiting')
                : tr('bl_qris_status_pending'),
            tone: StatusTone.accent,
          ),
        ),
        if (_expiresAt != null) ...[
          const SizedBox(height: SsrSpace.sm),
          Center(
            child: Text(
              tr('bl_qris_expires_in')
                  .replaceFirst('{t}', _countdownLabel()),
              style: const TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w700,
                color: DribTokens.errorText,
              ),
            ),
          ),
        ],
        const SizedBox(height: SsrSpace.lg),
        if (_status == 'pending')
          FilledButton(
            onPressed: _confirming ? null : _confirm,
            child: _confirming
                ? const SizedBox(
                    height: 20,
                    width: 20,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : Text(tr('bl_qris_paid_btn')),
          ),
        if (_status == 'awaiting_confirmation')
          Text(
            tr('bl_qris_waiting'),
            textAlign: TextAlign.center,
            style: Theme.of(context).textTheme.bodyMedium,
          ),
      ]);
    }

    if (expired) {
      children.addAll([
        const SizedBox(height: SsrSpace.lg),
        FilledButton(
          onPressed: _createOrder,
          child: Text(tr('bl_qris_new_qr')),
        ),
      ]);
    }
    return children;
  }
}
