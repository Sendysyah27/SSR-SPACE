import 'dart:io';

import 'package:flutter/material.dart';
import 'package:google_mlkit_text_recognition/google_mlkit_text_recognition.dart';
import 'package:image/image.dart' as img;
import 'package:image_picker/image_picker.dart';
import 'package:ssr_space/services/receipt_parse.dart';
import 'package:ssr_space/theme/dribbble_tokens.dart';
import 'package:ssr_space/utils/strings.dart';
import 'package:ssr_space/widgets/entry/ocr_camera_screen.dart';
import 'package:ssr_space/widgets/entry/voice_draft_sheet.dart';

/// Hasil urai OCR dari struk (nominal dalam IDR).
class OcrDraft {
  final String merchant;
  final double amount;
  final DateTime date;
  final String rawText;

  const OcrDraft({
    required this.merchant,
    required this.amount,
    required this.date,
    required this.rawText,
  });
}

/// Alur Scan OCR on-device (TANPA AI/cloud): sumber gambar -> pengaturan ->
/// OCR -> parse heuristik -> draft review (UI ala voice draft) -> simpan.
/// true bila transaksi tersimpan.
Future<bool> openOcrFlow(BuildContext context) async {
  final source = await _pickOcrSource(context);
  if (source == null || !context.mounted) return false;

  // Kamera: layar khusus dengan toggle flash. Galeri: image_picker.
  String? path;
  if (source == ImageSource.camera) {
    path = await openOcrCamera(context);
  } else {
    // Batasi resolusi: foto 12MP full-res -> decode ~48MB+ rawan OOM di HP
    // mid-range (fix #11). 2048px cukup untuk OCR struk.
    final XFile? file = await ImagePicker().pickImage(
      source: source,
      maxWidth: 2048,
      maxHeight: 2048,
      imageQuality: 92,
    );
    path = file?.path;
  }
  if (path == null || !context.mounted) return false;

  final bool? enhance = await _showOcrSettingsSheet(context, path);
  if (enhance == null || !context.mounted) return false;

  // OCR dengan loading + opsi coba lagi bila teks tak terbaca.
  String? rawText;
  var retry = true;
  while (retry) {
    if (!context.mounted) return false;
    _showOcrLoading(context);
    try {
      rawText = await _runOcr(path, enhance: enhance);
    } finally {
      if (context.mounted) Navigator.of(context, rootNavigator: true).pop();
    }
    if (!context.mounted) return false;
    if (rawText == null || rawText.trim().isEmpty) {
      retry = await _showOcrErrorSheet(context) ?? false;
      if (!context.mounted) return false;
      rawText = null;
    } else {
      retry = false;
    }
  }
  if (rawText == null || rawText.trim().isEmpty || !context.mounted) {
    return false;
  }

  final draft = _parseOcr(rawText);
  if (!context.mounted) return false;

  // Pakai ulang UI draft ala voice: konversi ke VoiceDraft.
  return showVoiceDraftSheet(
    context,
    VoiceDraft(
      amount: draft.amount,
      type: 'out',
      title: draft.merchant,
      dateTime: draft.date,
    ),
  );
}

/// Dialog pilih sumber gambar: kamera / galeri.
Future<ImageSource?> _pickOcrSource(BuildContext context) {
  return showModalBottomSheet<ImageSource>(
    context: context,
    useSafeArea: true,
    backgroundColor: Colors.transparent,
    builder: (ctx) => Container(
      decoration: BoxDecoration(
        color: DribTokens.cardOf(ctx),
        borderRadius: const BorderRadius.vertical(
          top: Radius.circular(DribTokens.sheetRadius),
        ),
      ),
      padding: const EdgeInsets.fromLTRB(20, 10, 20, 28),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          _dragHandle(ctx),
          const SizedBox(height: 12),
          Text(
            tr('ocr_src_title'),
            style: Theme.of(ctx)
                .textTheme
                .titleMedium
                ?.copyWith(fontWeight: FontWeight.w700),
          ),
          const SizedBox(height: 8),
          ListTile(
            leading: const Icon(Icons.photo_camera_outlined),
            title: Text(tr('ocr_src_camera')),
            onTap: () => Navigator.pop(ctx, ImageSource.camera),
          ),
          ListTile(
            leading: const Icon(Icons.photo_library_outlined),
            title: Text(tr('ocr_src_gallery')),
            onTap: () => Navigator.pop(ctx, ImageSource.gallery),
          ),
        ],
      ),
    ),
  );
}

