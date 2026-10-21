// Parser balasan chat Mang AI.
//
// Kontrak model (lihat LocalOpenCodeProvider.DEFAULT_SYSTEM + aiSoul):
//   {"reply":"<teks untuk user>","action":null}
//   {"reply":"...","action":{"type":"in|out|transfer","amount":<int>,
//     "category":"...","wallet":"...","note":"..."}}
//   {"reply":"...","action":{"type":"navigate","target":"<id>"}}
//     (perintah non-transaksi batch 281 - lihat validateChatCommand).
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
  final target = m['target'];
  if (target is String && target.trim().isNotEmpty) {
    out['target'] = target.trim();
  }
  final name = m['name'];
  if (name is String && name.trim().isNotEmpty) out['name'] = name.trim();
  final wtype = m['wallet_type'];
  if (wtype is String && wtype.trim().isNotEmpty) {
    out['wallet_type'] = wtype.trim();
  }
  final opening = m['opening_balance'];
  if (opening is int && opening >= 0) out['opening_balance'] = opening;
  final kind = m['kind'];
  if (kind is String && kind.trim().isNotEmpty) out['kind'] = kind.trim();
  return out;
}

/// Apakah teks reply menjanjikan tombol/konfirmasi ke user?
/// Dipakai untuk fallback: jangan buang aksi yang ditolak diam-diam
/// bila model sudah berjanji ada tombol.
bool replyPromisesConfirmation(String reply) {
  final t = reply.toLowerCase();
  return t.contains('konfirmasi') || t.contains('jalankan');
}

/// Ekstrak objek kontrak {"reply":...} dari teks yang dibungkus prosa /
/// fence di tengah kalimat (model free kadang melanggar format). Pindai
/// kurung seimbang (sadar string + escape) dari kemunculan TERAKHIR
/// '{"reply"'. Null bila tak ada objek kontrak yang bisa di-decode.
/// Murni; tak pernah throw. Pola sama seperti normalisasi server v3.
Map<String, dynamic>? extractContractJson(String s) {
  var idx = s.lastIndexOf('{"reply"');
  while (idx >= 0) {
    var depth = 0;
    var inStr = false;
    var esc = false;
    var end = -1;
    for (var i = idx; i < s.length; i++) {
      final c = s[i];
      if (inStr) {
        if (esc) {
          esc = false;
        } else if (c == '\\') {
          esc = true;
        } else if (c == '"') {
          inStr = false;
        }
      } else {
        if (c == '"') {
          inStr = true;
        } else if (c == '{') {
          depth++;
        } else if (c == '}') {
          depth--;
          if (depth == 0) {
            end = i;
            break;
          }
        }
      }
    }
    if (end > idx) {
      try {
        final j = jsonDecode(s.substring(idx, end + 1));
        if (j is Map) {
          final m = Map<String, dynamic>.from(j);
          final r = m['reply'];
          if (r is String && r.trim().isNotEmpty) return m;
        }
      } catch (_) {}
    }
    idx = idx > 0 ? s.lastIndexOf('{"reply"', idx - 1) : -1;
  }
  return null;
}

/// Target navigasi yang didukung action {"type":"navigate"} (281).
/// Id -> layar yang benar-benar ada di app (audit route 2026-10-21):
/// nfc=NfcCardsScreen, laporan=ReportsScreen, billing=BillingScreen,
/// dompet=WalletsScreen, kategori=CategoriesScreen,
/// anggaran=BudgetsScreen, tagihan=RecurringBillsScreen,
/// profil=SettingsScreen (hub Profil).
const kChatNavTargets = <String>{
  'nfc',
  'laporan',
  'billing',
  'dompet',
  'kategori',
  'anggaran',
  'tagihan',
  'profil',
};

/// Tipe action perintah non-transaksi yang dikenal (batch 281).
const kChatCommandTypes = <String>{
  'navigate',
  'add_wallet',
  'add_category',
  'edit_last',
  'delete_last',
};

/// Jenis kartu visualisasi Mode Asisten (281C tahap 2 + 285 tahap C).
/// Model hanya memilih jenis (+ limit sederhana); angka dirender app
/// dari snapshot lokal — tidak pernah dari teks/angka model.
const kChatVizTypes = <String>{
  'saldo',
  'rincian_kategori',
  'tren_ringkas',
  'banding_periode',
  'tren_30',
  'top_merchant',
  'progres_target',
};

/// Urai blok "viz" dari kontrak balasan -> peta ternormalisasi atau
/// null (tak ada / bukan Map / type tak dikenal). Murni; tak pernah
/// throw. Field selain type/limit dibuang.
Map<String, dynamic>? parseChatViz(dynamic raw) {
  if (raw is! Map) return null;
  final m = Map<String, dynamic>.from(raw);
  final t = m['type'];
  if (t is! String || !kChatVizTypes.contains(t.trim())) return null;
  final out = <String, dynamic>{'type': t.trim()};
  final limit = m['limit'];
  if (limit is int && limit >= 1 && limit <= 8) out['limit'] = limit;
  return out;
}

