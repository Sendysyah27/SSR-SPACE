import 'package:flutter/material.dart';
import 'package:ssr_space/theme/app_icons.dart';
import 'package:ssr_space/utils/strings.dart';
import 'package:ssr_space/utils/mask.dart';

class MaskToggle extends StatelessWidget {
  const MaskToggle({super.key});

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<bool>(
      valueListenable: maskAmounts,
      builder: (context, masked, _) => IconButton(
        tooltip: masked ? tr('mt_show') : tr('o_mask'),
        icon: DuoIcon(masked ? AppIcons.eyeOff : AppIcons.eye),
        onPressed: () => setMaskAmounts(!masked),
      ),
    );
  }
}
