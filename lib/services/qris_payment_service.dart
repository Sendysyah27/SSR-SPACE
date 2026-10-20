import 'package:flutter/foundation.dart';
import 'package:ssr_space/services/supabase_config.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

/// Hasil pemanggilan Edge Function QRIS.
/// Sukses → [data] berisi Map respons server. Gagal → [error] berisi
/// pesan jujur untuk ditampilkan ke user (error tak ditelan diam-diam
/// dan tak dilempar mentah ke UI).
class QrisResult {
  final Map<String, dynamic>? data;
  final String? error;

  const QrisResult.ok(this.data) : error = null;
  const QrisResult.fail(this.error) : data = null;

  bool get ok => error == null;
}

/// Ekstrak pesan error dari FunctionException: Edge Function QRIS
/// membalas JSON `{error: "..."}` di details. Bentuk lain (string /
/// tak dikenal) jatuh ke pesan generik + status HTTP.
String _fnErrorMessage(FunctionException e) {
  final d = e.details;
  if (d is Map && d['error'] != null) return d['error'].toString();
  if (d is String && d.isNotEmpty) return d;
  return 'Server menolak permintaan (${e.status}).';
}

/// Daftar paket yang bisa dibayar via QRIS — tabel `plan_pricing`
/// (SELECT publik), hanya yang aktif, urut harga naik.
/// Melempar bila query gagal: pemanggil (seksi QRIS di Billing)
/// menangkapnya dan menampilkan pesan error di seksinya sendiri.
Future<List<Map<String, dynamic>>> fetchQrisPlans() async {
  final rows = await SupabaseConfig.client
      .from('plan_pricing')
      .select()
      .eq('is_active', true)
      .order('price_idr', ascending: true);
  return (rows as List)
      .map((r) => Map<String, dynamic>.from(r as Map))
      .toList();
}

/// Buat pesanan QRIS baru lewat Edge Function `create-qris-order`.
/// Harga + kode unik ditentukan server dari `plan_pricing` — klien
/// hanya mengirim org dan kode paket, tidak pernah nominal.
Future<QrisResult> createQrisOrder(String orgId, String planCode) async {
  try {
    final res = await SupabaseConfig.client.functions.invoke(
      'create-qris-order',
      body: {'org_id': orgId, 'plan_code': planCode},
    );
    final d = res.data;
    if (d is Map) return QrisResult.ok(Map<String, dynamic>.from(d));
    return const QrisResult.fail('Respons server tidak dikenal.');
  } on FunctionException catch (e) {
    return QrisResult.fail(_fnErrorMessage(e));
  } catch (e) {
    // Gagal jaringan / tak dikenal: pesan jujur ke UI, detail ke log.
    debugPrint('createQrisOrder gagal: $e');
    return const QrisResult.fail(
      'Tidak bisa menghubungi server. Periksa koneksi lalu coba lagi.',
    );
  }
}

/// Konfirmasi "sudah bayar" lewat Edge Function `confirm-qris-order`
/// (status order pending → awaiting_confirmation).
Future<QrisResult> confirmQrisOrder(String orderId) async {
  try {
    final res = await SupabaseConfig.client.functions.invoke(
      'confirm-qris-order',
      body: {'order_id': orderId},
    );
    final d = res.data;
    if (d is Map) return QrisResult.ok(Map<String, dynamic>.from(d));
    return const QrisResult.fail('Respons server tidak dikenal.');
  } on FunctionException catch (e) {
    return QrisResult.fail(_fnErrorMessage(e));
  } catch (e) {
    // Gagal jaringan / tak dikenal: pesan jujur ke UI, detail ke log.
    debugPrint('confirmQrisOrder gagal: $e');
    return const QrisResult.fail(
      'Tidak bisa menghubungi server. Periksa koneksi lalu coba lagi.',
    );
  }
}

/// Baca ulang satu baris `payment_orders` milik user sendiri (RLS)
/// untuk polling status. Null bila baris tak ditemukan ATAU query
/// sesaat gagal — best-effort: UI mempertahankan status terakhir yang
/// diketahui dan countdown tetap menegakkan kedaluwarsa secara lokal.
Future<Map<String, dynamic>?> fetchQrisOrder(String orderId) async {
  try {
    final row = await SupabaseConfig.client
        .from('payment_orders')
        .select()
        .eq('id', orderId)
        .maybeSingle();
    if (row == null) return null;
    return Map<String, dynamic>.from(row as Map);
  } catch (e) {
    // best-effort: polling berkala; kegagalan sesaat tidak mengubah
    // kebenaran status terakhir yang ditampilkan.
    debugPrint('fetchQrisOrder gagal: $e');
    return null;
  }
}
