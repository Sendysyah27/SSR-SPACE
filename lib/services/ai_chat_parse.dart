// Parser balasan chat Mang AI.
//
// Kontrak model (lihat LocalOpenCodeProvider.DEFAULT_SYSTEM + aiSoul):
//   {"reply":"<teks untuk user>","action":null}
//   {"reply":"...","action":{"type":"in|out|transfer","amount":<int>,
//     "category":"...","wallet":"...","note":"..."}}
// Tanpa markdown fence, tanpa teks di luar JSON.
//
// Murni Dart (dart:convert + quick_input_parse, tanpa package Flutter)
// agar testable via `dart` murni maupun `flutter test`.
// Tak pernah throw; tak pernah log isi pesan.
import 'dart:convert';

import 'quick_input_parse.dart';

/// Validasi ketat aksi transaksi dari model.
/// - type: hanya 'in' | 'out' | 'transfer'.
/// - amount: HARUS int > 0. Tolak double, string, negatif, nol.
///   Uang = int (rupiah); jangan konversi longgar di sini.
/// - wallet: cocok dengan daftar wallet app (fuzzy via [matchWalletName],
///   sama seperti _runAction). Daftar kosong = terima string non-empty
///   (validasi akhir tetap di form).
/// - category: HARUS dari daftar kategori app (tak sensitif huruf).
///   Daftar kosong = terima string non-empty.
/// - note: opsional.
/// Gagal validasi -> null (tanpa tombol, tampilkan reply saja).
Map<String, dynamic>? validateChatAction(
  dynamic raw, {
  List<String> wallets = const [],
  List<String> categories = const [],
}) {
  if (raw == null || raw is! Map) return null;
  final m = Map<String, dynamic>.from(raw);

  final type = m['type'];
  if (type != 'in' && type != 'out' && type != 'transfer') return null;

  final amount = m['amount'];
  if (amount is! int || amount <= 0) return null;

  final walletRaw = m['wallet'];
  String? wallet;
  if (walletRaw is String && walletRaw.trim().isNotEmpty) {
    final w = walletRaw.trim();
    if (wallets.isEmpty) {
      wallet = w;
    } else {
      final hit = matchWalletName(w, wallets);
      if (hit == null) return null;
      wallet = hit; // normalisasi ke nama resmi dompet
    }
  } else {
    return null;
  }

  final catRaw = m['category'];
  String? category;
  if (catRaw is String && catRaw.trim().isNotEmpty) {
    final c = catRaw.trim();
    if (categories.isEmpty) {
      category = c;
    } else {
      String? hit;
      for (final k in categories) {
        if (k.toLowerCase() == c.toLowerCase()) {
          hit = k;
          break;
        }
      }
      if (hit == null) return null;
      category = hit; // normalisasi ke nama resmi kategori
    }
  } else {
    return null;
  }

  final noteRaw = m['note'];
  final note = noteRaw is String && noteRaw.trim().isNotEmpty
      ? noteRaw.trim()
      : null;

  return {
    'type': type,
    'amount': amount,
    'category': category,
    'wallet': wallet,
    if (note != null) 'note': note,
  };
}

/// Buang pembungkus ```json ... ``` / ``` ... ``` bila mengapit seluruh teks.
String _stripFence(String t) {
  final m = RegExp(r'^```(?:json)?\s*([\s\S]*?)\s*```$').firstMatch(t);
  return m != null ? m.group(1)!.trim() : t;
}

/// Urai balasan mentah model -> (reply, action).
/// - JSON valid berkontrak: kembalikan field `reply` SAJA sebagai teks
///   bubble; JSON mentah tidak pernah tampil ke user.
/// - Parse gagal (bukan JSON / bukan Map / tanpa `reply` string):
///   kembalikan teks asli apa adanya, action null (tanpa tombol).
/// Tak pernah throw.
({String reply, Map<String, dynamic>? action}) parseChatReply(
  String raw, {
  List<String> wallets = const [],
  List<String> categories = const [],
}) {
  final clean = _stripFence(raw.trim());
  dynamic decoded;
  try {
    decoded = jsonDecode(clean);
  } catch (_) {
    return (reply: raw, action: null);
  }
  if (decoded is! Map) return (reply: raw, action: null);
  final m = Map<String, dynamic>.from(decoded);
  final reply = m['reply'];
  if (reply is! String || reply.trim().isEmpty) {
    return (reply: raw, action: null);
  }
  final action = validateChatAction(
    m['action'],
    wallets: wallets,
    categories: categories,
  );
  return (reply: reply, action: action);
}
