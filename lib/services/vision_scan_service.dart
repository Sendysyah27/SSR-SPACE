import 'dart:async';
import 'dart:io';

import 'package:image_picker/image_picker.dart';
import 'package:ssr_space/services/ai_quota.dart';
import 'package:ssr_space/services/ai_pii.dart';
import 'package:ssr_space/services/ai_cli_client.dart';
import 'package:ssr_space/services/ai_server_client.dart';
import 'package:ssr_space/services/app_categories.dart';
import 'package:ssr_space/services/receipt_scan_service.dart';
import 'package:ssr_space/services/error_reporter.dart';
import 'package:ssr_space/services/receipt_currency.dart';
import 'package:ssr_space/services/receipt_parse.dart';
import 'package:ssr_space/services/receipt_scan_parse.dart';
import 'package:ssr_space/services/firebase_ai_parser.dart';
import 'package:ssr_space/utils/org_prefs.dart';

export 'package:image_picker/image_picker.dart' show ImageSource;

/// Gagal scan vision; [trKey] kunci strings, [detail] diagnostik.
class VisionScanException implements Exception {
  final String trKey;
  final String? detail;
  const VisionScanException(this.trKey, [this.detail]);
}

/// Foto struk (kamera/galeri) -> Mang AI SERVER vision langsung
/// (model VL via Edge Function mang-ai-chat), TANPA OCR.
/// Gagal vision -> OCR lokal -> Mang AI server (teks), KECUALI [strictVision]
/// true (mode "AI Vision" eksplisit pilihan user): tanpa fallback diam-diam,
/// error vision dilempar apa adanya agar user tahu mode yang dipakai gagal.
/// File foto dihapus. Null = user batal.
/// Return [ReceiptData] + nama provider + kategori AI (untuk prefill form).
/// Hasil HANYA mengisi form; tidak ada simpan otomatis.
Future<({ReceiptData data, String provider, String? category})?> scanReceiptVision(
  ImageSource source, {
  bool strictVision = false,
}) async {
  if (!Platform.isAndroid && !Platform.isIOS) {
    throw const VisionScanException('rcp_fail');
  }
  final picker = ImagePicker();
  // Kecilkan dulu: sisi terpanjang ~1280px, JPEG kualitas 80
  // (cepat + hemat token, tanpa dependency baru).
  final shot = await picker.pickImage(
    source: source,
    maxWidth: 1280,
    maxHeight: 1280,
    imageQuality: 80,
  );
  if (shot == null) return null;
  final path = shot.path;
  try {
    final bytes = await File(path).readAsBytes();
    if (bytes.isEmpty) throw const VisionScanException('rcp_empty');
    final mime = path.toLowerCase().endsWith('.png')
        ? 'image/png'
        : 'image/jpeg';

    final categories = appCategories.value;
    final system = scanReceiptSystemPrompt(categories);

    // Gate kuota AI (entitlement Fase 1) HANYA untuk jalur AI
    // (vision langsung + OCR->AI di bawah). OCR on-device
    // (ocrBytesToText) tetap gratis tanpa batas; bila kuota mentok,
    // lempar sebelum model dipanggil (pemanggil petakan ke paywall).
    // Fail-open: server diam -> lolos.
    final orgId = await activeOrgId();
    if (orgId.isNotEmpty && !await aiAllowed(orgId)) {
      throw const VisionScanException('q_ai_exceeded');
    }

    ReceiptScanResult? scanned;
    String? lastDetail;
    // Teks mentah terakhir (balasan model / OCR) — bahan deteksi mata
    // uang asing tahap B.
    var lastRaw = '';
    var usedProvider = serverProviderName;

    // 1) Vision langsung via Mang AI server (model VL).
    try {
      final r = await aiChatViaCli(
        'Uraikan struk pada gambar terlampir.',
        imageBytes: bytes,
        mimeType: mime,
        system: system,
        forceLocal: true,
        kind: 'receipt',
        // Struk 43 item -> JSON ribuan token; 30 dtk terlalu sempit.
        timeout: visionScanTimeout,
      );
      usedProvider = r.provider;
      lastRaw = r.text;
      // Format baris teks dulu (robust utk banyak item); fallback JSON lama.
      scanned = parseReceiptScanText(_stripFence(r.text), categories) ??
          parseReceiptScanJson(_stripFence(r.text), categories);
      if (scanned == null) {
        lastDetail = 'AI tidak mengembalikan data struk yang valid.';
      }
    } on AiFailure catch (e) {
      lastDetail = (e.detail ?? e.code).trim();
    } catch (e) {
      lastDetail = _snip(e.toString());
    }

    // 2) OCR lokal -> Mang AI server (teks), untuk model yang buta gambar.
    // Dilewati bila strictVision: user memilih "AI Vision" eksplisit, jadi
    // kegagalan vision dilaporkan jujur tanpa pindah mode diam-diam.
    if (scanned == null && !strictVision) {
      try {
        final ocr = await ocrBytesToText(bytes);
        if (ocr.trim().isNotEmpty) {
          final r = await aiChatViaCli(
            // Batch 281D tahap 4: teks OCR dimasking dulu
            // (nomor kartu di struk); nominal struk tak tersentuh pola.
            scanReceiptOcrPrompt(maskPii(ocr), categories),
            system: system,
            forceLocal: true,
            kind: 'receipt',
          );
          usedProvider = r.provider;
          lastRaw = '$ocr\n${r.text}';
          scanned = parseReceiptScanText(_stripFence(r.text), categories) ??
              parseReceiptScanJson(_stripFence(r.text), categories);
          if (scanned == null) {
            lastDetail = 'AI tidak mengembalikan data struk yang valid.';
          }
        }
      } on AiFailure catch (e) {
        lastDetail = (e.detail ?? e.code).trim();
      } catch (e) {
        lastDetail = _snip(e.toString());
      }
    }

    if (scanned == null) {
      throw VisionScanException(
          'rcp_fail', (lastDetail ?? 'Struk tak terbaca.').trim());
    }
    // Sukses AI -> catat satu pemakaian kuota (fail-silent).
    if (orgId.isNotEmpty) unawaited(recordAiUse(orgId, 'receipt'));
    final s = scanned;
    // Batch 284 tahap B: deteksi mata uang asing dari teks mentah;
    // konversi ke IDR dikerjakan pemanggil (applyFxConversion) agar
    // kurs + hasil konversi tampil di sheet review.
    final fxCode = detectReceiptCurrency(lastRaw);
    // Teks detail gaya struk -> disimpan sebagai catatan transaksi
    // (terlihat lengkap di detail transaksi).
    final detailText = receiptDetailText(s);
    // Petakan item vision -> lineItems agar ReceiptResultSheet menampilkan
    // replika struk lengkap (nama + qty + harga per baris).
    final lineItems = <ReceiptItem>[
      for (final it in s.items)
        ReceiptItem(
          name: it.name,
          qty: it.qty,
          price: it.price.toDouble(),
          suspicious: it.price > s.total,
        ),
    ];
    return (
      data: ReceiptData(
        amount: s.total.toDouble(),
        date: DateTime.tryParse(s.date),
        merchant: s.merchant,
        items: [for (final it in s.items) it.name],
        lineItems: lineItems,
        confident: true,
        detailText: detailText,
        fxCurrency: fxCode,
        fxOriginal: fxCode == null ? null : s.total.toDouble(),
      ),
      provider: usedProvider,
      category: s.category,
    );
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

String _snip(String s, [int max = 220]) =>
    s.length <= max ? s : s.substring(0, max);
