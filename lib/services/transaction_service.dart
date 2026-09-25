import 'package:ssr_space/services/month.dart';
import 'package:ssr_space/services/supabase_config.dart';
import 'package:ssr_space/models/transaction.dart';

String _ymd(DateTime d) =>
    '${d.year.toString().padLeft(4, '0')}-'
    '${d.month.toString().padLeft(2, '0')}-'
    '${d.day.toString().padLeft(2, '0')}';

/// Payload INSERT transaksi. `date` tidak boleh null eksplisit:
/// kolom `date date not null default current_date` hanya apply bila key diomit.
Map<String, dynamic> txInsertPayload({
  required String orgId,
  required String type,
  required double amount,
  String? walletId,
  String? toWalletId,
  String? category,
  String? note,
  String? code,
  String? date,
  String? sourcePackage,
  String? sourceHash,
  String? createdBy,
  DateTime? now,
}) {
  return {
    'org_id': orgId,
    'type': type,
    'amount': amount,
    'wallet_id': walletId,
    'to_wallet_id': toWalletId,
    'category': category,
    'note': note,
    'code': code,
    'date': date ?? _ymd(now ?? DateTime.now()),
    'source_package': sourcePackage,
    'source_hash': sourceHash,
    'created_by': createdBy,
  };
}

/// Payload UPDATE. `date` null → key diomit (kolom tidak diubah, bukan di-NULL-kan).
Map<String, dynamic> txUpdatePayload({
  required String type,
  required double amount,
  String? walletId,
  String? toWalletId,
  String? category,
  String? note,
  String? date,
}) {
  final row = <String, dynamic>{
    'type': type,
    'amount': amount,
    'wallet_id': walletId,
    'to_wallet_id': toWalletId,
    'category': category,
    'note': note,
  };
  if (date != null) row['date'] = date;
  return row;
}

class TransactionService {
  Future<List<SaasTransaction>> list(String orgId) async {
    final rows = await SupabaseConfig.client
        .from('transactions')
        .select()
        .eq('org_id', orgId)
        .order('date', ascending: false)
        .order('created_at', ascending: false)
        .limit(100);
    return List<Map<String, dynamic>>.from(rows)
        .map(SaasTransaction.fromMap)
        .toList();
  }

  Future<List<SaasTransaction>> listMonth(String orgId, String month) async {
    final rows = await SupabaseConfig.client
        .from('transactions')
        .select()
        .eq('org_id', orgId)
        .gte('date', monthStart(month))
        .lt('date', monthEnd(month))
        .order('date', ascending: false)
        .order('created_at', ascending: false)
        .limit(200);
    return List<Map<String, dynamic>>.from(rows)
        .map(SaasTransaction.fromMap)
        .toList();
  }

  /// Semua transaksi yang menyentuh satu dompet (sumber atau tujuan
  /// transfer), terbaru dulu. Dasar layar riwayat per dompet.
  Future<List<SaasTransaction>> listByWallet(
    String orgId,
    String walletId,
  ) async {
    final rows = await SupabaseConfig.client
        .from('transactions')
        .select()
        .eq('org_id', orgId)
        .or('wallet_id.eq.$walletId,to_wallet_id.eq.$walletId')
        .order('date', ascending: false)
        .order('created_at', ascending: false)
        .limit(200);
    return List<Map<String, dynamic>>.from(rows)
        .map(SaasTransaction.fromMap)
        .toList();
  }

  Future<String> mintCode(String orgId) async {
    final res = await SupabaseConfig.client.rpc(
      'mint_tx_code',
      params: {'p_org_id': orgId},
    );
    return res.toString();
  }

  /// Insert dulu (code nullable), baru mint + update, supaya nomor TX tidak
  /// terbakar bila insert gagal (duplikat hash, RLS, dll).
  Future<String?> add({
    required String orgId,
    required String type,
    required double amount,
    String? walletId,
    String? toWalletId,
    String? category,
    String? note,
    String? code,
    String? date,
    String? sourcePackage,
    String? sourceHash,
  }) async {
    assert(amount > 0);
    final row = await SupabaseConfig.client
        .from('transactions')
        .insert(
          txInsertPayload(
            orgId: orgId,
            type: type,
            amount: amount,
            walletId: walletId,
            toWalletId: toWalletId,
            category: category,
            note: note,
            code: code,
            date: date,
            sourcePackage: sourcePackage,
            sourceHash: sourceHash,
            createdBy: SupabaseConfig.client.auth.currentUser?.id,
          ),
        )
        .select('id')
        .single();
    final id = row['id'].toString();
    if (code != null) return id;
    try {
      final minted = await mintCode(orgId);
      await SupabaseConfig.client
          .from('transactions')
          .update({'code': minted})
          .eq('id', id);
    } catch (_) {
      // kode nomor opsional, transaksi tetap tersimpan
    }
    return id;
  }

  Future<void> update({
    required String id,
    required String orgId,
    required String type,
    required double amount,
    String? walletId,
    String? toWalletId,
    String? category,
    String? note,
    String? date,
  }) async {
    assert(amount > 0);
    await SupabaseConfig.client
        .from('transactions')
        .update(
          txUpdatePayload(
            type: type,
            amount: amount,
            walletId: walletId,
            toWalletId: toWalletId,
            category: category,
            note: note,
            date: date,
          ),
        )
        .eq('id', id)
        .eq('org_id', orgId);
  }

  Future<void> delete(String id, String orgId) async {
    await SupabaseConfig.client
        .from('transactions')
        .delete()
        .eq('id', id)
        .eq('org_id', orgId);
  }
}
