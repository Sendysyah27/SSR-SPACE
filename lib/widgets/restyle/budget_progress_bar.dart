import 'package:flutter/material.dart';
import 'package:ssr_space/theme/dribbble_tokens.dart';

/// Bar progres budget gaya referensi TAHAP 3 (baru, belum dipakai layar).
///
/// Track abu muda + fill biru (navy bila >= 100%) + label persen kanan.
class BudgetProgressBar extends StatelessWidget {
  /// 0.0–1.0+ (boleh > 1 bila jebol).
  final double progress;

  /// Label persen tampil ("75%").
  final String label;

  const BudgetProgressBar({
    super.key,
    required this.progress,
    required this.label,
  });

  @override
  Widget build(BuildContext context) {
    final over = progress >= 1;
    final clamped = progress.clamp(0.0, 1.0);
    return Row(
      children: [
        Expanded(
          child: ClipRRect(
            borderRadius: BorderRadius.circular(999),
            child: LinearProgressIndicator(
              value: clamped,
              minHeight: 8,
              backgroundColor:
                  DribTokens.navy.withValues(alpha: 0.10),
              valueColor: AlwaysStoppedAnimation<Color>(
                over ? DribTokens.navy : DribTokens.primary,
              ),
            ),
          ),
        ),
        const SizedBox(width: 8),
        Text(
          label,
          style: TextStyle(
            fontSize: 12,
            fontWeight: FontWeight.w700,
            color: DribTokens.navy.withValues(alpha: 0.7),
            fontFeatures: const [FontFeature.tabularFigures()],
          ),
        ),
      ],
    );
  }
}
