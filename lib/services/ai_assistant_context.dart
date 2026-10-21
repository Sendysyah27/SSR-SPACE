import 'package:ssr_space/utils/org_prefs.dart';

import 'goal_store.dart';
import 'month.dart';
import 'recurring_bills.dart';
import 'transaction_service.dart';
import 'wallet_service.dart';

// Context builder terstruktur Mode Asisten (batch 281C tahap 2,
// meniru AssistantContextBuilder-nya Ollo): snapshot dihitung dari
// service existing, dipakai untuk (1) teks konteks ke model dan
// (2) render kartu viz — angka SELALU dari data lokal app, model
// hanya memilih jenis viz. Tiap seksi fail-open sendiri-sendiri.

/// Snapshot keuangan ringkas untuk Mode Asisten.
class AssistantSnapshot {
  final List<({String name, double balance})> wallets;
  final double totalBalance;
  final double monthIn;
  final double monthOut;
  final List<({String name, double total})> topCategories;
  final List<({String day, double inAmt, double outAmt})> last7;
  final double last7In;
  final double last7Out;
  final int last7Count;
  final double prevMonthIn;
  final double prevMonthOut;
  final List<({String day, double inAmt, double outAmt})> daily30;
  final List<({String name, double total})> topMerchants;
  final ({String label, double amount, String due})? nextBill;
  final List<({String name, double saved, double target})> goals;

  const AssistantSnapshot({
    this.wallets = const [],
    this.totalBalance = 0,
    this.monthIn = 0,
    this.monthOut = 0,
    this.topCategories = const [],
    this.last7 = const [],
    this.last7In = 0,
    this.last7Out = 0,
    this.last7Count = 0,
    this.prevMonthIn = 0,
    this.prevMonthOut = 0,
    this.daily30 = const [],
    this.topMerchants = const [],
    this.nextBill,
    this.goals = const [],
  });

  bool get hasData =>
      wallets.isNotEmpty ||
      monthIn > 0 ||
      monthOut > 0 ||
      last7Count > 0 ||
      prevMonthIn > 0 ||
      prevMonthOut > 0 ||
      daily30.isNotEmpty ||
      topMerchants.isNotEmpty;
}

String _ymd(DateTime d) =>
    '${d.year}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}';

/// Rakit snapshot dari data app yang sudah tersedia (tanpa jalur data
/// baru). Gagal total -> snapshot kosong (hasData false).
Future<AssistantSnapshot> buildAssistantSnapshot() async {
  var orgId = '';
  try {
    orgId = await activeOrgId();
  } catch (_) {}
  if (orgId.isEmpty) return const AssistantSnapshot();

  var wallets = <({String name, double balance})>[];
  var totalBalance = 0.0;
  try {
    final ws = await WalletService().list(orgId);
    final bals = await WalletService().balances(orgId);
    final map = {for (final b in bals) b.walletId: b.balance};
    for (final w in ws.take(10)) {
      final s = map[w.id] ?? 0;
      totalBalance += s;
      wallets.add((name: w.name, balance: s));
    }
  } catch (_) {}

  var monthIn = 0.0, monthOut = 0.0;
  var topCategories = <({String name, double total})>[];
  var last7 = <({String day, double inAmt, double outAmt})>[];
  var last7In = 0.0, last7Out = 0.0, last7Count = 0;
  var prevMonthIn = 0.0, prevMonthOut = 0.0;
  var daily30 = <({String day, double inAmt, double outAmt})>[];
  var topMerchants = <({String name, double total})>[];
  try {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final start = today.subtract(const Duration(days: 6));
    final cur = currentMonth();
    final curList =
        List.of(await TransactionService().listMonth(orgId, cur));
    final prevList =
        List.of(await TransactionService().listMonth(orgId, prevMonth(cur)));
    final all = [...curList, ...prevList];
    final catTotals = <String, double>{};
    final perDay = <String, ({double inAmt, double outAmt})>{};
    for (final t in all) {
      final d = (t.date ?? '').length >= 10 ? t.date!.substring(0, 10) : '';
      if (d.startsWith(cur)) {
        if (t.type == 'in') monthIn += t.amount;
        if (t.type == 'out') {
          monthOut += t.amount;
          final c = (t.category ?? '').trim();
          if (c.isNotEmpty) catTotals[c] = (catTotals[c] ?? 0) + t.amount;
        }
      }
      if (d.isNotEmpty) {
        final dt = DateTime.tryParse(d);
        if (dt != null && !dt.isBefore(start) && !dt.isAfter(today)) {
          final prev = perDay[d] ?? (inAmt: 0.0, outAmt: 0.0);
          if (t.type == 'in') {
            perDay[d] = (inAmt: prev.inAmt + t.amount, outAmt: prev.outAmt);
            last7In += t.amount;
            last7Count++;
          } else if (t.type == 'out') {
            perDay[d] = (inAmt: prev.inAmt, outAmt: prev.outAmt + t.amount);
            last7Out += t.amount;
            last7Count++;
          }
        }
      }
    }
    final sorted = catTotals.entries.toList()
      ..sort((a, b) => b.value.compareTo(a.value));
    topCategories = [
      for (final e in sorted.take(5)) (name: e.key, total: e.value)
    ];
    // Batch 285 tahap C: total bulan lalu + seri harian 30 hari +
    // merchant/catatan pengeluaran teratas. Fail-open di blok try ini.
    for (final t in prevList) {
      if (t.type == 'in') prevMonthIn += t.amount;
      if (t.type == 'out') prevMonthOut += t.amount;
    }
    final d30Start = today.subtract(const Duration(days: 29));
    final perDay30 = <String, ({double inAmt, double outAmt})>{};
    final merchTotals = <String, double>{};
    void accumulate30(Transaction t) {
      final d = (t.date ?? '').length >= 10 ? t.date!.substring(0, 10) : '';
      if (d.isNotEmpty) {
        final dt = DateTime.tryParse(d);
        if (dt != null && !dt.isBefore(d30Start) && !dt.isAfter(today)) {
          final prev = perDay30[d] ?? (inAmt: 0.0, outAmt: 0.0);
          if (t.type == 'in') {
            perDay30[d] =
                (inAmt: prev.inAmt + t.amount, outAmt: prev.outAmt);
          } else if (t.type == 'out') {
            perDay30[d] =
                (inAmt: prev.inAmt, outAmt: prev.outAmt + t.amount);
          }
        }
      }
    }
    for (final t in curList) {
      accumulate30(t);
      if (t.type == 'out') {
        final name = (t.note ?? '').trim();
        if (name.isNotEmpty) {
          merchTotals[name] = (merchTotals[name] ?? 0) + t.amount;
        }
      }
    }
    for (final t in prevList) {
      accumulate30(t);
    }
    daily30 = [
      for (var i = 0; i < 30; i++)
        (
          day: _ymd(d30Start.add(Duration(days: i))),
          inAmt: perDay30[_ymd(d30Start.add(Duration(days: i)))]?.inAmt ?? 0,
          outAmt: perDay30[_ymd(d30Start.add(Duration(days: i)))]?.outAmt ?? 0,
        )
    ];
    final mSorted = merchTotals.entries.toList()
      ..sort((a, b) => b.value.compareTo(a.value));
    topMerchants = [
      for (final e in mSorted.take(5)) (name: e.key, total: e.value)
    ];
    last7 = [
      for (var i = 0; i < 7; i++)
        (
          day: _ymd(start.add(Duration(days: i))),
          inAmt: perDay[_ymd(start.add(Duration(days: i)))]?.inAmt ?? 0,
          outAmt: perDay[_ymd(start.add(Duration(days: i)))]?.outAmt ?? 0,
        )
    ];
  } catch (_) {}

  ({String label, double amount, String due})? nextBill;
  try {
    final bills = await loadBills();
    final act = bills.where((b) => b.active && b.nextDue.isNotEmpty).toList()
      ..sort((a, b) => a.nextDue.compareTo(b.nextDue));
    if (act.isNotEmpty) {
      final b = act.first;
      nextBill = (label: b.label, amount: b.amount, due: b.nextDue);
    }
  } catch (_) {}

  var goals = <({String name, double saved, double target})>[];
  try {
    final gs = await loadGoals();
    goals = [
      for (final g in gs.take(6))
        (name: g.name, saved: g.savedManual, target: g.target)
    ];
  } catch (_) {}

  return AssistantSnapshot(
    wallets: wallets,
    totalBalance: totalBalance,
    monthIn: monthIn,
    monthOut: monthOut,
    topCategories: topCategories,
    last7: last7,
    last7In: last7In,
    last7Out: last7Out,
    last7Count: last7Count,
    prevMonthIn: prevMonthIn,
    prevMonthOut: prevMonthOut,
    daily30: daily30,
    topMerchants: topMerchants,
    nextBill: nextBill,
    goals: goals,
  );
}

