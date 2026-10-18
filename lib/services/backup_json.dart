/// Backup JSON penuh + rencana restore (Batch 9 Sprint). Murni Dart.
/// Format file: {app:'ssr-space', format:1, exportedAt, org:{id,name},
/// wallets:[{id,name,type}], transactions:[row], budgets:[{...}]}.
class BackupInvalid implements Exception {
  /// bad-root | bad-app | bad-version
  final String reason;
  const BackupInvalid(this.reason);
  @override
  String toString() => 'BackupInvalid($reason)';
}

/// Maks transaksi per restore (lindungi kuota/egress/waktu).
const restoreTxCap = 2000;

/// Maks transaksi per export backup JSON. DISAMAKAN dengan restoreTxCap
/// (fix #10): dulu export 3000 vs restore 2000, sehingga backup tak bisa
/// di-restore utuh karena dipotong diam-diam.
const backupExportTxCap = restoreTxCap;

Map<String, dynamic> buildBackup({
  required String orgId,
  required String orgName,
  required List<Map<String, dynamic>> wallets,
  required List<Map<String, dynamic>> txs,
  required List<Map<String, dynamic>> budgets,
  DateTime? now,
}) =>
    {
      'app': 'ssr-space',
      'format': 1,
      'exportedAt': (now ?? DateTime.now()).toUtc().toIso8601String(),
      'org': {'id': orgId, 'name': orgName},
      'wallets': wallets,
      'transactions': txs,
      'budgets': budgets,
    };

class ParsedBackup {
  final String orgId;
  final String orgName;
  final List<Map<String, dynamic>> wallets;
  final List<Map<String, dynamic>> txs;
  final List<Map<String, dynamic>> budgets;
  const ParsedBackup({
    required this.orgId,
    required this.orgName,
    required this.wallets,
    required this.txs,
    required this.budgets,
  });
}

List<Map<String, dynamic>> _mapList(dynamic v) {
  if (v is! List) throw const BackupInvalid('bad-root');
  return [
    for (final r in v)
      if (r is Map) Map<String, dynamic>.from(r),
  ];
}

/// Validasi ketat: root/app/format salah → lempar (fail-closed).
ParsedBackup parseBackup(dynamic raw) {
  if (raw is! Map) throw const BackupInvalid('bad-root');
  final m = Map<String, dynamic>.from(raw);
  if (m['app'] != 'ssr-space') throw const BackupInvalid('bad-app');
  if (m['format'] != 1) throw const BackupInvalid('bad-version');
  final org = m['org'];
  if (org is! Map) throw const BackupInvalid('bad-root');
  return ParsedBackup(
    orgId: (org['id'] ?? '').toString(),
    orgName: (org['name'] ?? '').toString(),
    wallets: _mapList(m['wallets']),
    txs: _mapList(m['transactions']),
    budgets: _mapList(m['budgets']),
  );
}

/// Hasil perencanaan restore (sebelum tulis apa pun). Baris selalu
/// berkunci NAMA dompet (id backup tak berlaku di sini); service
/// membuat yang hilang dulu lalu menukar nama jadi id live.
class RestorePlan {
  /// backupWalletId -> liveWalletId (yang cocok nama, case-insensitive).
  final Map<String, String> walletMap;

  /// Nama dompet hilang -> type (untuk dibuat). Key = nama asli.
  final Map<String, String> missingWallets;

  /// Baris tx siap insert: {type, amount, wallet_name, to_wallet_name,
  /// category, note, date, created_at}. to_wallet_name '' = tak ada.
  final List<Map<String, dynamic>> ready;

  /// Baris dilewati (jenis/nominal tak valid, dompet tak dikenal,
  /// transfer tanpa tujuan).
  final int skipped;

  /// True bila daftar dipotong cap.
  final bool capped;
  const RestorePlan({
    required this.walletMap,
    required this.missingWallets,
    required this.ready,
    required this.skipped,
    required this.capped,
  });
}

/// Susun rencana: cocokkan dompet per nama, strip field server
/// (id/code/source/hash/created_by/org), buang baris rusak, potong cap.
RestorePlan planRestore({
  required List<Map<String, dynamic>> backupWallets,
  required List<Map<String, dynamic>> backupTxs,
  required List<Map<String, dynamic>> liveWallets,
  int cap = restoreTxCap,
}) {
  final liveByName = <String, String>{
    for (final w in liveWallets)
      (w['name'] ?? '').toString().trim().toLowerCase():
          (w['id'] ?? '').toString(),
  };
  final backupName = <String, String>{};
  final backupType = <String, String>{};
  for (final w in backupWallets) {
    final id = (w['id'] ?? '').toString();
    final name = (w['name'] ?? '').toString().trim();
    if (id.isEmpty || name.isEmpty) continue;
    backupName[id] = name;
    backupType[name] = (w['type'] ?? 'cash').toString();
  }
  final walletMap = <String, String>{};
  final missingWallets = <String, String>{};
  for (final entry in backupName.entries) {
    final hit = liveByName[entry.value.toLowerCase()];
    if (hit != null && hit.isNotEmpty) {
      walletMap[entry.key] = hit;
    } else {
      missingWallets[entry.value] = backupType[entry.value] ?? 'cash';
    }
  }
  String? nameOf(String backupId) => backupName[backupId];
  final ready = <Map<String, dynamic>>[];
  var skipped = 0;
  for (final t in backupTxs) {
    if (ready.length >= cap) break;
    final type = (t['type'] ?? '').toString();
    if (type != 'in' && type != 'out' && type != 'transfer') {
      skipped++;
      continue;
    }
    final amount = (t['amount'] as num?)?.toDouble() ?? 0;
    if (amount <= 0) {
      skipped++;
      continue;
    }
    final wname = nameOf((t['wallet_id'] ?? '').toString());
    if (wname == null || wname.isEmpty) {
      skipped++;
      continue;
    }
    var toName = '';
    if (type == 'transfer') {
      final tn = nameOf((t['to_wallet_id'] ?? '').toString());
      if (tn == null || tn.isEmpty) {
        skipped++;
        continue;
      }
      toName = tn;
    }
    ready.add({
      'type': type,
      'amount': amount,
      'wallet_name': wname,
      'to_wallet_name': toName,
      'category': (t['category'] ?? '').toString(),
      'note': (t['note'] ?? '').toString(),
      'date': (t['date'] ?? '').toString(),
      'created_at': (t['created_at'] ?? '').toString(),
    });
  }
  return RestorePlan(
    walletMap: walletMap,
    missingWallets: missingWallets,
    ready: ready,
    skipped: skipped,
    capped: backupTxs.length > ready.length + skipped,
  );
}
