import 'package:ssr_space/services/transaction_service.dart';
import 'package:ssr_space/models/transaction.dart';

class DashboardData {
  final double totalIn;
  final double totalOut;
  final Map<String, double> outByCategory;
  final List<SaasTransaction> recent;
  DashboardData({required this.totalIn, required this.totalOut, required this.outByCategory, required this.recent});
  double get balance => totalIn - totalOut;
}

DashboardData computeDashboard(List<SaasTransaction> txs) {
  double totalIn = 0;
  double totalOut = 0;
  final byCat = <String, double>{};
  for (final t in txs) {
    if (t.type == 'in') {
      totalIn += t.amount;
    } else if (t.type == 'out') {
      totalOut += t.amount;
      final k = (t.category?.isNotEmpty ?? false) ? t.category! : 'Lainnya';
      byCat[k] = (byCat[k] ?? 0) + t.amount;
    }
  }
  return DashboardData(
    totalIn: totalIn,
    totalOut: totalOut,
    outByCategory: byCat,
    recent: txs.take(5).toList(),
  );
}

Future<DashboardData> fetchDashboard(String orgId) async {
  final txs = await TransactionService().list(orgId);
  return computeDashboard(txs);
}
