import 'package:flutter/material.dart';
import 'package:ssr_space/theme/app_icons.dart';
import 'package:ssr_space/theme/app_theme.dart';
import 'package:ssr_space/utils/strings.dart';
import 'package:ssr_space/widgets/nav_tile.dart';
import 'package:ssr_space/widgets/premium/glass_sheet.dart';

/// Mode input dari tombol + : live / scan OCR / scan vision / voice.
enum TxInputMode { live, scanManual, scanVision, voice }

/// Bottom sheet pilih mode. Null = batal.
Future<TxInputMode?> showInputModeSheet(BuildContext context) {
  return showModalBottomSheet<TxInputMode>(
    context: context,
    useSafeArea: true,
    backgroundColor: Colors.transparent,
    builder: (ctx) => GlassSheetScaffold(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(
          SsrSpace.md,
          SsrSpace.sm,
          SsrSpace.md,
          SsrSpace.lg,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              tr('mode_title'),
              style: Theme.of(ctx).textTheme.titleMedium,
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: SsrSpace.sm),
            NavTile(
              icon: AppIcons.add,
              title: tr('mode_live'),
              subtitle: tr('mode_live_s'),
              onTap: () => Navigator.pop(ctx, TxInputMode.live),
            ),
            const Divider(height: 1),
            NavTile(
              icon: AppIcons.scan,
              title: tr('mode_scan'),
              subtitle: tr('mode_scan_s'),
              onTap: () => Navigator.pop(ctx, TxInputMode.scanManual),
            ),
            const Divider(height: 1),
            NavTile(
              icon: AppIcons.autoBadge,
              title: tr('mode_vision'),
              subtitle: tr('mode_vision_s'),
              onTap: () => Navigator.pop(ctx, TxInputMode.scanVision),
            ),
            const Divider(height: 1),
            NavTile(
              icon: AppIcons.voice,
              title: tr('mode_voice'),
              subtitle: tr('mode_voice_s'),
              onTap: () => Navigator.pop(ctx, TxInputMode.voice),
            ),
          ],
        ),
      ),
    ),
  );
}
