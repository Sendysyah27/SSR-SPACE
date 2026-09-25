import 'package:flutter/material.dart';
import 'package:ssr_space/theme/app_theme.dart';

/// Pilihan jenis transaksi Masuk / Keluar / Transfer (pill toggle).
/// Dipakai di form layar Transaksi; style disalin persis dari aslinya
/// (selected = latar zamrud, teks putih, outline mengikuti tema).
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
      segments: const [
        ButtonSegment(value: 'in', label: Text('Masuk')),
        ButtonSegment(value: 'out', label: Text('Keluar')),
        ButtonSegment(value: 'transfer', label: Text('Transfer')),
      ],
      selected: {value},
      onSelectionChanged: (v) => onChanged(v.first),
      showSelectedIcon: false,
      style: ButtonStyle(
        backgroundColor: WidgetStateProperty.resolveWith((states) {
          if (states.contains(WidgetState.selected)) {
            return SsrColors.accent;
          }
          return Colors.white;
        }),
        foregroundColor: WidgetStateProperty.resolveWith((states) {
          if (states.contains(WidgetState.selected)) {
            return Colors.white;
          }
          return SsrColors.ink;
        }),
        side: WidgetStateProperty.resolveWith((states) {
          if (states.contains(WidgetState.selected)) {
            return const BorderSide(color: SsrColors.accent);
          }
          return BorderSide(color: Theme.of(context).colorScheme.outline);
        }),
        textStyle: WidgetStateProperty.all(
          const TextStyle(fontSize: 13, fontWeight: FontWeight.w600),
        ),
      ),
    );
  }
}
