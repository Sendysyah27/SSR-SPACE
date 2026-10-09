import 'package:ssr_space/services/month.dart';
import 'package:ssr_space/services/space_service.dart';
import 'package:ssr_space/services/supabase_config.dart';
import 'package:ssr_space/models/transaction.dart';
import 'package:ssr_space/utils/strings.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

String _ymd(DateTime d) =>
    '${d.year.toString().padLeft(4, '0')}-'
    '${d.month.toString().padLeft(2, '0')}-'
    '${d.day.toString().padLeft(2, '0')}';

/// Payload INSERT transaksi. `date` tidak boleh null eksplisit:
/// kolom `date date not null default current_date` hanya apply bila key diomit.
/// `createdAt` opsional (ISO 'YYYY-MM-DDTHH:MM:SS'): diisi hanya bila user
/// memilih jam di sheet input; null berarti kolom diomit (server pakai now()).
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
  String? createdAt,
  String? sourcePackage,
  String? sourceHash,
  String? createdBy,
  DateTime? now,
}) {
  final row = <String, dynamic>{
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
  if (createdAt != null) row['created_at'] = createdAt;
  return row;
}

/// Payload UPDATE. `date`/`createdAt` null → key diomit (kolom tidak diubah,
/// bukan di-NULL-kan).
Map<String, dynamic> txUpdatePayload({
  required String type,
  required double amount,
  String? walletId,
  String? toWalletId,
  String? category,
  String? note,
  String? date,
  String? createdAt,
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
  if (createdAt != null) row['created_at'] = createdAt;
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

  /// Tanggal-tanggal terbaru saja (kolom date, tanpa nominal).
  /// Dasar streak harian: ringan, tanpa nominal, tanpa upload tambahan.
  Future<List<DateTime>> listDates(String orgId, {int limit = 120}) async {
    final rows = await SupabaseConfig.client
        .from('transactions')
        .select('date')
        .eq('org_id', orgId)
        .order('date', ascending: false)
        .limit(limit);
    return [
      for (final r in List<Map<String, dynamic>>.from(rows))
        DateTime.tryParse((r['date'] ?? '').toString()),
    ].whereType<DateTime>().toList();
  }

  /// Rentang tanggal (untuk insight mingguan). Fail-open di pemanggil:
  /// gagal = kartu sembunyi, bukan error.
  Future<List<SaasTransaction>> listRange(
    String orgId,
    String startYmd,
    String endYmd, {
    int limit = 300,
  }) async {
    final rows = await SupabaseConfig.client
        .from('transactions')
        .select()
        .eq('org_id', orgId)
        .gte('date', startYmd)
        .lt('date', endYmd)
        .order('date', ascending: false)
        .limit(limit);
    return List<Map<String, dynamic>>.from(rows)
        .map(SaasTransaction.fromMap)
        .toList();
  }

  /// Jendela terbaru (untuk auto-gabung transfer): tanpa filter bulan,
  /// dibatasi 100 baris. Dasar `_tryAutoMerge` — bukan untuk UI.
  Future<List<SaasTransaction>> listSince(String orgId, DateTime since) async {
    final rows = await SupabaseConfig.client
        .from('transactions')
        .select()
        .eq('org_id', orgId)
        .gte('created_at', since.toUtc().toIso8601String())
        .order('created_at', ascending: false)
        .limit(100);
    return List<Map<String, dynamic>>.from(rows)
        .map(SaasTransaction.fromMap)
        .toList();
  }

  /// Satu transaksi by id (untuk sheet koreksi instan). Null bila tak ada.
  Future<SaasTransaction?> getById(String orgId, String id) async {
    final row = await SupabaseConfig.client
        .from('transactions')
        .select()
        .eq('org_id', orgId)
        .eq('id', id)
        .maybeSingle();
    if (row == null) return null;
    return SaasTransaction.fromMap(Map<String, dynamic>.from(row));
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
    String? createdAt,
    String? sourcePackage,
    String? sourceHash,
  }) async {
    assert(amount > 0);
    Map<String, dynamic> row;
    try {
      row = await SupabaseConfig.client
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
              createdAt: createdAt,
              sourcePackage: sourcePackage,
              sourceHash: sourceHash,
              createdBy: SupabaseConfig.client.auth.currentUser?.id,
            ),
          )
          .select('id')
          .single();
    } on PostgrestException catch (e) {
      // Mode bendahara: member ditolak RLS (bukan error teknis).
      if (e.code == '42501') throw SpaceException(tr('sp_only_treasurer'));
      rethrow;
    }
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
    String? createdAt,
  }) async {
    assert(amount > 0);
    try {
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
              createdAt: createdAt,
            ),
          )
          .eq('id', id)
          .eq('org_id', orgId);
    } on PostgrestException catch (e) {
      if (e.code == '42501') throw SpaceException(tr('sp_only_treasurer'));
      rethrow;
    }
  }

  Future<void> delete(String id, String orgId) async {
    try {
      await SupabaseConfig.client
          .from('transactions')
          .delete()
          .eq('id', id)
          .eq('org_id', orgId);
    } on PostgrestException catch (e) {
      if (e.code == '42501') throw SpaceException(tr('sp_only_treasurer'));
      rethrow;
    }
  }
}
