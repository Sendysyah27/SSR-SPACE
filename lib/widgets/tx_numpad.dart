import 'package:flutter/material.dart';
import 'package:ssr_space/services/tx_input_logic.dart';
import 'package:ssr_space/theme/app_icons.dart';
import 'package:ssr_space/theme/app_theme.dart';

/// Numpad ala e-wallet untuk input nominal: 1-9, 000, 0, hapus.
/// Keyboard sistem tidak pernah dibuka. Satu tangan, malam hari.
/// State berupa [digits] (buffer mentah); konversi ke nominal via
/// `majorFromDigits` di sisi pemanggil (sadar desimal mata uang).
class TxNumpad extends StatelessWidget {
  final ValueNotifier<String> digits;
  final int maxLen;

  const TxNumpad({super.key, required this.digits, this.maxLen = 15});

  void _press(String key) {
    digits.value = numpadAppend(digits.value, key, maxLen: maxLen);
  }

  void _backspace() {
    digits.value = numpadBackspace(digits.value);
  }

  void _clear() {
    digits.value = '';
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        for (final row in const [
          ['1', '2', '3'],
          ['4', '5', '6'],
          ['7', '8', '9'],
          ['000', '0', 'back'],
        ])
          Row(
            children: [
              for (final key in row)
                Expanded(
                  child: Padding(
                    padding: const EdgeInsets.all(4),
                    child: key == 'back'
                        ? _NumpadKey(
                            onTap: _backspace,
                            onLongPress: _clear,
                            child: const DuoIcon(AppIcons.backspace),
                          )
                        : _NumpadKey(
                            onTap: () => _press(key),
                            child: Text(
                              key,
                              style: const TextStyle(
                                fontSize: 22,
                                fontWeight: FontWeight.w600,
                                fontFeatures: [
                                  FontFeature.tabularFigures(),
                                ],
                              ),
                            ),
                            ),
                    ),
                  ),
            ],
          ),
      ],
    );
  }
}

/// Satu tombol numpad: 60px (di atas minimum sentuh 44px), surface
/// terangkat dengan garis outline, cipratan primer saat ditekan.
class _NumpadKey extends StatelessWidget {
  final Widget child;
  final VoidCallback onTap;
  final VoidCallback? onLongPress;

  const _NumpadKey({
    required this.child,
    required this.onTap,
    this.onLongPress,
  });

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Material(
      color: scheme.outline.withValues(alpha: 0.35),
      borderRadius: BorderRadius.circular(SsrRadius.tile),
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
