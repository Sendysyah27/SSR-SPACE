import 'package:ssr_space/services/space_service.dart';
import 'package:ssr_space/services/supabase_config.dart';
import 'package:ssr_space/services/pg_trigger_codes.dart';
import 'package:ssr_space/models/wallet.dart';
import 'package:ssr_space/models/wallet_balance.dart';
import 'package:ssr_space/utils/strings.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

/// Kuota paket mentok (trigger QUOTA_EXCEEDED, migration_20).
/// Pesan sudah lokal (q_wallet_exceeded / q_budget_exceeded) — pemanggil
/// UI: catch → `requirePro(context, e.message)`. Bukan SpaceException
/// (itu khusus mode Bendahara 42501).
class QuotaExceededException implements Exception {
  final String message;
  const QuotaExceededException(this.message);
  @override
  String toString() => 'QuotaExceededException($message)';
}

/// Bungkus tulis dompet: RLS bendahara → pesan jujur, bukan error teknis.
Future<T> _guardSpace<T>(Future<T> Function() run) async {
  try {
    return await run();
  } on PostgrestException catch (e) {
    if (e.code == '42501') throw SpaceException(tr('sp_only_treasurer'));
    rethrow;
  }
}

class WalletService {
  Future<List<Wallet>> list(String orgId) async {
    final rows = await SupabaseConfig.client.from('wallets').select().eq('org_id', orgId).order('created_at');
    return List<Map<String, dynamic>>.from(rows).map(Wallet.fromMap).toList();
  }

  Future<String> create(String orgId, String name, String type, {String currency = 'IDR'}) async {
    return _guardSpace(() async {
      try {
        final row = await SupabaseConfig.client
            .from('wallets')
            .insert({'org_id': orgId, 'name': name, 'type': type, 'currency': currency.toUpperCase()})
            .select('id')
            .single();
        return row['id'].toString();
      } on PostgrestException catch (e) {
        // Trigger kuota (migration_20): tawarkan Pro, bukan error teknis.
        // _guardSpace di luar tetap memetakan 42501 Bendahara.
        if (pgIsQuotaExceeded(e)) {
          throw QuotaExceededException(tr('q_wallet_exceeded'));
        }
        rethrow;
      }
    });
  }

  Future<void> rename(String id, String orgId, String name) async {
    return _guardSpace(() async {
      await SupabaseConfig.client
          .from('wallets')
          .update({'name': name})
          .eq('id', id)
          .eq('org_id', orgId);
    });
  }

  Future<void> changeType(String id, String orgId, String type) async {
    return _guardSpace(() async {
      await SupabaseConfig.client
          .from('wallets')
          .update({'type': type})
          .eq('id', id)
          .eq('org_id', orgId);
    });
  }

  Future<bool> hasTransactions(String orgId, String walletId) async {
    final rows = await SupabaseConfig.client
        .from('transactions')
        .select('id')
        .eq('org_id', orgId)
        .or('wallet_id.eq.$walletId,to_wallet_id.eq.$walletId')
        .limit(1);
    return (rows as List).isNotEmpty;
  }

  Future<void> deleteWallet(String id, String orgId) async {
    return _guardSpace(() async {
      await SupabaseConfig.client
          .from('wallets')
          .delete()
          .eq('id', id)
          .eq('org_id', orgId);
    });
  }

  Future<List<WalletBalance>> balances(String orgId) async {
    final rows = await SupabaseConfig.client
        .from('wallet_balance')
        .select()
        .eq('org_id', orgId);
    return List<Map<String, dynamic>>.from(rows)
        .map(WalletBalance.fromMap)
        .toList();
  }
}

/// Snapshot dompet + saldo per workspace di memori (TTL 60 detik).
///
/// Form catat dibuka dari cache agar sheet tampil segera; penyegaran
/// diam-diam mengisi buka berikutnya. Stale ≤60 detik wajar untuk label
/// dropdown (saldo otoritatif tetap di Supabase). Fail-open: miss = null.
class CachedWallets {
  final List<Wallet> wallets;
  final Map<String, double> balances;
  const CachedWallets(this.wallets, this.balances);
}

class WalletCache {
  static CachedWallets? _cached;
  static String? _orgId;
  static DateTime? _at;
  static const ttl = Duration(seconds: 60);

  static CachedWallets? peek(String orgId) {
    if (_orgId != orgId || _cached == null || _at == null) return null;
    if (DateTime.now().difference(_at!) > ttl) return null;
    return _cached;
  }

  static void store(
    String orgId,
    List<Wallet> wallets,
    Map<String, double> balances,
  ) {
    _orgId = orgId;
    _cached = CachedWallets(List.of(wallets), Map.of(balances));
    _at = DateTime.now();
  }

  static void invalidate() {
    _cached = null;
    _at = null;
  }
}
