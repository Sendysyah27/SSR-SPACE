import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:ssr_space/theme/dribbble_tokens.dart';

/// Satu iris donut.
class DonutSlice {
  final double value;
  final String label;
  final Color color;
  const DonutSlice({
    required this.value,
    required this.label,
    required this.color,
  });
}

/// Donut + legenda gaya referensi TAHAP 3 (baru, belum dipakai layar).
///
/// Palet baku: biru [DribTokens.primary], navy [DribTokens.navy],
/// oranye [DribTokens.accentOrange]. Sentuh dimatikan (tanpa animasi).
class DonutChart extends StatelessWidget {
  final List<DonutSlice> slices;

  /// Teks tengah donut (mis. total). Null = donut polos.
  final String? centerText;

  /// Mode ringkas untuk gauge kecil (tinggi 64, tanpa legenda).
  final bool compact;

  const DonutChart({
    super.key,
    required this.slices,
    this.centerText,
    this.compact = false,
  });

  @override
  Widget build(BuildContext context) {
    final live = slices.where((s) => s.value > 0).toList();
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        SizedBox(
          height: compact ? 64 : 180,
          child: Stack(
            children: [
              PieChart(
                PieChartData(
                  pieTouchData: PieTouchData(enabled: false),
                  sectionsSpace: 2,
                  centerSpaceRadius: 52,
                  startDegreeOffset: 270,
                  sections: live.isEmpty
                      ? [
                          PieChartSectionData(
                            value: 1,
                            color: DribTokens.navy.withValues(alpha: 0.12),
                            radius: 26,
                            showTitle: false,
                          ),
                        ]
                      : [
                          for (final s in live)
                            PieChartSectionData(
                              value: s.value,
                              color: s.color,
                              radius: 26,
                              showTitle: false,
                            ),
                        ],
                ),
              ),
              if (centerText != null)
                Center(
                  child: Text(
                    centerText!,
                    style: DribTokens.bigNumber(size: 20),
                  ),
                ),
            ],
          ),
        ),
        if (!compact) ...[
          const SizedBox(height: 12),
          Wrap(
            spacing: 16,
            runSpacing: 8,
            alignment: WrapAlignment.center,
            children: [
              for (final s in live)
                Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Container(
                      width: 10,
                      height: 10,
                      decoration: BoxDecoration(
                        color: s.color,
                        shape: BoxShape.circle,
                      ),
                    ),
                    const SizedBox(width: 6),
                    Text(s.label, style: const TextStyle(fontSize: 12)),
                  ],
                ),
              ],
            ),
        ],
      ),
    );
  }
}