String _rp0(double v) => v.toStringAsFixed(0);

/// Teks konteks Mode Asisten untuk model (ringkas, hemat token).
/// Kosong bila snapshot tak punya data.
String assistantContextText(AssistantSnapshot s) {
  if (!s.hasData) return '';
  final buf = StringBuffer();
  if (s.wallets.isNotEmpty) {
    buf.writeln('Dompet (total ${_rp0(s.totalBalance)}):');
    for (final w in s.wallets) {
      buf.writeln('- ${w.name}: ${_rp0(w.balance)}');
    }
  }
  buf.writeln(
      'Bulan ini: masuk ${_rp0(s.monthIn)}, keluar ${_rp0(s.monthOut)}.');
  buf.writeln('Bulan lalu: masuk ${_rp0(s.prevMonthIn)}, '
      'keluar ${_rp0(s.prevMonthOut)}.');
  if (s.topMerchants.isNotEmpty) {
    buf.writeln('Merchant/catatan pengeluaran teratas bulan ini:');
    for (final m in s.topMerchants) {
      buf.writeln('- ${m.name}: ${_rp0(m.total)}');
    }
  }
  if (s.topCategories.isNotEmpty) {
    buf.writeln('Kategori pengeluaran teratas bulan ini:');
    for (final c in s.topCategories) {
      buf.writeln('- ${c.name}: ${_rp0(c.total)}');
    }
  }
  if (s.last7Count > 0) {
    buf.writeln('7 hari terakhir: masuk ${_rp0(s.last7In)}, '
        'keluar ${_rp0(s.last7Out)} dari ${s.last7Count} transaksi.');
  }
  final b = s.nextBill;
  if (b != null) {
    buf.writeln(
        'Tagihan terdekat: ${b.label} ${_rp0(b.amount)} (jatuh ${b.due}).');
  }
  if (s.goals.isNotEmpty) {
    buf.writeln('Target nabung:');
    for (final g in s.goals) {
      buf.writeln('- ${g.name}: ${_rp0(g.saved)}/${_rp0(g.target)}');
    }
  }
  final out = buf.toString().trim();
  if (out.isEmpty) return '';
  final capped = out.length <= 2500 ? out : out.substring(0, 2500);
  return 'DATA ASISTEN (baca saja, akurat per saat ini):\n$capped';
}
