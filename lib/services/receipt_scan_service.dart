import 'dart:async';
import 'dart:io';
import 'dart:ui' as ui;

import 'package:google_mlkit_text_recognition/google_mlkit_text_recognition.dart';
import 'package:image_picker/image_picker.dart';
import 'package:ssr_space/services/error_reporter.dart';
import 'package:ssr_space/services/receipt_parse.dart';

/// Gagal scan struk; [trKey] kunci strings (`rcp_fail` / `rcp_empty`).
/// [detail] pesan error asli (diagnostik, ditampilkan apa adanya).
class ReceiptScanException implements Exception {
  final String trKey;
  final String? detail;
  const ReceiptScanException(this.trKey, [this.detail]);
}

/// Foto struk (kamera/galeri) -> OCR on-device -> [ReceiptData].
/// Null bila user batal memilih. File foto dihapus setelah dibaca.
/// Tanpa upload ke mana pun; butuh Android/iOS (ML Kit tak ada di desktop).
Future<ReceiptData?> scanReceipt(ImageSource source) async {
  if (!Platform.isAndroid && !Platform.isIOS) {
    throw const ReceiptScanException('rcp_fail');
  }
  final picker = ImagePicker();
  final shot = await picker.pickImage(
    source: source,
    maxWidth: 1600,
    imageQuality: 80,
  );
  if (shot == null) return null;
  final path = shot.path;
  try {
    // Jalur bitmap (bukan fromFilePath): fromFilePath NPE di native
    // untuk file picker tertentu (tak bisa buka/EXIF), hanya catch
    // IOException. Decode di Dart terbukti bisa/tidak dengan pesan jelas.
    final bytes = await File(path).readAsBytes();
    final ui.Codec codec = await ui.instantiateImageCodec(bytes);
    final ui.FrameInfo frame = await codec.getNextFrame();
    final ui.Image image = frame.image;
    final byteData =
        await image.toByteData(format: ui.ImageByteFormat.rawRgba);
    final w = image.width;
    final h = image.height;
    image.dispose();
    if (byteData == null) {
      throw const ReceiptScanException(
        'rcp_fail',
        'decode kosong',
      );
    }
    final input = InputImage.fromBitmap(
      bitmap: byteData.buffer.asUint8List(
        byteData.offsetInBytes,
        byteData.lengthInBytes,
      ),
      width: w,
      height: h,
    );
    final recognizer = TextRecognizer(script: TextRecognitionScript.latin);
    try {
      final out = await recognizer.processImage(input);
      if (out.text.trim().isEmpty) {
        throw const ReceiptScanException('rcp_empty');
      }
      return parseReceipt(out.text);
    } finally {
      await recognizer.close();
    }
  } catch (e, st) {
    if (e is ReceiptScanException) rethrow;
    // Diagnostik Fase 1: kirim pesan asli ke client_errors + teruskan
    // ringkasnya ke UI agar akar terlihat di device.
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