/// Sheet pengaturan OCR: pratinjau gambar + toggle tingkatkan kontras.
Future<bool?> _showOcrSettingsSheet(BuildContext context, String imagePath) {
  var enhance = false;
  return showModalBottomSheet<bool>(
    context: context,
    useSafeArea: true,
    isScrollControlled: true,
    backgroundColor: Colors.transparent,
    builder: (ctx) => StatefulBuilder(
      builder: (ctx, setState) => Container(
        decoration: BoxDecoration(
          color: DribTokens.cardOf(ctx),
          borderRadius: const BorderRadius.vertical(
            top: Radius.circular(DribTokens.sheetRadius),
          ),
        ),
        padding: const EdgeInsets.fromLTRB(20, 10, 20, 28),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            _dragHandle(ctx),
            const SizedBox(height: 12),
            Text(
              tr('ocr_settings_title'),
              style: Theme.of(ctx)
                  .textTheme
                  .titleMedium
                  ?.copyWith(fontWeight: FontWeight.w700),
            ),
            const SizedBox(height: 4),
            Text(
              tr('ocr_settings_desc'),
              textAlign: TextAlign.center,
              style: Theme.of(ctx).textTheme.bodySmall?.copyWith(
                    color: Theme.of(ctx).colorScheme.onSurfaceVariant,
                  ),
            ),
            const SizedBox(height: 12),
            ClipRRect(
              borderRadius: BorderRadius.circular(12),
              child: Image.file(
                File(imagePath),
                height: 220,
                width: double.infinity,
                fit: BoxFit.cover,
              ),
            ),
            SwitchListTile(
              title: Text(tr('ocr_enhance')),
              subtitle: Text(tr('ocr_enhance_sub')),
              value: enhance,
              onChanged: (v) => setState(() => enhance = v),
            ),
            const SizedBox(height: 8),
            Row(
              children: [
                Expanded(
                  child: OutlinedButton(
                    onPressed: () => Navigator.pop(ctx),
                    child: Text(tr('cancel')),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: FilledButton(
                    onPressed: () => Navigator.pop(ctx, enhance),
                    child: Text(tr('ocr_process')),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    ),
  );
}

/// Dialog loading selama OCR berjalan.
void _showOcrLoading(BuildContext context) {
  showDialog(
    context: context,
    barrierDismissible: false,
    builder: (ctx) => Center(
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 28, vertical: 22),
        decoration: BoxDecoration(
          color: DribTokens.cardOf(ctx),
          borderRadius: BorderRadius.circular(16),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const CircularProgressIndicator(),
            const SizedBox(height: 12),
            Text(tr('ocr_processing')),
          ],
        ),
      ),
    ),
  );
}

/// Sheet error: teks tidak terbaca -> coba lagi / batal.
Future<bool?> _showOcrErrorSheet(BuildContext context) {
  return showModalBottomSheet<bool>(
    context: context,
    useSafeArea: true,
    backgroundColor: Colors.transparent,
    builder: (ctx) {
      final scheme = Theme.of(ctx).colorScheme;
      return Container(
        decoration: BoxDecoration(
          color: DribTokens.cardOf(ctx),
          borderRadius: const BorderRadius.vertical(
            top: Radius.circular(DribTokens.sheetRadius),
          ),
        ),
        padding: const EdgeInsets.fromLTRB(20, 10, 20, 28),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            _dragHandle(ctx),
            const SizedBox(height: 12),
            Icon(
              Icons.text_snippet_outlined,
              size: 44,
              color: scheme.onSurfaceVariant,
            ),
            const SizedBox(height: 12),
            Text(
              tr('ocr_err_empty'),
              textAlign: TextAlign.center,
              style: TextStyle(color: scheme.onSurfaceVariant),
            ),
            const SizedBox(height: 16),
            Row(
              children: [
                Expanded(
                  child: OutlinedButton(
                    onPressed: () => Navigator.pop(ctx, false),
                    child: Text(tr('cancel')),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: FilledButton(
                    onPressed: () => Navigator.pop(ctx, true),
                    child: Text(tr('ocr_retry')),
                  ),
                ),
              ],
            ),
          ],
        ),
      );
    },
  );
}

Widget _dragHandle(BuildContext ctx) {
  return Container(
    width: 40,
    height: 4,
    decoration: BoxDecoration(
      borderRadius: BorderRadius.circular(2),
      color: Theme.of(ctx).colorScheme.outlineVariant,
    ),
  );
}

/// Jalankan OCR ML Kit (latin). Bila [enhance], gambar di-grayscale +
/// kontras dulu memakai package image.
Future<String?> _runOcr(String path, {required bool enhance}) async {
  var usePath = path;
  if (enhance) usePath = await _enhanceContrast(path);
  final recognizer = TextRecognizer(script: TextRecognitionScript.latin);
  try {
    final input = InputImage.fromFilePath(usePath);
    return (await recognizer.processImage(input)).text;
  } catch (_) {
    return null;
  } finally {
    recognizer.close();
  }
}

/// Grayscale + naikkan kontras; kembalikan path file hasil (atau path
/// asli bila gagal).
Future<String> _enhanceContrast(String path) async {
  try {
    final bytes = await File(path).readAsBytes();
    final decoded = img.decodeImage(bytes);
    if (decoded == null) return path;
    final tuned = img.adjustColor(
      img.grayscale(decoded),
      contrast: 1.35,
      brightness: 0.05,
    );
    final out = File(
      '${Directory.systemTemp.path}/ocr_enh_${DateTime.now().millisecondsSinceEpoch}.jpg',
    );
    await out.writeAsBytes(img.encodeJpg(tuned, quality: 92));
    return out.path;
  } catch (_) {
    return path;
  }
}

/// Parse teks struk memakai parser heuristik utama ([parseReceipt])
/// yang sama dengan jalur scan lain: merchant diambil dari baris brand
/// (label "Sales No"/"Date"/"Cashier" tak pernah jadi judul), total =
/// Grand Total sesudah diskon (termasuk pola dua kolom label/angka
/// terpisah), tanggal menangkap jam struk. (Parser lokal lama di file
/// ini pensiun di batch 286 — persis tiga kegagalan itu yang ia buat.)
OcrDraft _parseOcr(String rawText) {
  final d = parseReceipt(rawText);
  var date = d.date ?? DateTime.now();
  final t = d.time;
  if (t != null) {
    final m = RegExp(r'^(\d{1,2}):(\d{2})').firstMatch(t);
    if (m != null) {
      final h = int.tryParse(m.group(1)!);
      final mi = int.tryParse(m.group(2)!);
      if (h != null && mi != null) {
        date = DateTime(date.year, date.month, date.day, h, mi);
      }
    }
  }
  final merchant = d.merchant?.trim();
  return OcrDraft(
    merchant: (merchant != null && merchant.isNotEmpty)
        ? merchant
        : tr('ocr_merchant_default'),
    amount: d.amount ?? 0,
    date: date,
    rawText: rawText,
  );
}
