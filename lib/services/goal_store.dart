import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';
import 'package:ssr_space/services/savings_goal.dart';

/// Simpan goals di prefs `savings_goals` sebagai list JSON (maks 20),
/// ikut pola `recurring_bills`. Entri rusak dibuang saat baca.
const _kGoals = 'savings_goals';

Future<List<SavingsGoal>> loadGoals() async {
  final prefs = await SharedPreferences.getInstance();
  final raw = prefs.getString(_kGoals);
  if (raw == null || raw.isEmpty) return [];
  try {
    final list = jsonDecode(raw) as List;
    return [
      for (final e in list) SavingsGoal.tryParse(e),
    ].whereType<SavingsGoal>().take(maxGoals).toList();
  } catch (_) {
    return [];
  }
}

Future<void> saveGoals(List<SavingsGoal> goals) async {
  final prefs = await SharedPreferences.getInstance();
  final capped = goals.take(maxGoals).toList();
  await prefs.setString(
    _kGoals,
    jsonEncode([for (final g in capped) g.toJson()]),
  );
}
