import 'package:flutter/material.dart';
import 'package:ssr_space/theme/tokens.dart';

/// Batch 6 (2.61.0+169) — wadah kaca untuk bottom sheet & dialog.
///
/// Pola pakai:
/// ```dart
/// showModalBottomSheet(
///   context: context,
///   backgroundColor: Colors.transparent, // WAJIB: biar kaca yang gambar bg
///   isScrollControlled: true,
///   useSafeArea: true,
///   builder: (_) => GlassSheetScaffold(child: MySheetContent()),
/// );
/// ```
/// Jangan pasang `shape` di showModalBottomSheet — radius diatur di sini (28).
class GlassSheetScaffold extends StatelessWidget {
  const GlassSheetScaffold({
    super.key,
    required this.child,
    this.showHandle = true,
  });

  final Widget child;
  final bool showHandle;

  static const _radius = BorderRadius.vertical(top: Radius.circular(28));

  @override
  Widget build(BuildContext context) {
    // BUG C fix: latar OPAK (surface solid) agar isi sheet tidak tembus
    // pandang di mode terang maupun gelap. Warna ikut tema.
    final surface = Theme.of(context).colorScheme.surface;
    return ClipRRect(
      borderRadius: _radius,
      child: DecoratedBox(
        decoration: BoxDecoration(
          borderRadius: _radius,
          color: surface,
          border: Border(
            top: BorderSide(
              color: Theme.of(context).colorScheme.outlineVariant,
              width: 1,
            ),
          ),
          boxShadow: GlassElevation.sheet,
        ),
        child: SafeArea(
          top: false,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              if (showHandle) ...[
                const SizedBox(height: GlassSpace.sm),
                const _GlassDragHandle(),
              ],
              child,
            ],
          ),
        ),
      ),
    );
  }
}

class _GlassDragHandle extends StatelessWidget {
  const _GlassDragHandle();

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Container(
        width: 44,
        height: 5,
        decoration: BoxDecoration(
          color: Colors.white.withValues(alpha: 0.28),
          borderRadius: BorderRadius.circular(3),
        ),
      ),
    );
  }
}

/// Dialog kaca pengganti AlertDialog — layout title/content/actions sama.
Future<T?> showGlassDialog<T>({
  required BuildContext context,
  required Widget title,
  required Widget content,
  List<Widget> actions = const [],
}) {
  final theme = Theme.of(context);
  return showDialog<T>(
    context: context,
    builder: (ctx) => Dialog(
      // BUG C fix: Dialog bawaan sudah opak (surface solid ikut tema).
      insetPadding: const EdgeInsets.symmetric(
        horizontal: GlassSpace.lg,
        vertical: GlassSpace.xl,
      ),
      child: Padding(
        padding: const EdgeInsets.all(GlassSpace.lg),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            DefaultTextStyle(
              style: theme.textTheme.titleLarge!,
              child: title,
            ),
            const SizedBox(height: GlassSpace.sm),
            DefaultTextStyle(
              style: theme.textTheme.bodyMedium!,
              child: content,
            ),
            if (actions.isNotEmpty) ...[
              const SizedBox(height: GlassSpace.md),
              Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  for (var i = 0; i < actions.length; i++) ...[
                    if (i > 0) const SizedBox(width: GlassSpace.sm),
                    actions[i],
                  ],
                ],
              ),
            ],
          ],
        ),
      ),
    ),
  );
}
