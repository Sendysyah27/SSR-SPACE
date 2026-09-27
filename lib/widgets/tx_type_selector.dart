import 'package:flutter/material.dart';
import 'package:ssr_space/theme/app_theme.dart';
import 'package:ssr_space/utils/strings.dart';

/// Pilihan jenis transaksi Masuk / Keluar / Transfer (pill toggle).
/// Satu gaya untuk semua pemakaian: pilihan terisi mint penuh dengan
/// teks gelap, sisanya surface noir dengan teks sekunder.
class TxTypeSelector extends StatelessWidget {
  final String value;
  final ValueChanged<String> onChanged;

  const TxTypeSelector({
    super.key,
    required this.value,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    return SegmentedButton<String>(
      segments: [
        ButtonSegment(value: 'in', label: Text(tr('tx_in'))),
        ButtonSegment(value: 'out', label: Text(tr('tx_out'))),
        ButtonSegment(value: 'transfer', label: Text(tr('tx_transfer'))),
      ],
      selected: {value},
      onSelectionChanged: (v) => onChanged(v.first),
      showSelectedIcon: false,
      style: ButtonStyle(
        backgroundColor: WidgetStateProperty.resolveWith((states) {
          if (states.contains(WidgetState.selected)) {
            return SsrColors.mint;
          }
          return SsrColors.noirSurface;
        }),
        foregroundColor: WidgetStateProperty.resolveWith((states) {
          if (states.contains(WidgetState.selected)) {
            return const Color(0xFF0C1210);
          }
          return SsrColors.noirSecondary;
        }),
        side: WidgetStateProperty.resolveWith((states) {
          if (states.contains(WidgetState.selected)) {
            return const BorderSide(color: SsrColors.mint);
          }
          return const BorderSide(color: SsrColors.noirLine);
        }),
        textStyle: WidgetStateProperty.all(
          const TextStyle(fontSize: 13, fontWeight: FontWeight.w600),
        ),
      ),
    );
  }
}
