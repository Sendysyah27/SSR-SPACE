import 'package:flutter/material.dart';
import 'package:lottie/lottie.dart';
import 'package:ssr_space/theme/app_icons.dart';
import 'package:ssr_space/theme/app_theme.dart';

/// Kilatan sukses: animasi centang ~900ms di atas konten saat simpan
/// berhasil, lalu hilang sendiri. Logika simpan/pesan tak berubah.
Future<void> showSuccessFlash(BuildContext context) async {
  final overlay = Overlay.of(context);
  late final OverlayEntry entry;
  entry = OverlayEntry(
    builder: (_) => const IgnorePointer(child: Center(child: _FlashCard())),
  );
  overlay.insert(entry);
  await Future.delayed(const Duration(milliseconds: 950));
  entry.remove();
}

class _FlashCard extends StatelessWidget {
  const _FlashCard();

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 120,
      height: 120,
      padding: const EdgeInsets.all(SsrSpace.lg),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(SsrRadius.card),
        boxShadow: [
          BoxShadow(
            color: SsrColors.ink.withValues(alpha: 0.16),
            blurRadius: 24,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: Lottie.asset(
        'assets/lottie/check_pop.json',
        repeat: false,
        errorBuilder: (context, error, stackTrace) =>
            DuoIcon(AppIcons.success, color: SsrColors.accent, size: 48),
      ),
    );
  }
}
