import 'package:shared_preferences/shared_preferences.dart';

/// ID workspace (org) aktif yang tersimpan di prefs.
/// Return string kosong bila belum ada — pola ini sama persis di banyak
/// layar (Dompet, Transaksi, Budget, Billing, Laporan).
Future<String> activeOrgId() async =>
    (await SharedPreferences.getInstance()).getString('active_org_id') ?? '';

/// Nama workspace aktif untuk kop laporan.
Future<String> activeOrgName() async =>
    (await SharedPreferences.getInstance()).getString('active_org_name') ?? '-';
