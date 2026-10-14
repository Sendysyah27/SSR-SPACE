import 'dart:async';
import 'dart:io';

import 'package:image_picker/image_picker.dart';
import 'package:ssr_space/services/ai_key_store.dart';
import 'package:ssr_space/services/error_reporter.dart';
import 'package:ssr_space/services/error_reporter.dart';
import 'package:ssr_space/services/firebase_ai_factory.dart';
import 'package:ssr_space/services/firebase_ai_parser.dart';
import 'package:ssr_space/services/receipt_parse.dart';
import 'ai_draft.dart';

export 'package:image_picker/image_picker.dart' show ImageSource;

/// Gagal scan vision; [trKey] kunci strings, [detail] diagnostik.
class VisionScanException implements Exception {
  final String trKey;
  final String? detail;
  const VisionScanException(this.trKey, [this.detail]);
}

/// Foto struk (kamera/galeri) -> model VISION langsung, TANPA OCR.
/// Syarat: kunci Gemini (multimodal) atau login Firebase. Provider
/// text-only (OpenRouter/Zen) dilewati jujur. File foto dihapus.
/// Null = user batal. Return [ReceiptData] + nama provider pemenang.
Future<({ReceiptData data, String provider})?> scanReceiptVision(
  ImageSource source,
) async {
  if (!Platform.isAndroid && !Platform.isIOS) {
    throw const VisionScanException('rcp_fail');
  }
  final picker = ImagePicker();
  final shot = await picker.pickImage(
    source: source,
    maxWidth: 1600,
    imageQuality: 85,
  );
  if (shot == null) return null;
  final path = shot.path;
  try {
    final bytes = await File(path).readAsBytes();
    if (bytes.isEmpty) throw const VisionScanException('rcp_empty');
    final mime = path.toLowerCase().endsWith('.png')
        ? 'image/png'
        : 'image/jpeg';
    String? text;
    String provider = '';
    AiFailure? last;
    // 1) Gemini key (multimodal penuh).
    if (await aiProviderOn(aiProvGemini)) {
      final k = await readGeminiKey();
      if (k != null) {
        try {
          String? used;
          text = await restGenerate(aiVisionPrompt(),
                  apiKey: k,
                  onModel: (m) => used = m,
                  imageBytes: bytes,
                  mimeType: mime)
              .timeout(const Duration(seconds: 90));
          provider = 'Gemini${used == null ? '' : ': $used'}';
        } on AiFailure catch (e) {
          last = e;
          if (e.code == 'quota') unawaited(noteQuotaHit());
        } catch (e) {
          last = AiFailure('network', '[Gemini] $e');
        }
      }
    }
    // 2) Firebase login (multimodal SDK).
    if ((text == null || text.trim().isEmpty) &&
        await aiProviderOn(aiProvFb)) {
      try {
        text = await firebaseVisionAsk(
          bytes: bytes,
          prompt: aiVisionPrompt(),
          mimeType: mime,
        );
        if (text != null && text.trim().isNotEmpty) {
          provider = 'Firebase';
        }
      } on AiFailure catch (e) {
        last = e;
        if (e.code == 'quota') unawaited(noteQuotaHit());
      } catch (e) {
        last = AiFailure('network', '$e');
      }
    }
    if (text == null || text.trim().isEmpty) {
      final e = last;
      if (e != null && e.code == 'quota') {
        throw AiFailure('quota', e.detail);
      }
      if (e != null) {
        throw VisionScanException(
            'rcp_fail', '(${e.code}) ${e.detail ?? ''}'.trim());
      }
      throw const VisionScanException(
          'rcp_fail', '(butuh kunci Gemini / login Firebase)');
    }
    final draft = parseAiDraft(_stripFence(text));
    if (draft == null) {
      throw const VisionScanException('rcp_partial');
    }
    return (data: draft.toReceiptData(), provider: provider);
  } catch (e, st) {
    if (e is VisionScanException || e is AiFailure) rethrow;
    unawaited(ErrorReporter.capture(e, st, context: 'vision_scan'));
    var detail = e.toString();
    if (detail.length > 220) detail = detail.substring(0, 220);
    throw VisionScanException('rcp_fail', detail);
  } finally {
    try {
      await File(path).delete();
    } catch (_) {}
  }
}

/// Buang pagar markdown bila model membungkus JSON.
String _stripFence(String s) {
  var t = s.trim();
  t = t.replaceAll(RegExp(r'^```(json)?\s*'), '');
  t = t.replaceAll(RegExp(r'\s*```$'), '');
  return t;
}
