import 'package:flutter/material.dart';
import 'package:ssr_space/theme/app_theme.dart';

/// Satu tombol numpad: 60px (di atas minimum sentuh 44px), surface
/// terangkat dengan garis outline, cipratan primer saat ditekan.
/// Dipakai TxNumpad (nominal) dan PinPad (PIN) supaya gaya seragam.
class NumpadKey extends StatelessWidget {
  final Widget child;
  final VoidCallback onTap;
  final VoidCallback? onLongPress;

  const NumpadKey({
    super.key,
    required this.child,
    required this.onTap,
    this.onLongPress,
  });

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Material(
      color: scheme.outline.withValues(alpha: 0.35),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(SsrRadius.tile),
        side: BorderSide(color: scheme.outline),
      ),
      child: InkWell(
        borderRadius: BorderRadius.circular(SsrRadius.tile),
        splashColor: scheme.primary.withValues(alpha: 0.22),
        highlightColor: scheme.primary.withValues(alpha: 0.12),
        onTap: onTap,
        onLongPress: onLongPress,
        child: SizedBox(
          height: 60,
          child: Center(
            child: IconTheme(
              data: IconThemeData(color: scheme.onSurface, size: 24),
              child: DefaultTextStyle(
                style: TextStyle(color: scheme.onSurface),
                child: child,
              ),
            ),
          ),
        ),
      ),
    );
  }
}
