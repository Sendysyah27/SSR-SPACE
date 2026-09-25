import 'package:flutter/material.dart';
import 'package:ssr_space/core/format/mask.dart';

class MaskToggle extends StatelessWidget {
  const MaskToggle({super.key});

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<bool>(
      valueListenable: maskAmounts,
      builder: (context, masked, _) => IconButton(
        tooltip: masked ? 'Tampilkan nominal' : 'Samarkan nominal',
        icon: Icon(
          masked ? Icons.visibility_off_outlined : Icons.visibility_outlined,
        ),
        onPressed: () => setMaskAmounts(!masked),
      ),
    );
  }
}
