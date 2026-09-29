import 'dart:async';
import 'dart:io';

import 'package:google_mlkit_text_recognition/google_mlkit_text_recognition.dart';
import 'package:image/image.dart' as pkg_image;
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
    // Decode murni Dart: byte RGBA dijamin ketat w*h*4 (toByteData Skia
    // bisa ber-padding stride hingga native menolak). EXIF diputar otomatis.
    final bytes = await File(path).readAsBytes();
    final decoded = pkg_image.decodeImage(bytes);
    if (decoded == null) {
      throw const ReceiptScanException('rcp_fail', 'decode null');
    }
    var img = decoded;
    if (img.width > 1600 || img.height > 1600) {
      img = pkg_image.copyResize(
        img,
        width: img.width >= img.height ? 1600 : null,
        height: img.width >= img.height ? null : 1600,
      );
    }
    final rgba = img.getBytes(order: pkg_image.ChannelOrder.rgba);
    final want = img.width * img.height * 4;
    if (rgba.length != want) {
      throw ReceiptScanException(
        'rcp_fail',
        'stride ${rgba.length} vs $want',
      );
    }
    final input = InputImage.fromBitmap(
      bitmap: rgba,
      width: img.width,
      height: img.height,
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
