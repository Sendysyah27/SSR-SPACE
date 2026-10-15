import 'package:shared_preferences/shared_preferences.dart';
import 'package:ssr_space/services/budget_service.dart';
import 'package:ssr_space/services/debt_store.dart';
import 'package:ssr_space/services/debt_track.dart';
import 'package:ssr_space/services/goal_store.dart';
import 'package:ssr_space/services/month.dart';
import 'package:ssr_space/services/recurring_bills.dart';
import 'package:ssr_space/services/transaction_service.dart';
import 'package:ssr_space/services/wallet_service.dart';
import 'package:ssr_space/utils/org_prefs.dart';

// Izin akses data untuk Mang AI (dialog sekali saat chat dibuka).
// false/tak ada = chat jalan TANPA konteks data (tetap bisa tanya umum).
const _kAiDataOk = 'ai_data_ok';

Future<bool?> aiDataChoice() async {
  try {
    final p = await SharedPreferences.getInstance();
    if (!p.containsKey(_kAiDataOk)) return null;
    return p.getBool(_kAiDataOk) ?? false;
  } catch (_) {
    return false;
  }
}

Future<void> setAiDataChoice(bool v) async {
  try {
    await (await SharedPreferences.getInstance())
        .setBool(_kAiDataOk, v);
  } catch (_) {}
}

/// Ringkasan data user untuk konteks AI (maks ~2000 char).
/// Tiap seksi fail-open sendiri-sendiri; kosong = '' (tanpa konteks).
/// Hanya angka + nama (tanpa ID internal).
Future<String> buildAiDataContext() async {
  final buf = StringBuffer();
  String orgId = '';
  try {
    orgId = await activeOrgId();
  } catch (_) {}
  if (orgId.isEmpty) return '';
  // Dompet + saldo.
  try {
    final ws = await WalletService().list(orgId);
    final bals = await WalletService().balances(orgId);
    final map = {for (final b in bals) b.walletId: b.balance};
    var total = 0.0;
    final lines = <String>[];
    for (final w in ws.take(8)) {
      final s = map[w.id] ?? 0;
      total += s;
      lines.add('${w.name}: ${s.toStringAsFixed(0)}');
    }
    buf.writeln('Dompet (total ${total.toStringAsFixed(0)}):');
    for (final l in lines) {
      buf.writeln('- $l');
    }
    // Penegas kontrak aksi: wallet HARUS persis dari daftar di atas.
    buf.writeln(
        "Isi 'wallet' pada action HANYA dengan nama persis dari daftar dompet di atas; "
        'jangan karang nama/metode bayar lain.');
  } catch (_) {}
  // Arus bulan berjalan.
  try {
    final txs = await TransactionService().listMonth(orgId, currentMonth());
    var masuk = 0.0, keluar = 0.0;
    for (final t in txs) {
      if (t.type == 'in') {
        masuk += t.amount;
      } else if (t.type == 'out') {
        keluar += t.amount;
      }
    }
    buf.writeln(
        'Bulan ini: masuk ${masuk.toStringAsFixed(0)}, keluar ${keluar.toStringAsFixed(0)}.');
  } catch (_) {}
  // Budget + tagihan aktif.
  try {
    final bm = await fetchBudgets(orgId);
    final over = <String>[];
    for (final b in bm.items.take(8)) {
      over.add('${b.category}: ${b.spent.toStringAsFixed(0)}/${b.limit.toStringAsFixed(0)}');
    }
    if (over.isNotEmpty) {
      buf.writeln('Budget:');
      for (final l in over) {
        buf.writeln('- $l');
      }
    }
  } catch (_) {}
  try {
    final bills = await loadBills();
    final act = bills.where((b) => b.active).take(8).toList();
    if (act.isNotEmpty) {
      buf.writeln('Tagihan aktif:');
      for (final b in act) {
        buf.writeln(
            '- ${b.label}: ${b.amount.toStringAsFixed(0)} (jatuh ${b.nextDue})');
      }
    }
  } catch (_) {}
  // Target nabung (baca saja).
  try {
    final goals = await loadGoals();
    final act = goals.take(6).toList();
    if (act.isNotEmpty) {
      buf.writeln('Target nabung:');
      for (final g in act) {
        buf.writeln('- ${g.name}: '
            '${g.savedManual.toStringAsFixed(0)}/${g.target.toStringAsFixed(0)}');
      }
    }
  } catch (_) {}
  // Utang & piutang aktif (baca saja).
  try {
    final debts = await loadDebts();
    final act = debts.where((d) => d.remaining() > 0).take(6).toList();
    if (act.isNotEmpty) {
      buf.writeln('Utang & piutang aktif:');
      for (final d in act) {
        final kind = d.kind == debtKindDebt ? 'Utang' : 'Piutang';
        buf.writeln(
            '- $kind ${d.name}: sisa ${d.remaining().toStringAsFixed(0)}');
      }
    }
  } catch (_) {}
  // Daftar fitur aplikasi agar AI bisa mengarahkan user ke fitur yang
  // tepat (pengetahuan fitur, bukan eksekusi).
  buf.writeln('Fitur SSR SPACE: Dompet, Tagihan rutin, Target nabung, '
      'Utang & Piutang, E-Money NFC, Patungan, Budget, Laporan, '
      'Langganan terdeteksi, Pelacakan otomatis. Arahkan user ke fitur '
      'yang relevan bila bertanya soal fitur; jangan eksekusi apa pun.');
  final s = buf.toString().trim();
  if (s.isEmpty) return '';
  final capped = s.length <= 3000 ? s : s.substring(0, 3000);
  return 'DATA USER (baca saja, akurat per saat ini):\n$capped';
}
