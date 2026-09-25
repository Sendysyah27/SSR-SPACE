import 'package:flutter/material.dart';
import 'package:phosphor_flutter/phosphor_flutter.dart';
import 'package:ssr_space/theme/app_icons.dart';
import 'package:ssr_space/utils/mask.dart';

class MaskToggle extends StatelessWidget {
  const MaskToggle({super.key});

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<bool>(
      valueListenable: maskAmounts,
      builder: (context, masked, _) => IconButton(
        tooltip: masked ? 'Tampilkan nominal' : 'Samarkan nominal',
        icon: PhosphorIcon(
          masked ? AppIcons.eyeOff : AppIcons.eye,
        ),
        onPressed: () => setMaskAmounts(!masked),
      ),
    );
  }
}
