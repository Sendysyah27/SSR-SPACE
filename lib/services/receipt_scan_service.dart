import 'dart:async';
import 'dart:io';
import 'dart:typed_data';
import 'dart:ui' show Size;

import 'package:google_mlkit_commons/google_mlkit_commons.dart';
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

/// RGBA ketat -> NV21 (Y + VU subsampling 2x2). Murni, tanpa dep native.
Uint8List rgbaToNv21(Uint8List rgba, int width, int height) {
  final ySize = width * height;
  final out = Uint8List(ySize + ySize ~/ 2);
  var j = 0;
  for (var i = 0; i < rgba.length; i += 4, j++) {
    final y = ((66 * rgba[i] + 129 * rgba[i + 1] + 25 * rgba[i + 2] + 128) >> 8)
        + 16;
    out[j] = y.clamp(0, 255);
  }
  var uv = ySize;
  for (var y = 0; y < height; y += 2) {
    for (var x = 0; x < width; x += 2) {
      final i = (y * width + x) * 4;
      final r = rgba[i], g = rgba[i + 1], b = rgba[i + 2];
      final v = ((-38 * r - 74 * g + 112 * b + 128) >> 8) + 128;
      final u = ((112 * r - 94 * g - 18 * b + 128) >> 8) + 128;
      out[uv++] = v.clamp(0, 255);
      out[uv++] = u.clamp(0, 255);
    }
  }
  return out;
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
    // Jalur NV21 (bukan bitmap/file): cabang bitmap native menolak byte
    // di device ini; fromByteArray langsung tanpa BitmapFactory.
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
    if (img.width.isOdd || img.height.isOdd) {
      img = pkg_image.copyResize(
        img,
        width: img.width ~/ 2 * 2,
        height: img.height ~/ 2 * 2,
      );
    }
    final w = img.width;
    final h = img.height;
    final rgba = img.getBytes(order: pkg_image.ChannelOrder.rgba);
    final want = w * h * 4;
    if (rgba.length != want) {
      throw ReceiptScanException(
        'rcp_fail',
        'rgba ${rgba.length} vs $want',
      );
    }
    final input = InputImage.fromBytes(
      bytes: rgbaToNv21(rgba, w, h),
      metadata: InputImageMetadata(
        size: Size(w.toDouble(), h.toDouble()),
        rotation: InputImageRotation.rotation0deg,
        format: InputImageFormat.nv21,
        bytesPerRow: w,
      ),
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
