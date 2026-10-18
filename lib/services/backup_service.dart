import 'dart:io';

import 'package:ssr_space/services/backup_json.dart';
import 'package:ssr_space/services/export_files.dart';
import 'package:ssr_space/services/supabase_config.dart';
import 'package:ssr_space/services/pg_trigger_codes.dart';
import 'package:ssr_space/services/transaction_service.dart';
import 'package:ssr_space/services/wallet_service.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

/// Hasil restore: hitung jujur per baris (ok/lewat/gagal + dompet dibuat
/// + tertahan kuota). quotaBlocked = baris yang ditolak trigger
/// QUOTA_EXCEEDED (paket Gratis penuh) — bukan "gagal" generik.
class RestoreResult {
  final int walletsCreated;
  final int ok;
  final int skipped;
  final int failed;
  final int quotaBlocked;
  const RestoreResult({
    required this.walletsCreated,
    required this.ok,
    required this.skipped,
    required this.failed,
    this.quotaBlocked = 0,
  });
}

/// Ambil seluruh data org untuk backup (cap = backupExportTxCap, sama
/// dengan restoreTxCap agar backup selalu bisa di-restore utuh).
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
      .limit(backupExportTxCap);
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
  var quotaBlocked = 0;
  for (final entry in plan.missingWallets.entries) {
    try {
      final id = await WalletService().create(orgId, entry.key, entry.value);
      nameToId[entry.key.trim().toLowerCase()] = id;
      created++;
    } on QuotaExceededException {
      // Dompet Gratis penuh: catat jujur, lanjutkan sisa rencana
      // (transaksi yang butuh dompet ini jadi skipped di bawah).
      quotaBlocked++;
    } on PostgrestException catch (e) {
      if (pgIsQuotaExceeded(e)) {
        quotaBlocked++;
      } else {
        rethrow;
      }
    }
  }
  var ok = 0;
  var skipped = plan.skipped;
  var failed = 0;
  // Fix #6: bulk restore. Dulu tiap baris = INSERT + mint RPC + UPDATE
  // (3 round-trip serial via add()); 1000 baris = ~3000 request, belasan
  // menit di jaringan lemot. Sekarang: kode di-mint dulu (RPC ringan),
  // lalu SATU bulk insert per 200 baris. Chunk yang gagal (mis. 23505)
  // difallback ke insert satuan agar hitungan tetap jujur per baris.
  final payloads = <Map<String, dynamic>>[];
  final uid = SupabaseConfig.client.auth.currentUser?.id;
  for (final r in plan.ready) {
    final wid = nameToId[(r['wallet_name'] ?? '').toString().toLowerCase()];
    final toName = (r['to_wallet_name'] ?? '').toString();
    final toId = toName.isEmpty ? null : nameToId[toName.toLowerCase()];
    if (wid == null || wid.isEmpty) {
      skipped++;
      continue;
    }
    if ((r['type'] ?? '') == 'transfer' && (toId == null || toId.isEmpty)) {
      skipped++;
      continue;
    }
    final amount = (r['amount'] as num?)?.toDouble() ?? 0;
    if (amount <= 0) {
      failed++; // add() melempar ArgumentError untuk nominal ini
      continue;
    }
    final date = (r['date'] ?? '').toString();
    final createdAt = (r['created_at'] ?? '').toString();
    final cat = (r['category'] ?? '').toString();
    final note = (r['note'] ?? '').toString();
    payloads.add(txInsertPayload(
      orgId: orgId,
      type: (r['type'] ?? '').toString(),
      amount: amount,
      walletId: wid,
      toWalletId: toId,
      category: cat.isEmpty ? null : cat,
      note: note.isEmpty ? null : note,
      date: date.isEmpty ? null : date,
      createdAt: createdAt.isEmpty ? null : createdAt,
      createdBy: uid,
    ));
  }
  // Mint kode upfront (tanpa UPDATE per baris seperti add()).
  final svc = TransactionService();
  for (final pl in payloads) {
    try {
      pl['code'] = await svc.mintCode(orgId);
    } catch (_) {
      // Kode opsional: baris tetap di-restore tanpa kode (semantik add()).
    }
  }
  const chunkSize = 200;
  for (var i = 0; i < payloads.length; i += chunkSize) {
    final end = (i + chunkSize).clamp(0, payloads.length);
    final chunk = payloads.sublist(i, end);
    try {
      await SupabaseConfig.client.from('transactions').insert(chunk);
      ok += chunk.length;
    } on PostgrestException catch (e) {
      if (e.code == '23505' || pgIsQuotaExceeded(e)) {
        for (final pl in chunk) {
          try {
            await SupabaseConfig.client.from('transactions').insert(pl);
            ok++;
          } on PostgrestException catch (re) {
            // Duplikat hash = baris sudah ada → lewati, bukan gagal.
            // QUOTA = tertahan kuota paket → hitung jujur, bukan gagal generik.
            if (re.code == '23505') {
              skipped++;
            } else if (pgIsQuotaExceeded(re)) {
              quotaBlocked++;
            } else {
              failed++;
            }
          } catch (_) {
            failed++;
          }
        }
      } else {
        failed += chunk.length;
      }
    } catch (_) {
      failed += chunk.length;
    }
  }
    walletsCreated: created,
    ok: ok,
    skipped: skipped,
    failed: failed,
    quotaBlocked: quotaBlocked,
  );
}
