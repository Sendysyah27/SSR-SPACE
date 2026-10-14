import 'dart:async';
import 'dart:io';

import 'package:google_mlkit_text_recognition/google_mlkit_text_recognition.dart';
import 'package:image_picker/image_picker.dart';
import 'package:path_provider/path_provider.dart';
import 'package:ssr_space/services/error_reporter.dart';
import 'package:ssr_space/services/receipt_kind.dart';
import 'package:ssr_space/services/receipt_layout.dart';
import 'package:ssr_space/services/receipt_parse.dart';

/// Gagal scan struk; [trKey] kunci strings (`rcp_fail` / `rcp_empty`).
/// [detail] pesan error asli (diagnostik, ditampilkan apa adanya).
class ReceiptScanException implements Exception {
  final String trKey;
  final String? detail;
  const ReceiptScanException(this.trKey, [this.detail]);
}

/// Teks OCR mentah dari scan terakhir (diagnosis di device saja).
/// Null bila scan gagal sebelum OCR. Hanya di memori, tak diupload.
String? lastRawOcrText;

/// OCR lokal dari bytes gambar (untuk chat AI saat provider vision
/// tak tersedia tapi Zen/OpenRouter aktif). Tulis temp file, baca
/// via ML Kit, hapus lagi. Tanpa upload. Butuh Android/iOS.
Future<String> ocrBytesToText(List<int> bytes) async {
  if (!Platform.isAndroid && !Platform.isIOS) {
    throw const ReceiptScanException('rcp_fail');
  }
  if (bytes.isEmpty) throw const ReceiptScanException('rcp_empty');
  final dir = await getTemporaryDirectory();
  final f = File(
      '${dir.path}/ai_ocr_${DateTime.now().millisecondsSinceEpoch}.jpg');
  try {
    await f.writeAsBytes(bytes);
    final recognizer = TextRecognizer(script: TextRecognitionScript.latin);
    try {
      final out = await recognizer.processImage(InputImage.fromFilePath(f.path));
      return out.text;
    } finally {
      await recognizer.close();
    }
  } finally {
    try {
      await f.delete();
    } catch (_) {}
  }
}

/// Foto struk (kamera/galeri) -> OCR on-device -> [ReceiptData].
/// Null bila user batal memilih. File foto dihapus setelah dibaca.
/// Tanpa upload ke mana pun; butuh Android/iOS (ML Kit tak ada di desktop).
Future<ReceiptData?> scanReceipt(ImageSource source) async {
  if (!Platform.isAndroid && !Platform.isIOS) {
    throw const ReceiptScanException('rcp_fail');
  }
  lastRawOcrText = null;
  final picker = ImagePicker();
  final shot = await picker.pickImage(
    source: source,
    maxWidth: 1600,
    imageQuality: 80,
  );
  if (shot == null) return null;
  final path = shot.path;
  try {
    // Jalur resmi untuk file statis; konversi byte manual hanya untuk
    // live-CameraImage, jangan dipakai lagi di sini.
    final input = InputImage.fromFilePath(path);
    final recognizer = TextRecognizer(script: TextRecognitionScript.latin);
    try {
      final out = await recognizer.processImage(input);
      // Susun spasial dari boundingBox bila ada (struk 2 kolom kembali
      // sebaris); tanpa geometri = teks datar. Null-safe: box null =
      // baris dilewati, bukan crash (riset: pola opensource + review !).
      final boxes = <OcrBox>[];
      try {
        for (final block in out.blocks) {
          for (final line in block.lines) {
            final text = line.text.trim();
            if (text.isEmpty) continue;
            final box = line.boundingBox;
            boxes.add(
              OcrBox(
                text,
                box.left.round(),
                box.top.round(),
                box.right.round(),
                box.bottom.round(),
              ),
            );
          }
        }
      } catch (_) {}
      final seen = boxes.isEmpty
          ? out.text
          : spatialLines(
              boxes,
              rowTol: layoutFor(detectReceiptKind(out.text)).rowTol,
            ).join('\n');
      lastRawOcrText = seen;
      if (seen.trim().isEmpty) {
        throw const ReceiptScanException('rcp_empty');
      }
      return parseReceipt(seen);
    } finally {
      await recognizer.close();
    }
  } catch (e, st) {
    if (e is ReceiptScanException) rethrow;
    unawaited(ErrorReporter.capture(e, st, context: 'receipt_scan'));
    var detail = e.toString();
    if (detail.length > 220) detail = detail.substring(0, 220);
    throw ReceiptScanException('rcp_fail', detail);
  } finally {
    try {
      await File(path).delete();
    } catch (_) {}
  }
}
