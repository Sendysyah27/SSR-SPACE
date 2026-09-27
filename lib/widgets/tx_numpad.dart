import 'package:flutter/material.dart';
import 'package:ssr_space/services/tx_input_logic.dart';
import 'package:ssr_space/theme/app_icons.dart';
import 'package:ssr_space/theme/app_theme.dart';

/// Numpad ala e-wallet untuk input nominal: 1-9, 000, 0, hapus.
/// Keyboard sistem tidak pernah dibuka — satu tangan, malam hari.
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

/// Satu tombol numpad: 60px (di atas minimum sentuh 44px), sudut
/// tile mengikuti radius sistem, tanpa glow/dekorasi.
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
    return Material(
      color: SsrColors.accentSoft,
      borderRadius: BorderRadius.circular(SsrRadius.tile),
      child: InkWell(
        borderRadius: BorderRadius.circular(SsrRadius.tile),
        onTap: onTap,
        onLongPress: onLongPress,
        child: SizedBox(
          height: 60,
          child: Center(
            child: IconTheme(
              data: const IconThemeData(color: SsrColors.ink, size: 24),
              child: DefaultTextStyle(
                style: const TextStyle(color: SsrColors.ink),
                child: child,
              ),
            ),
          ),
        ),
      ),
    );
  }
}
