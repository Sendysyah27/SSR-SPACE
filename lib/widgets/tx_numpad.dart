import 'package:flutter/material.dart';
import 'package:ssr_space/services/tx_input_logic.dart';
import 'package:ssr_space/theme/app_icons.dart';
import 'package:ssr_space/widgets/numpad_key.dart';

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
                        ? NumpadKey(
                            onTap: _backspace,
                            onLongPress: _clear,
                            child: const DuoIcon(AppIcons.backspace),
                          )
                        : NumpadKey(
                            onTap: () => _press(key),
                            child: Text(
                              key,
                              style: const TextStyle(
                                fontSize: 22,
                                fontWeight: FontWeight.w600,
                                fontFeatures: [FontFeature.tabularFigures()],
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
