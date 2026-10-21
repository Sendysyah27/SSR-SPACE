import 'package:flutter/material.dart';
import 'package:ssr_space/theme/app_theme.dart';
import 'package:ssr_space/utils/strings.dart';
import 'package:ssr_space/widgets/premium/glass_sheet.dart';

/// Aksi pilihan user di sheet error scan (batch 284 tahap D).
enum ScanErrorAction { retry, replace, manual }

/// Sheet error scan ala Ollo: pesan error + 3 aksi — Coba Lagi (foto
/// yang sama, tanpa kamera/galeri ulang), Ganti Foto, Isi Manual.
/// Null = sheet ditutup tanpa pilihan (pemanggil memperlakukannya
/// seperti Isi Manual).
Future<ScanErrorAction?> showScanErrorSheet(
  BuildContext context, {
  required String message,
}) {
  return showModalBottomSheet<ScanErrorAction>(
    context: context,
    isScrollControlled: true,
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
              tr('scan_err_title'),
              style: Theme.of(ctx).textTheme.titleMedium,
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: SsrSpace.sm),
            Text(
              message,
              style: Theme.of(ctx).textTheme.bodyMedium?.copyWith(
                    color: Theme.of(ctx).colorScheme.error,
                  ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: SsrSpace.md),
            FilledButton.icon(
              onPressed: () => Navigator.pop(ctx, ScanErrorAction.retry),
              icon: const Icon(Icons.refresh),
              label: Text(tr('scan_err_retry')),
            ),
            const SizedBox(height: SsrSpace.sm),
            OutlinedButton.icon(
              onPressed: () => Navigator.pop(ctx, ScanErrorAction.replace),
              icon: const Icon(Icons.photo_camera_outlined),
              label: Text(tr('scan_err_replace')),
            ),
            const SizedBox(height: SsrSpace.sm),
            TextButton(
              onPressed: () => Navigator.pop(ctx, ScanErrorAction.manual),
              child: Text(tr('scan_err_manual')),
            ),
          ],
        ),
      ),
    ),
  );
}
