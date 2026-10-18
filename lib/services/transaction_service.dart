import 'dart:async';

import 'package:flutter/foundation.dart';

import 'package:ssr_space/services/month.dart';
import 'package:ssr_space/services/month_figures.dart';
import 'package:ssr_space/services/offline_cache.dart';
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

/// Ukuran halaman riwayat (Batch 2 Sprint). Satu order deterministik
/// (date DESC, created_at DESC) dipakai semua halaman supaya tak loncat.
const txPageSize = 100;

/// True bila kemungkinan masih ada halaman berikut (yang datang penuh).
/// Murni Dart — dasar infinite scroll, bisa di-test tanpa backend.
bool txPageHasMore(int fetched, int limit) => fetched >= limit;

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
        .map(SaasTransaction.tryFromMap).whereType<SaasTransaction>()
        .toList();
  }

  Future<List<SaasTransaction>> listMonth(String orgId, String month) async {
    try {
      final rows = await SupabaseConfig.client
          .from('transactions')
          .select()
          .eq('org_id', orgId)
          .gte('date', monthStart(month))
          .lt('date', monthEnd(month))
          .order('date', ascending: false)
          .order('created_at', ascending: false)
          .limit(200);
      markOnline();
      unawaited(writeTxCache(orgId, month, List<dynamic>.from(rows)));
      return List<Map<String, dynamic>>.from(rows)
          .map(SaasTransaction.tryFromMap).whereType<SaasTransaction>()
          .toList();
    } catch (e) {
      // Offline: sodorkan cache terakhir; tanpa cache = lempar asli.
      if (!isNetworkError(e)) rethrow;
      markOffline();
      final cached = await readTxCache(orgId, month);
      if (cached != null) {
        return cached.map(SaasTransaction.tryFromMap).whereType<SaasTransaction>().toList();
      }
      rethrow;
    }
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
        .map(SaasTransaction.tryFromMap).whereType<SaasTransaction>()
        .toList();
  }

  /// Satu halaman bulan berjalan (untuk infinite scroll).
  ///
  /// Keyset pagination via [after] (fix #9): offset `.range()` rawan drift —
  /// insert baru saat scroll menggeser baris sehingga duplikat/terlewat.
  /// Kursor = item terakhir halaman sebelumnya; order (date, created_at, id)
  /// DESC dengan id sebagai tiebreaker deterministik.
  Future<List<SaasTransaction>> listMonthPage(
    String orgId,
    String month, {
    SaasTransaction? after,
    int limit = txPageSize,
  }) async {
    try {
      var q = SupabaseConfig.client
          .from('transactions')
          .select()
          .eq('org_id', orgId)
          .gte('date', monthStart(month))
          .lt('date', monthEnd(month));
      final ad = after?.date;
      final ac = after?.createdAt;
      if (after != null && ad != null && ac != null) {
        // Baris SETELAH kursor dalam order DESC.
        q = q.or('date.lt.$ad,'
            'and(date.eq.$ad,created_at.lt.$ac),'
            'and(date.eq.$ad,created_at.eq.$ac,id.lt.${after.id})');
      }
      final rows = await q
          .order('date', ascending: false)
          .order('created_at', ascending: false)
          .order('id', ascending: false)
          .limit(limit);
      markOnline();
      // Cache hanya halaman pertama (tampilan awal offline).
      if (after == null) {
        unawaited(writeTxCache(orgId, month, List<dynamic>.from(rows)));
      }
      return List<Map<String, dynamic>>.from(rows)
          .map(SaasTransaction.tryFromMap).whereType<SaasTransaction>()
          .toList();
    } catch (e) {
      if (!isNetworkError(e)) rethrow;
      markOffline();
      // Offline: halaman lanjutan tak ada → list kosong (hasMore padam
      // di pemanggil bila tanpa cache); halaman pertama pakai cache.
      if (after != null) return [];
      final cached = await readTxCache(orgId, month);
      if (cached != null) {
        return cached.map(SaasTransaction.tryFromMap).whereType<SaasTransaction>().toList();
      }
      rethrow;
    }
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
        .map(SaasTransaction.tryFromMap).whereType<SaasTransaction>()
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
        .map(SaasTransaction.tryFromMap).whereType<SaasTransaction>()
        .toList();
  }

  /// Agregat sebulan per (jenis, kategori) via RPC month_mix
  /// (migration_18). [walletId] null = semua (transfer ikut bila salah
  /// satu kaki cocok, selaras filterByWallet). Melempar bila RPC tak ada
  /// atau gagal → pemanggil fallback listMonth + mixRowsFromTx.
  Future<({List<MonthMixRow> rows, int totalN})> monthMix(
    String orgId,
    String month, {
    String? walletId,
  }) async {
    try {
      final res = await SupabaseConfig.client.rpc(
        'month_mix',
        params: {
          'p_org_id': orgId,
          'p_month': month,
          if (walletId != null && walletId.isNotEmpty) 'p_wallet': walletId,
        },
      );
      markOnline();
      final m = Map<String, dynamic>.from(res as Map);
      unawaited(writeMixCache(orgId, month, walletId, m));
      return _mixFromMap(m);
    } catch (e) {
      if (!isNetworkError(e)) rethrow;
      markOffline();
      final cached = await readMixCache(orgId, month, walletId);
      if (cached != null) return _mixFromMap(cached);
      rethrow;
    }
  }

  ({List<MonthMixRow> rows, int totalN}) _mixFromMap(
    Map<String, dynamic> m,
  ) {
    final raw = (m['rows'] as List? ?? []);
    return (
      rows: [
        for (final r in raw)
          MonthMixRow.fromMap(Map<String, dynamic>.from(r as Map)),
      ],
      totalN: (m['total_n'] as num?)?.toInt() ?? 0,
    );
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
  /// terbakar bila insert gagal (duplikat hash, RLS, dll). Celah app-mati
  /// di antaranya ditutup oleh backfillMissingCodes() tiap start.
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
    if (amount <= 0) throw ArgumentError('amount harus > 0');
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

  /// Backfill kode TX yang kosong (NICE-TO-HAVE #N2).
  /// Menutup celah non-atomik add(): app terbunuh antara insert & mint code
  /// meninggalkan baris permanen tanpa code. Urutan insert-first dipertahankan
  /// (nomor TX tidak terbakar bila insert gagal); yang tertinggal diisi di sini.
  /// Best-effort per baris, cap 100/start agar startup tetap ringan.
  Future<void> backfillMissingCodes(String orgId) async {
    final rows = await SupabaseConfig.client
        .from('transactions')
        .select('id')
        .eq('org_id', orgId)
        .isFilter('code', null)
        .limit(100);
    for (final r in (rows as List)) {
      final id = (r as Map)['id']?.toString();
      if (id == null || id.isEmpty) continue;
      try {
        final minted = await mintCode(orgId);
        await SupabaseConfig.client
            .from('transactions')
            .update({'code': minted})
            .eq('id', id);
      } catch (e) {
        // best-effort: baris ini dilewati, dicoba lagi di start berikutnya
        debugPrint('[backfill] skip $id: $e');
      }
    }
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
    if (amount <= 0) throw ArgumentError('amount harus > 0');
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
