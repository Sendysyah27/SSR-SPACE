import 'package:flutter/material.dart';
import 'package:ssr_space/utils/strings.dart';

/// Gaya segmented tunggal seluruh app: pilihan terisi primer penuh,
/// sisanya surface dengan teks sekunder, border primer/outline.
/// Selalu ikut colorScheme ambient via context yang wajib diisi.
ButtonStyle ssrSegmentedStyle(BuildContext context) {
  final scheme = Theme.of(context).colorScheme;
  final unselectedFg =
      Theme.of(context).textTheme.bodySmall?.color ?? scheme.onSurface;
  return ButtonStyle(
    backgroundColor: WidgetStateProperty.resolveWith((states) {
      if (states.contains(WidgetState.selected)) {
        return scheme.primary;
      }
      return Colors.transparent;
    }),
    foregroundColor: WidgetStateProperty.resolveWith((states) {
      if (states.contains(WidgetState.selected)) {
        return scheme.onPrimary;
      }
      return unselectedFg;
    }),
    side: WidgetStateProperty.resolveWith((states) {
      if (states.contains(WidgetState.selected)) {
        return BorderSide(color: scheme.primary);
      }
      return BorderSide(color: scheme.outline);
    }),
    textStyle: WidgetStateProperty.all(
      const TextStyle(fontSize: 13, fontWeight: FontWeight.w600),
    ),
  );
}

/// Pilihan jenis transaksi Masuk / Keluar / Transfer (pill toggle).
/// Satu gaya untuk semua pemakaian: pilihan terisi primer penuh,
/// sisanya surface dengan teks sekunder.
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
      style: ssrSegmentedStyle(context),
    );
  }
}
