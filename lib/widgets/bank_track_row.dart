import 'package:flutter/material.dart';
import 'package:ssr_space/models/wallet.dart';
import 'package:ssr_space/theme/app_theme.dart';

/// Satu baris pengaturan app bank/dompet di layar "Pelacakan otomatis":
/// switch on/off app + (bila daftar dompet tersedia) dropdown dompet tujuan
/// dan field kategori di bawahnya. Nominal tidak ada di baris ini.
class BankTrackRow extends StatelessWidget {
  final String label;
  final String subtitle;
  final bool value;
  final ValueChanged<bool> onChanged;
  final bool showMapping;
  final String? walletValue;
  final List<Wallet> wallets;
  final ValueChanged<String?> onWalletChanged;
  final String categoryValue;
  final ValueChanged<String> onCategoryChanged;

  const BankTrackRow({
    super.key,
    required this.label,
    required this.subtitle,
    required this.value,
    required this.onChanged,
    required this.showMapping,
    this.walletValue,
    required this.wallets,
    required this.onWalletChanged,
    required this.categoryValue,
    required this.onCategoryChanged,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        SwitchListTile(
          contentPadding: EdgeInsets.zero,
          title: Text(label),
          subtitle: Text(subtitle),
          value: value,
          onChanged: onChanged,
        ),
        if (showMapping)
          Padding(
            padding: const EdgeInsets.only(left: 4, bottom: SsrSpace.md),
            child: Row(
              children: [
                Expanded(
                  child: DropdownButtonFormField<String?>(
                    initialValue: walletValue,
                    isExpanded: true,
                    decoration: const InputDecoration(
                      labelText: 'Masuk ke dompet',
                      isDense: true,
                    ),
                    items: [
                      const DropdownMenuItem<String?>(
                        value: null,
                        child: Text('Otomatis / ikut nama'),
                      ),
                      for (final w in wallets)
                        DropdownMenuItem<String?>(
                          value: w.id,
                          child: Text(w.name),
                        ),
                    ],
                    onChanged: onWalletChanged,
                  ),
                ),
                const SizedBox(width: SsrSpace.sm),
                Expanded(
                  child: TextFormField(
                    initialValue: categoryValue,
                    decoration: const InputDecoration(
                      labelText: 'Kategori',
                      isDense: true,
                    ),
                    onChanged: onCategoryChanged,
                  ),
                ),
              ],
            ),
          ),
      ],
    );
  }
}
