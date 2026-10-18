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
//
// Kode alasan (reason) untuk debug-only logging — HANYA kode, tanpa
// isi pesan/nominal/gambar:
//   parse_gagal, action_null, type_invalid, transfer_tanpa_tujuan,
//   amount_invalid, wallet_kosong, wallet_tidak_cocok,
//   kategori_kosong, kategori_tidak_cocok
import 'dart:convert';

import 'quick_input_parse.dart';

/// Kode alasan validasi aksi. null = valid.
String? validateChatActionReason(
  dynamic raw, {
  List<String> wallets = const [],
  List<String> categories = const [],
}) {
  if (raw == null) return 'action_null';
  if (raw is! Map) return 'action_null';
  final m = Map<String, dynamic>.from(raw);

  final type = m['type'];
  if (type != 'in' && type != 'out' && type != 'transfer') {
    return 'type_invalid';
  }
  if (type == 'transfer') {
    // Kontrak tak punya dompet tujuan: transfer via chat pasti tersimpan
    // tanpa to_wallet_id (baris korup) lewat simpan-satu-ketuk.
    // Tolak fail-closed; user tetap bisa catat manual via form
    // (ada picker dompet tujuan).
    return 'transfer_tanpa_tujuan';
  }

  final amount = m['amount'];
  if (amount is! int || amount <= 0) return 'amount_invalid';

  final walletRaw = m['wallet'];
  if (walletRaw is! String || walletRaw.trim().isEmpty) {
    return 'wallet_kosong';
  }
  final w = walletRaw.trim();
  if (wallets.isNotEmpty && matchWalletName(w, wallets) == null) {
    return 'wallet_tidak_cocok';
  }

  final catRaw = m['category'];
  if (catRaw is! String || catRaw.trim().isEmpty) {
    return 'kategori_kosong';
  }
  final c = catRaw.trim();
  if (categories.isNotEmpty) {
    var hit = false;
    for (final k in categories) {
      if (k.toLowerCase() == c.toLowerCase()) {
        hit = true;
        break;
      }
    }
    if (!hit) return 'kategori_tidak_cocok';
  }

  return null;
}

