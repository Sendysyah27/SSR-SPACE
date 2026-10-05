import 'package:flutter/material.dart';
import 'package:ssr_space/services/tx_input_logic.dart';
import 'package:ssr_space/theme/app_icons.dart';
import 'package:ssr_space/utils/strings.dart';
import 'package:ssr_space/widgets/numpad_key.dart';

/// Numpad PIN on-screen: 1-9, slot kosong, 0, hapus.
/// Menulis langsung ke [controller] (listener `PinField` yang gambar);
/// keyboard sistem tak pernah dibuka. Gaya tombol sama dengan
/// `TxNumpad`, satu motif numpad untuk seluruh app.
/// Tekan-lama tombol hapus = bersihkan semua.
class PinPad extends StatelessWidget {
  final TextEditingController controller;
  final int length;

  const PinPad({super.key, required this.controller, this.length = 6});

  void _press(String key) {
    controller.text = pinKeyInput(controller.text, key, maxLen: length);
  }

  void _backspace() {
    controller.text = numpadBackspace(controller.text);
  }

  void _clear() {
    controller.clear();
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
          ['', '0', 'back'],
        ])
          Row(
            children: [
              for (final key in row)
                Expanded(
                  child: Padding(
                    padding: const EdgeInsets.all(4),
                    child: key == ''
                        ? const SizedBox(height: 60)
                        : key == 'back'
                        ? NumpadKey(
                            onTap: _backspace,
                            onLongPress: _clear,
                            child: Semantics(
                              label: tr('tx_delete'),
                              child: const DuoIcon(AppIcons.backspace),
                            ),
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