/// Tipe dompet yang dikenal app (form dompet manual + WalletService).
const kChatWalletTypes = <String>{'cash', 'ewallet', 'bank', 'investment'};

/// Validasi action perintah non-transaksi -> kode alasan atau null.
/// - navigate: target wajib salah satu [kChatNavTargets] (selain itu
///   'target_invalid' -> action diabaikan aman, teks tetap tampil).
/// - add_wallet: name non-kosong ('nama_kosong'), belum ada di daftar
///   dompet ('dompet_sudah_ada'), wallet_type dikenal bila diisi
///   ('tipe_dompet_invalid'), opening_balance int >= 0 bila diisi
///   ('saldo_awal_invalid').
/// - add_category: name non-kosong ('nama_kosong'), belum ada di daftar
///   kategori ('kategori_sudah_ada'), kind in/out bila diisi
///   ('kind_invalid'; skema kategori app tak membedakan arah - kind
///   hanya keterangan, tidak disimpan).
/// - edit_last: minimal satu field berubah ('edit_kosong'); field yang
///   diisi divalidasi seperti action tx (amount int > 0, kategori dari
///   daftar, dompet fuzzy-match, note string - boleh '' = hapus catatan).
/// - delete_last: tanpa field; selalu valid di parser (ketersediaan
///   transaksi terakhir dicek eksekutor di layar).
/// Murni; tak pernah throw.
String? validateChatCommandReason(
  dynamic raw, {
  List<String> wallets = const [],
  List<String> categories = const [],
}) {
  if (raw == null) return 'action_null';
  if (raw is! Map) return 'action_null';
  final m = Map<String, dynamic>.from(raw);
  final type = m['type'];
  if (type == 'navigate') {
    final t = m['target'];
    if (t is! String || !kChatNavTargets.contains(t.trim())) {
      return 'target_invalid';
    }
    return null;
  }
  if (type == 'add_wallet') {
    final name = m['name'];
    if (name is! String || name.trim().isEmpty) return 'nama_kosong';
    final n = name.trim().toLowerCase();
    for (final w in wallets) {
      if (w.toLowerCase() == n) return 'dompet_sudah_ada';
    }
    final wt = m['wallet_type'];
    if (wt != null && (wt is! String || !kChatWalletTypes.contains(wt.trim()))) {
      return 'tipe_dompet_invalid';
    }
    final ob = m['opening_balance'];
    if (ob != null && (ob is! int || ob < 0)) return 'saldo_awal_invalid';
    return null;
  }
  if (type == 'add_category') {
    final name = m['name'];
    if (name is! String || name.trim().isEmpty) return 'nama_kosong';
    final n = name.trim().toLowerCase();
    for (final c in categories) {
      if (c.toLowerCase() == n) return 'kategori_sudah_ada';
    }
    final kind = m['kind'];
    if (kind != null && kind != 'in' && kind != 'out') return 'kind_invalid';
    return null;
  }
  if (type == 'edit_last') {
    final hasAmount = m['amount'] != null;
    final hasCategory = m['category'] != null;
    final hasWallet = m['wallet'] != null;
    final hasNote = m['note'] != null;
    if (!hasAmount && !hasCategory && !hasWallet && !hasNote) {
      return 'edit_kosong';
    }
    if (hasAmount) {
      final a = m['amount'];
      if (a is! int || a <= 0) return 'amount_invalid';
    }
    if (hasCategory) {
      final c = m['category'];
      if (c is! String || c.trim().isEmpty) return 'kategori_kosong';
      if (categories.isNotEmpty) {
        var hit = false;
        for (final k in categories) {
          if (k.toLowerCase() == c.trim().toLowerCase()) {
            hit = true;
            break;
          }
        }
        if (!hit) return 'kategori_tidak_cocok';
      }
    }
    if (hasWallet) {
      final w = m['wallet'];
      if (w is! String || w.trim().isEmpty) return 'wallet_kosong';
      if (wallets.isNotEmpty && matchWalletName(w.trim(), wallets) == null) {
        return 'wallet_tidak_cocok';
      }
    }
    if (hasNote && m['note'] is! String) return 'note_invalid';
    return null;
  }
  if (type == 'delete_last') {
    return null;
  }
  return 'type_invalid';
}

