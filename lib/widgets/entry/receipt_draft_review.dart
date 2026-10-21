import 'dart:async';

import 'package:flutter/material.dart';

import 'package:ssr_space/screens/lainnya/ai_draft_screen.dart';
import 'package:ssr_space/services/ai_draft.dart';
import 'package:ssr_space/services/receipt_parse.dart';
import 'package:ssr_space/services/scan_draft_store.dart';

/// Hasil review draft scan (batch 286 tahap C).
class ScanReviewOutcome {
  /// Data final yang disetujui user; null = tidak dipakai.
  final ReceiptData? data;

  /// True bila user memilih "Simpan draft" (transaksi tidak dibuat;
  /// pemanggil cukup menampilkan konfirmasi).
  final bool savedDraft;

  const ScanReviewOutcome({this.data, this.savedDraft = false});
}

/// Buka review terstruktur ala Ollo ([AiDraftScreen]) untuk hasil scan
/// apa pun — OCR lokal maupun scan AI — supaya semua jalur bermuara
/// ke review yang sama sebelum jadi transaksi.
///
/// [existingDraftId]: bila review dibuka dari daftar draft tersimpan,
/// tombol Simpan Draft menimpa entri itu, Buang menghapusnya, dan
/// draft yang dipakai sampai jadi transaksi ikut terhapus (selesai).
Future<ScanReviewOutcome> reviewScanDraft(
  BuildContext context,
  ReceiptData data, {
  String? existingDraftId,
}) async {
  var saved = false;
  final store = ScanDraftStore();
  final edited = await Navigator.of(context).push<ReceiptData>(
    MaterialPageRoute(
      builder: (_) => AiDraftScreen(
        initial: AiDraft.fromReceiptData(data),
        carry: data,
        onSaveDraft: (draft) async {
          if (existingDraftId != null) {
            await store.update(existingDraftId, draft);
          } else {
            await store.add(draft);
          }
          saved = true;
        },
        onDiscard: existingDraftId == null
            ? null
            : () => unawaited(store.remove(existingDraftId)),
      ),
    ),
  );
  if (edited != null) {
    if (existingDraftId != null) {
      await store.remove(existingDraftId);
    }
    return ScanReviewOutcome(data: edited);
  }
  return ScanReviewOutcome(savedDraft: saved);
}