/// Validasi ketat aksi transaksi dari model.
/// - type: hanya 'in' | 'out'. 'transfer' DITOLAK (kontrak tak punya
///   dompet tujuan -> baris korup tanpa to_wallet_id).
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
  if (validateChatActionReason(raw,
          wallets: wallets, categories: categories) !=
      null) {
    return null;
  }
  final m = Map<String, dynamic>.from(raw as Map);
  final walletRaw = (m['wallet'] as String).trim();
  final catRaw = (m['category'] as String).trim();
  String wallet = walletRaw;
  String category = catRaw;
  if (wallets.isNotEmpty) {
    wallet = matchWalletName(walletRaw, wallets)!;
  }
  if (categories.isNotEmpty) {
    for (final k in categories) {
      if (k.toLowerCase() == catRaw.toLowerCase()) {
        category = k;
        break;
      }
    }
  }
  final noteRaw = m['note'];
  final note = noteRaw is String && noteRaw.trim().isNotEmpty
      ? noteRaw.trim()
      : null;
  return {
    'type': m['type'],
    'amount': m['amount'],
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

/// Salinan lenient field aksi mentah (untuk prefill kartu fallback).
/// Tidak divalidasi; hanya untuk tampilan. Tak pernah throw.
Map<String, dynamic>? lenientActionMap(dynamic raw) {
  if (raw is! Map) return null;
  final m = Map<String, dynamic>.from(raw);
  final out = <String, dynamic>{};
  final type = m['type'];
  if (type is String && type.trim().isNotEmpty) out['type'] = type.trim();
  final amount = m['amount'];
  if (amount is int && amount > 0) out['amount'] = amount;
  final category = m['category'];
  if (category is String && category.trim().isNotEmpty) {
    out['category'] = category.trim();
  }
  final wallet = m['wallet'];
  if (wallet is String && wallet.trim().isNotEmpty) {
    out['wallet'] = wallet.trim();
  }
  final note = m['note'];
  if (note is String && note.trim().isNotEmpty) out['note'] = note.trim();
  return out;
}

/// Apakah teks reply menjanjikan tombol/konfirmasi ke user?
/// Dipakai untuk fallback: jangan buang aksi yang ditolak diam-diam
/// bila model sudah berjanji ada tombol.
bool replyPromisesConfirmation(String reply) {
  final t = reply.toLowerCase();
  return t.contains('konfirmasi') || t.contains('jalankan');
}

/// Urai balasan mentah model -> (reply, action, actionRaw, reason).
/// - JSON valid berkontrak: kembalikan field `reply` SAJA sebagai teks
///   bubble; JSON mentah tidak pernah tampil ke user.
/// - Parse gagal (bukan JSON / bukan Map / tanpa `reply` string):
///   kembalikan teks asli apa adanya, action null, reason 'parse_gagal'.
/// - action null eksplisit: reason 'action_null'.
/// - action ditolak validasi: reason = kode dari [validateChatActionReason],
///   actionRaw = salinan lenient untuk prefill fallback.
/// Tak pernah throw. Tak pernah log isi pesan.
({String reply, Map<String, dynamic>? action, Map<String, dynamic>? actionRaw, String? reason}) parseChatReply(
  String raw, {
  List<String> wallets = const [],
  List<String> categories = const [],
}) {
  final clean = _stripFence(raw.trim());
  dynamic decoded;
  try {
    decoded = jsonDecode(clean);
  } catch (_) {
    return (reply: raw, action: null, actionRaw: null, reason: 'parse_gagal');
  }
  if (decoded is! Map) {
    return (reply: raw, action: null, actionRaw: null, reason: 'parse_gagal');
  }
  final m = Map<String, dynamic>.from(decoded);
  final reply = m['reply'];
  if (reply is! String || reply.trim().isEmpty) {
    return (reply: raw, action: null, actionRaw: null, reason: 'parse_gagal');
  }
  final reason = validateChatActionReason(
    m['action'],
    wallets: wallets,
    categories: categories,
  );
  if (reason != null) {
    return (
      reply: reply,
      action: null,
      actionRaw: lenientActionMap(m['action']),
      reason: reason,
    );
  }
  final action = validateChatAction(
    m['action'],
    wallets: wallets,
    categories: categories,
  );
  return (reply: reply, action: action, actionRaw: null, reason: null);
}

/// Data untuk kartu fallback: aksi ditolak validasi padahal reply
/// menjanjikan konfirmasi. Murni (tanpa Flutter) agar testable.
/// Tidak ada simpan otomatis; kartu hanya prefill + picker.
class PendingChatAction {
  /// 'in' | 'out' | 'transfer' (default 'out' bila mentah tak valid).
  final String type;

  /// Nominal valid (>0). 0 bila tak valid (lalu [fixable] false).
  final int amount;

  /// Nama dompet tervalidasi, atau null bila bermasalah/kosong.
  final String? walletOk;

  /// Nama kategori tervalidasi, atau null bila bermasalah/kosong.
  final String? categoryOk;

  /// Nilai dompet mentah yang ditolak (untuk pesan), atau null.
  final String? walletBad;

  /// Nilai kategori mentah yang ditolak (untuk pesan), atau null.
  final String? categoryBad;

  final String? note;

  /// Kode alasan dari [validateChatActionReason].
  final String reason;

  /// True bila bisa diperbaiki user via picker (wallet/kategori).
  final bool fixable;

  /// Daftar dompet valid untuk dropdown perbaikan.
  final List<String> walletOptions;

  /// Daftar kategori valid untuk dropdown perbaikan.
  final List<String> categoryOptions;

  const PendingChatAction({
    required this.type,
    required this.amount,
    this.walletOk,
    this.categoryOk,
    this.walletBad,
    this.categoryBad,
    this.note,
    required this.reason,
    required this.fixable,
    this.walletOptions = const [],
    this.categoryOptions = const [],
  });
}

/// Haruskah app menampilkan kartu fallback (jangan buang diam-diam)?
/// Ya bila action null/ditolak DAN reply menjanjikan konfirmasi.
/// Murni agar testable.
bool shouldShowActionFallback({
  required Map<String, dynamic>? action,
  required String? reason,
  required String reply,
}) {
  if (action != null) return false;
  if (reason == null) return false;
  return replyPromisesConfirmation(reply);
}

/// Bangun [PendingChatAction] dari aksi mentah yang ditolak.
/// - reason wallet_*/kategori_* -> fixable (picker).
/// - reason lain -> fixable=false (hanya pesan jelas).
/// Null bila data pokok (type/amount) tak bisa dipakai.
/// Murni agar testable. Tak pernah throw.
PendingChatAction? buildPendingChatAction({
  required String reason,
  required Map<String, dynamic>? raw,
  required List<String> walletNames,
  required List<String> categories,
}) {
  const fixableReasons = {
    'wallet_tidak_cocok',
    'wallet_kosong',
    'kategori_tidak_cocok',
    'kategori_kosong',
  };
  if (!fixableReasons.contains(reason)) {
    return PendingChatAction(
      type: 'out',
      amount: 0,
      reason: reason,
      fixable: false,
      walletOptions: walletNames,
      categoryOptions: categories,
    );
  }
  final type = (raw?['type'] is String &&
          (raw!['type'] == 'in' ||
              raw['type'] == 'out' ||
              raw['type'] == 'transfer'))
      ? raw['type'] as String
      : 'out';
  final amount = raw?['amount'];
  if (amount is! int || amount <= 0) {
    return PendingChatAction(
      type: type,
      amount: 0,
      reason: 'amount_invalid',
      fixable: false,
      walletOptions: walletNames,
      categoryOptions: categories,
    );
  }
  String? walletOk;
  String? walletBad;
  final wRaw = raw?['wallet'];
  if (wRaw is String && wRaw.trim().isNotEmpty) {
    final w = wRaw.trim();
    if (walletNames.isEmpty) {
      walletOk = w;
    } else {
      final hit = matchWalletName(w, walletNames);
      if (hit != null) {
        walletOk = hit;
      } else {
        walletBad = w;
      }
    }
  }
  String? categoryOk;
  String? categoryBad;
  final cRaw = raw?['category'];
  if (cRaw is String && cRaw.trim().isNotEmpty) {
    final c = cRaw.trim();
    if (categories.isEmpty) {
      categoryOk = c;
    } else {
      for (final k in categories) {
        if (k.toLowerCase() == c.toLowerCase()) {
          categoryOk = k;
          break;
        }
      }
      if (categoryOk == null) categoryBad = c;
    }
  }
  final noteRaw = raw?['note'];
  final note = noteRaw is String && noteRaw.trim().isNotEmpty
      ? noteRaw.trim()
      : null;
  return PendingChatAction(
    type: type,
    amount: amount,
    walletOk: walletOk,
    categoryOk: categoryOk,
    walletBad: walletBad,
    categoryBad: categoryBad,
    note: note,
    reason: reason,
    fixable: true,
    walletOptions: walletNames,
    categoryOptions: categories,
  );
}
