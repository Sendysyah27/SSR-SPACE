import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

/// Status konektivitas pasif (Batch 8 Sprint): mengikuti hasil panggil
/// nyata, tanpa plugin/dep baru. Default online (fail-open).
final netOnline = ValueNotifier<bool>(true);

void markOnline() {
  if (!netOnline.value) netOnline.value = true;
}

void markOffline() {
  if (netOnline.value) netOnline.value = false;
}

/// True bila error = jaringan (server tak menjawab). PostgrestException =
/// server menjawab (RLS/kuota/validasi) → BUKAN offline, jangan sodorkan
/// cache basi. Murni (testable).
bool isNetworkError(Object e) {
  if (e is PostgrestException) return false;
  if (e is SocketException ||
      e is HttpException ||
      e is TimeoutException) {
    return true;
  }
  final n = e.runtimeType.toString();
  return n.contains('ClientException') ||
      n.contains('SocketException') ||
      n.contains('Connection');
}

String _mixKey(String orgId, String month, String? walletId) =>
    'off_mix_${orgId}_${month}_${(walletId == null || walletId.isEmpty) ? 'all' : walletId}';
String _txKey(String orgId, String month) => 'off_tx_${orgId}_$month';
String _budKey(String orgId, String month) => 'off_bud_${orgId}_$month';

Future<void> _write(String key, Object value) async {
  try {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(key, jsonEncode(value));
  } catch (e) {
    // best-effort: cache lokal gagal tulis bukan fatal (data utama di cloud).
    debugPrint('[offline_cache] tulis $key gagal: $e');
  }
}

Future<dynamic> _read(String key) async {
  try {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(key);
    if (raw == null || raw.isEmpty) return null;
    return jsonDecode(raw);
  } catch (_) {
    return null;
  }
}

/// Tulis hasil RPC month_mix mentah (map JSON) untuk fallback offline.
Future<void> writeMixCache(
  String orgId,
  String month,
  String? walletId,
  Map<String, dynamic> res,
) =>
    _write(_mixKey(orgId, month, walletId), res);

/// Baca cache mix (null bila tak ada/rusak).
Future<Map<String, dynamic>?> readMixCache(
  String orgId,
  String month,
  String? walletId,
) async {
  final v = await _read(_mixKey(orgId, month, walletId));
  if (v is Map) return Map<String, dynamic>.from(v);
  return null;
}

/// Tulis baris transaksi mentah (List<Map> JSON-encodable dari Supabase).
Future<void> writeTxCache(
  String orgId,
  String month,
  List<dynamic> rows,
) =>
    _write(_txKey(orgId, month), rows);

/// Baca cache transaksi sebagai list map (null bila tak ada/rusak).
Future<List<Map<String, dynamic>>?> readTxCache(
  String orgId,
  String month,
) async {
  final v = await _read(_txKey(orgId, month));
  if (v is List) {
    try {
      return [
        for (final r in v) Map<String, dynamic>.from(r as Map),
      ];
    } catch (_) {
      return null;
    }
  }
  return null;
}

/// Tulis BudgetMonth jadi (map dari [BudgetMonth.toMap]).
Future<void> writeBudgetCache(
  String orgId,
  String month,
  Map<String, dynamic> value,
) =>
    _write(_budKey(orgId, month), value);

/// Baca cache budget (null bila tak ada/rusak).
Future<Map<String, dynamic>?> readBudgetCache(
  String orgId,
  String month,
) async {
  final v = await _read(_budKey(orgId, month));
  if (v is Map) return Map<String, dynamic>.from(v);
  return null;
}
