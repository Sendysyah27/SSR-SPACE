import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';
import 'package:ssr_space/services/debt_track.dart';

// Penyimpanan prefs daftar utang-piutang (maks [maxDebts]).
// Dipisah dari layar agar service notifikasi bisa pakai tanpa
// import file widget (debt_track.dart tetap murni untuk test dart).

/// Kunci prefs daftar utang-piutang.
const kDebtsKey = 'debts';

Future<List<DebtRecord>> loadDebts() async {
  final prefs = await SharedPreferences.getInstance();
  final raw = prefs.getString(kDebtsKey);
  if (raw == null || raw.isEmpty) return [];
  try {
    final list = jsonDecode(raw) as List;
    final out = <DebtRecord>[];
    for (final e in list) {
      final d = DebtRecord.tryParse(e);
      if (d != null) out.add(d);
      if (out.length >= maxDebts) break;
    }
    return out;
  } catch (_) {
    return [];
  }
}

Future<void> saveDebts(List<DebtRecord> debts) async {
  final capped = debts.take(maxDebts).toList();
  final prefs = await SharedPreferences.getInstance();
  await prefs.setString(
    kDebtsKey,
    jsonEncode([for (final d in capped) d.toJson()]),
  );
}
