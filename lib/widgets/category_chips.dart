import 'package:flutter/material.dart';
import 'package:ssr_space/services/app_categories.dart';
import 'package:ssr_space/theme/app_theme.dart';
import 'package:ssr_space/widgets/status_chip.dart';

/// Saran kategori global: ketuk chip untuk mengisi [controller].
/// Mengetik bebas di field tetap bisa — chip hanya jalan pintas.
/// Chip yang sama dengan [selected] tampil aksen (umpan balik pilihan).
class CategoryChips extends StatelessWidget {
  final TextEditingController controller;
  final String? selected;
  final ValueChanged<String>? onPick;

  const CategoryChips({
    super.key,
    required this.controller,
    this.selected,
    this.onPick,
  });

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<List<String>>(
      valueListenable: appCategories,
      builder: (_, cats, __) {
        if (cats.isEmpty) return const SizedBox.shrink();
        return Wrap(
          spacing: 6,
          runSpacing: 6,
          children: [
            for (final c in cats)
              InkWell(
                borderRadius: BorderRadius.circular(SsrRadius.chip),
                onTap: () {
                  controller.text = c;
                  onPick?.call(c);
                },
                child: StatusChip(
                  label: c,
                  tone: c == selected
                      ? StatusTone.accent
                      : StatusTone.neutral,
                ),
              ),
          ],
        );
      },
    );
  }
}
