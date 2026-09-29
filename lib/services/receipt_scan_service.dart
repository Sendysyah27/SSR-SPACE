import 'dart:io';

import 'package:google_mlkit_text_recognition/google_mlkit_text_recognition.dart';
import 'package:image_picker/image_picker.dart';
import 'package:ssr_space/services/receipt_parse.dart';

/// Gagal scan struk; [trKey] kunci strings (`rcp_fail` / `rcp_empty`).
class ReceiptScanException implements Exception {
  final String trKey;
  const ReceiptScanException(this.trKey);
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
    final recognizer = TextRecognizer(script: RecognisedScript.latin);
    try {
      final out = await recognizer.processImage(
        InputImage.fromFilePath(path),
      );
      if (out.text.trim().isEmpty) {
        throw const ReceiptScanException('rcp_empty');
      }
      return parseReceipt(out.text);
    } finally {
      await recognizer.close();
    }
  } catch (e) {
    if (e is ReceiptScanException) rethrow;
    throw const ReceiptScanException('rcp_fail');
  } finally {
    try {
      await File(path).delete();
    } catch (_) {}
  }
}