/// Normalisasi action perintah yang valid; null bila tak valid.
Map<String, dynamic>? validateChatCommand(
  dynamic raw, {
  List<String> wallets = const [],
  List<String> categories = const [],
}) {
  if (validateChatCommandReason(raw, wallets: wallets, categories: categories) !=
      null) {
    return null;
  }
  final m = Map<String, dynamic>.from(raw as Map);
  final type = m['type'];
  if (type == 'navigate') {
    return {'type': 'navigate', 'target': (m['target'] as String).trim()};
  }
  if (type == 'add_wallet') {
    final wt = m['wallet_type'];
    final ob = m['opening_balance'];
    return {
      'type': 'add_wallet',
      'name': (m['name'] as String).trim(),
      'wallet_type': wt is String ? wt.trim() : 'cash',
      'opening_balance': ob is int ? ob : 0,
    };
  }
  if (type == 'add_category') {
    final kind = m['kind'];
    return {
      'type': 'add_category',
      'name': (m['name'] as String).trim(),
      if (kind is String) 'kind': kind,
    };
  }
  if (type == 'edit_last') {
    final out = <String, dynamic>{'type': 'edit_last'};
    final a = m['amount'];
    if (a is int) out['amount'] = a;
    final c = m['category'];
    if (c is String) {
      var cat = c.trim();
      for (final k in categories) {
        if (k.toLowerCase() == cat.toLowerCase()) {
          cat = k;
          break;
        }
      }
      out['category'] = cat;
    }
    final w = m['wallet'];
    if (w is String) {
      var wal = w.trim();
      if (wallets.isNotEmpty) {
        wal = matchWalletName(wal, wallets) ?? wal;
      }
      out['wallet'] = wal;
    }
    final n = m['note'];
    if (n is String) out['note'] = n.trim();
    return out;
  }
  if (type == 'delete_last') {
    return {'type': 'delete_last'};
  }
  return null;
}

/// Urai balasan mentah model -> (reply, action, actionRaw, reason).
/// Field command: action perintah non-transaksi tervalidasi (navigate
/// dst., batch 281) - saluran terpisah dari action transaksi.
/// Field viz: blok visualisasi Mode Asisten tervalidasi (281C tahap 2),
/// independen dari action — viz tak valid cukup dibuang, reply utuh.
/// - JSON valid berkontrak: kembalikan field `reply` SAJA sebagai teks
///   bubble; JSON mentah tidak pernah tampil ke user.
/// - Parse gagal (bukan JSON / bukan Map / tanpa `reply` string):
///   kembalikan teks asli apa adanya, action null, reason 'parse_gagal'.
/// - action null eksplisit: reason 'action_null'.
/// - action ditolak validasi: reason = kode dari [validateChatActionReason],
///   actionRaw = salinan lenient untuk prefill fallback.
/// Tak pernah throw. Tak pernah log isi pesan.
({String reply, Map<String, dynamic>? action, Map<String, dynamic>? actionRaw, String? reason, Map<String, dynamic>? command, Map<String, dynamic>? viz}) parseChatReply(
  String raw, {
  List<String> wallets = const [],
  List<String> categories = const [],
}) {
  final clean = _stripFence(raw.trim());
  dynamic decoded;
  try {
    decoded = jsonDecode(clean);
  } catch (_) {
    decoded = null;
  }
  if (decoded is! Map) {
    // Lenient (281): kontrak mungkin terbungkus prosa / fence di tengah
    // teks - ekstrak objeknya; gagal juga -> teks asli apa adanya.
    decoded = extractContractJson(clean);
  }
  if (decoded is! Map) {
    return (
      reply: raw,
      action: null,
      actionRaw: null,
      reason: 'parse_gagal',
      command: null,
      viz: null,
    );
  }
  final m = Map<String, dynamic>.from(decoded);
  final reply = m['reply'];
  if (reply is! String || reply.trim().isEmpty) {
    return (
      reply: raw,
      action: null,
      actionRaw: null,
      reason: 'parse_gagal',
      command: null,
      viz: null,
    );
  }
  final viz = parseChatViz(m['viz']);
  // Saluran perintah non-transaksi (batch 281): type yang dikenal
  // sebagai command divalidasi di jalurnya sendiri; type asing lain
  // tetap jatuh ke jalur tx dan ditolak 'type_invalid' seperti biasa.
  final rawAction = m['action'];
  if (rawAction is Map) {
    final t = rawAction['type'];
    if (t is String && kChatCommandTypes.contains(t)) {
      final cReason = validateChatCommandReason(
        rawAction,
        wallets: wallets,
        categories: categories,
      );
      if (cReason != null) {
        return (
          reply: reply,
          action: null,
          actionRaw: lenientActionMap(rawAction),
          reason: cReason,
          command: null,
          viz: viz,
        );
      }
      return (
        reply: reply,
        action: null,
        actionRaw: null,
        reason: null,
        command: validateChatCommand(
          rawAction,
          wallets: wallets,
          categories: categories,
        ),
        viz: viz,
      );
    }
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
      command: null,
      viz: viz,
    );
  }
  final action = validateChatAction(
    m['action'],
    wallets: wallets,
    categories: categories,
  );
  return (reply: reply, action: action, actionRaw: null, reason: null, command: null, viz: viz);
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
