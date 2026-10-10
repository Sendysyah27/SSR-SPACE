import 'dart:io';

import 'package:ssr_space/services/backup_json.dart';
import 'package:ssr_space/services/export_files.dart';
import 'package:ssr_space/services/supabase_config.dart';
import 'package:ssr_space/services/transaction_service.dart';
import 'package:ssr_space/services/wallet_service.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

/// Hasil restore: hitung jujur per baris (ok/lewat/gagal + dompet dibuat).
class RestoreResult {
  final int walletsCreated;
  final int ok;
  final int skipped;
  final int failed;
  const RestoreResult({
    required this.walletsCreated,
    required this.ok,
    required this.skipped,
    required this.failed,
  });
}

/// Ambil seluruh data org untuk backup (cap tx 3000 baris).
Future<ParsedBackup> fetchBackup(String orgId, String orgName) async {
  final c = SupabaseConfig.client;
  final wallets = await c
      .from('wallets')
      .select()
      .eq('org_id', orgId)
      .order('created_at');
  final txs = await c
      .from('transactions')
      .select()
      .eq('org_id', orgId)
      .order('date')
      .limit(3000);
  final budgets = await c
      .from('budgets')
      .select()
      .eq('org_id', orgId)
      .order('month');
  return ParsedBackup(
    orgId: orgId,
    orgName: orgName,
    wallets: List<Map<String, dynamic>>.from(wallets),
    txs: List<Map<String, dynamic>>.from(txs),
    budgets: List<Map<String, dynamic>>.from(budgets),
  );
}

/// Simpan JSON ke Documents (izin ditolak = lempar [ExportNoPermission]).
Future<String> saveBackupFile(String fileName, String content) =>
    saveToDocuments(
      fileName: fileName,
      write: (p) async {
        final f = File(p);
        await f.writeAsString(content);
      },
    );


/// Rencana pratinjau sebelum pulihkan (tanpa tulis apa pun).
Future<RestorePlan> previewRestore(
  String orgId,
  ParsedBackup backup,
) async {
  final live = await WalletService().list(orgId);
  return planRestore(
    backupWallets: backup.wallets,
    backupTxs: backup.txs,
    liveWallets: [
      for (final w in live) {'id': w.id, 'name': w.name},
    ],
  );
}

/// Pulihkan backup ke org aktif: buat dompet hilang, insert transaksi
/// (kode baru dari server, tanpa hash auto). Butuh internet; gagal
/// koneksi = lempar (layar tampilkan error jujur, tanpa tulis parsial
/// diam-diam — hitungan ok/skip/gagal dilaporkan).
Future<RestoreResult> restoreBackup(
  String orgId,
  ParsedBackup backup,
) async {
  final live = await WalletService().list(orgId);
  final plan = planRestore(
    backupWallets: backup.wallets,
    backupTxs: backup.txs,
    liveWallets: [
      for (final w in live) {'id': w.id, 'name': w.name},
    ],
  );
  final nameToId = <String, String>{
    for (final w in live) w.name.trim().toLowerCase(): w.id,
  };
  var created = 0;
  for (final entry in plan.missingWallets.entries) {
    final id = await WalletService().create(orgId, entry.key, entry.value);
    nameToId[entry.key.trim().toLowerCase()] = id;
    created++;
  }
  var ok = 0;
  var skipped = plan.skipped;
  var failed = 0;
  for (final r in plan.ready) {
    final wid = nameToId[(r['wallet_name'] ?? '').toString().toLowerCase()];
    final toName = (r['to_wallet_name'] ?? '').toString();
    final toId = toName.isEmpty
        ? null
        : nameToId[toName.toLowerCase()];
    if (wid == null || wid.isEmpty) {
      skipped++;
      continue;
    }
    if ((r['type'] ?? '') == 'transfer' && (toId == null || toId.isEmpty)) {
      skipped++;
      continue;
    }
    final date = (r['date'] ?? '').toString();
    final createdAt = (r['created_at'] ?? '').toString();
    final cat = (r['category'] ?? '').toString();
    final note = (r['note'] ?? '').toString();
    try {
      await TransactionService().add(
        orgId: orgId,
        type: (r['type'] ?? '').toString(),
        amount: (r['amount'] as num?)?.toDouble() ?? 0,
        walletId: wid,
        toWalletId: toId,
        category: cat.isEmpty ? null : cat,
        note: note.isEmpty ? null : note,
        date: date.isEmpty ? null : date,
        createdAt: createdAt.isEmpty ? null : createdAt,
      );
      ok++;
    } on PostgrestException catch (e) {
      // Duplikat hash = baris sudah ada → lewati, bukan gagal.
      if (e.code == '23505') {
        skipped++;
      } else {
        failed++;
      }
    } catch (_) {
      failed++;
    }
  }
  return RestoreResult(
    walletsCreated: created,
    ok: ok,
    skipped: skipped,
    failed: failed,
  );
}
