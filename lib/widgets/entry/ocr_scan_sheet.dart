import 'dart:io';

import 'package:flutter/material.dart';
import 'package:google_mlkit_text_recognition/google_mlkit_text_recognition.dart';
import 'package:image/image.dart' as img;
import 'package:image_picker/image_picker.dart';
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
    final XFile? file = await ImagePicker().pickImage(
      source: source,
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

/// Parse heuristik teks struk: total = angka terbesar di baris ber-keyword
/// (abaikan kembalian), tanggal multi-pola, merchant = baris pertama
/// yang bermakna.
OcrDraft _parseOcr(String rawText) {
  final lines = rawText.split('\n');

  double maxTotal = 0;
  const keywords = ['total', 'grand total', 'jumlah', 'bayar', 'tunai', 'cash'];
  for (final line in lines) {
    final lower = line.toLowerCase();
    if (lower.contains('kembalian') || lower.contains('change')) continue;
    if (!keywords.any(lower.contains)) continue;
    for (final m in RegExp(r'\d[\d.,]*').allMatches(line)) {
      final v = _parseIdr(m.group(0)!);
      if (v != null && v > maxTotal) maxTotal = v;
    }
  }

  DateTime date = DateTime.now();
  final dateMatch = RegExp(
    r'(\d{1,2})[\/\-.](\d{1,2})[\/\-.](\d{2,4})'
    r'|(\d{1,2})\s+(Jan|Feb|Mar|Apr|Mei|Jun|Jul|Agu|Sep|Okt|Nov|Des'
    r'|January|February|March|April|May|June|July|August|September'
    r'|October|November|December)\s+(\d{2,4})',
    caseSensitive: false,
  ).firstMatch(rawText);
  if (dateMatch != null) {
    final parsed = _parseDateMatch(dateMatch);
    if (parsed != null) date = parsed;
  }

  var merchant = tr('ocr_merchant_default');
  for (final line in lines) {
    final t = line.trim();
    if (t.isEmpty || t.length < 3 || t.length > 40) continue;
    if (RegExp(r'^[\d\s.,/\-:]+$').hasMatch(t)) continue;
    merchant = t;
    break;
  }

  return OcrDraft(
    merchant: merchant,
    amount: maxTotal,
    date: date,
    rawText: rawText,
  );
}

/// Parse angka format Indonesia: "26.900" -> 26900, "26.900,00" -> 26900.00.
/// Null bila bukan angka valid / di luar batas wajar.
double? _parseIdr(String s) {
  var t = s.replaceAll(RegExp(r'[^\d.,]'), '');
  if (t.isEmpty) return null;
  if (t.contains(',')) {
    // Gaya Indonesia: titik = ribuan, koma = desimal.
    t = t.replaceAll('.', '').replaceFirst(',', '.');
  } else {
    // Tanpa koma: titik diikuti tepat 3 digit di akhir = pemisah ribuan.
    final parts = t.split('.');
    if (parts.length > 1 && parts.last.length == 3) {
      t = parts.join('');
    }
  }
  final v = double.tryParse(t);
  if (v == null || v <= 0 || v > 1000000000) return null;
  return v;
}

DateTime? _parseDateMatch(RegExpMatch m) {
  try {
    if (m.group(1) != null) {
      final day = int.parse(m.group(1)!);
      final month = int.parse(m.group(2)!);
      var year = int.parse(m.group(3)!);
      if (year < 100) year += 2000;
      if (day >= 1 && day <= 31 && month >= 1 && month <= 12) {
        return DateTime(year, month, day);
      }
      return null;
    }
    final day = int.parse(m.group(4)!);
    var year = int.parse(m.group(6)!);
    if (year < 100) year += 2000;
    const months = {
      'jan': 1,
      'feb': 2,
      'mar': 3,
      'apr': 4,
      'mei': 5,
      'may': 5,
      'jun': 6,
      'jul': 7,
      'agu': 8,
      'aug': 8,
      'sep': 9,
      'okt': 10,
      'oct': 10,
      'nov': 11,
      'des': 12,
      'dec': 12,
      'january': 1,
      'february': 2,
      'march': 3,
      'april': 4,
      'june': 6,
      'july': 7,
      'august': 8,
      'september': 9,
      'october': 10,
      'november': 11,
      'december': 12,
    };
    final month = months[m.group(5)!.toLowerCase()];
    if (month != null && day >= 1 && day <= 31) {
      return DateTime(year, month, day);
    }
  } catch (_) {}
  return null;
}
