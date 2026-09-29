import '../models/transaction.dart';
import 'wallet_filter.dart';

/// Filter ekspor Laporan: dompet sesi + jenis arus, murni bisa di-test.
///
/// `flow`: 'all' | 'in' | 'out' | 'transfer'. Nilai tak dikenal = 'all'
/// (fail-open: ekspor tak pernah kosong karena salah ketik filter).
/// Urutan stabil: dompet dulu lalu jenis, sama dengan yang tampil di layar.
List<SaasTransaction> applyReportFilters(
  List<SaasTransaction> items,
  String? walletId,
  String flow,
) {
  final byWallet = filterByWallet(items, walletId);
  final f = flow == 'in' || flow == 'out' || flow == 'transfer' ? flow : 'all';
  if (f == 'all') return byWallet;
  return byWallet.where((t) => t.type == f).toList();
}

/// Nama file ekspor tanpa ekstensi: `laporan-YYYY-MM[-dompet][-jenis]`.
/// Label disanitasi (huruf/angka/dash saja, maks 24) agar aman di semua FS.
String exportBaseName(String month, {String? walletLabel, String flow = 'all'}) {
  final buf = StringBuffer('laporan-$month');
  final w = _slug(walletLabel);
  if (w.isNotEmpty) buf.write('-$w');
  if (flow == 'in' || flow == 'out' || flow == 'transfer') {
    buf.write('-$flow');
  }
  return buf.toString();
}

String _slug(String? s) {
  final clean = (s ?? '')
      .toLowerCase()
      .replaceAll(RegExp(r'[^a-z0-9]+'), '-')
      .replaceAll(RegExp(r'^-+|-+$'), '');
  if (clean.isEmpty) return '';
  return clean.length <= 24 ? clean : clean.substring(0, 24);
}
