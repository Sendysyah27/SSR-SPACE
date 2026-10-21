import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';
import 'package:ssr_space/services/supabase_config.dart';
import 'package:ssr_space/utils/org_prefs.dart';

// Memori alias merchant (batch 281D tahap 2, pola user_merchant_aliases
// Ollo): teks merchant/catatan yang berulang dipetakan ke kategori +
// dompet final pilihan user. Alias terisi dari pencatatan terkonfirmasi
// (nilai final, termasuk hasil koreksi kartu) lalu disuntikkan sebagai
// hint kuat ke prompt Mode Catat. Lokal dulu (SharedPreferences),
// sinkron best-effort ke tabel user_merchant_aliases (migration_28).
// Semua jalur fail-open.

const _kMerchantAliases = 'ai_merchant_aliases';

/// Batas simpan lokal (soft-limit purge ala Ollo).
const merchantAliasCap = 100;

/// Ambang kemiripan trigram untuk pencocokan mirip.
const aliasTrigramThreshold = 0.35;

class MerchantAlias {
  final String key;
  final String? category;
  final String? wallet;
  final int count;
  final String lastUsed;

  const MerchantAlias({
    required this.key,
    this.category,
    this.wallet,
    required this.count,
    required this.lastUsed,
  });

  Map<String, dynamic> toJson() => {
        'key': key,
        'category': category,
        'wallet': wallet,
        'count': count,
        'lastUsed': lastUsed,
      };

  factory MerchantAlias.fromJson(Map<String, dynamic> m) => MerchantAlias(
        key: (m['key'] ?? '').toString(),
        category: m['category']?.toString(),
        wallet: m['wallet']?.toString(),
        count: m['count'] is num ? (m['count'] as num).toInt() : 1,
        lastUsed: (m['lastUsed'] ?? '').toString(),
      );
}

const _aliasStopwords = {
  'di', 'ke', 'dari', 'beli', 'bayar', 'untuk', 'via', 'pakai', 'pake',
  'dan', 'yang', 'ini', 'itu', 'tadi', 'lagi', 'sama', 'dengan', 'rp',
};

/// Normalisasi teks -> kunci alias. MURNI: lowercase, non-alfanumerik
/// jadi spasi, buang kata umum, maks 4 token pertama.
String normalizeMerchantKey(String raw) {
  final cleaned = raw.toLowerCase().replaceAll(RegExp(r'[^a-z0-9]+'), ' ');
  final tokens = [
    for (final t in cleaned.split(RegExp(r'\s+')))
      if (t.isNotEmpty && !_aliasStopwords.contains(t)) t,
  ];
  return tokens.take(4).join(' ');
}

Set<String> _trigrams(String s) {
  final padded = '  $s ';
  final out = <String>{};
  for (var i = 0; i + 3 <= padded.length; i++) {
    out.add(padded.substring(i, i + 3));
  }
  return out;
}

/// Kemiripan trigram (Jaccard) ala Postgres pg_trgm. MURNI.
double trigramSimilarity(String a, String b) {
  final x = normalizeMerchantKey(a);
  final y = normalizeMerchantKey(b);
  if (x.isEmpty || y.isEmpty) return 0;
  if (x == y) return 1;
  final sx = _trigrams(x);
  final sy = _trigrams(y);
  if (sx.isEmpty || sy.isEmpty) return 0;
  final inter = sx.intersection(sy).length;
  final union = sx.length + sy.length - inter;
  return union == 0 ? 0 : inter / union;
}

/// Cari alias paling cocok untuk teks user. MURNI: kandidat = kunci
/// sama persis, kunci alias terkandung di kunci teks (atau sebaliknya),
/// atau kemiripan trigram >= [aliasTrigramThreshold]. Pilih count
/// tertinggi; seri -> kemiripan tertinggi.
MerchantAlias? findAliasFor(String text, List<MerchantAlias> aliases) {
  final key = normalizeMerchantKey(text);
  if (key.isEmpty) return null;
  MerchantAlias? best;
  var bestScore = -1.0;
  for (final a in aliases) {
    if (a.key.isEmpty) continue;
    double? score;
    if (a.key == key) {
      score = 1.0;
    } else if (key.contains(a.key) || a.key.contains(key)) {
      score = 0.9;
    } else {
      final sim = trigramSimilarity(a.key, key);
      if (sim >= aliasTrigramThreshold) score = sim;
    }
    if (score == null) continue;
    if (best == null ||
        a.count > best.count ||
        (a.count == best.count && score > bestScore)) {
      best = a;
      bestScore = score;
    }
  }
  return best;
}

/// Blok hint yang disuntikkan ke prompt Mode Catat. MURNI.
String aliasHintBlock(MerchantAlias a) {
  final cat = a.category ?? 'kategori pilihan user sebelumnya';
  final wal = a.wallet == null ? '' : ' dompet ${a.wallet}';
  return 'PETUNJUK KEBIASAAN USER: catatan/merchant mirip "${a.key}" '
      'biasanya dicatat sebagai kategori $cat$wal (sudah ${a.count}x). '
      'Utamakan saran ini untuk action-nya, kecuali user menyebut '
      'kategori/dompet lain secara eksplisit.';
}

Future<List<MerchantAlias>> loadMerchantAliases() async {
  try {
    final p = await SharedPreferences.getInstance();
    final raw = p.getString(_kMerchantAliases);
    if (raw == null || raw.isEmpty) return [];
    final d = jsonDecode(raw);
    if (d is! List) return [];
    return [
      for (final e in d)
        if (e is Map) MerchantAlias.fromJson(Map<String, dynamic>.from(e)),
    ];
  } catch (_) {
    return [];
  }
}

Future<void> _saveMerchantAliases(List<MerchantAlias> items) async {
  final p = await SharedPreferences.getInstance();
  await p.setString(
    _kMerchantAliases,
    jsonEncode([for (final a in items) a.toJson()]),
  );
}

/// Catat pemakaian alias dari pencatatan terkonfirmasi (nilai final
/// user). Kunci kosong -> no-op. Cap [merchantAliasCap]: buang count
/// terkecil (seri: lastUsed terlama).
Future<void> upsertMerchantAlias({
  required String sourceText,
  String? category,
  String? wallet,
}) async {
  try {
    final key = normalizeMerchantKey(sourceText);
    if (key.isEmpty) return;
    final items = await loadMerchantAliases();
    final now = DateTime.now().toIso8601String();
    final i = items.indexWhere((a) => a.key == key);
    if (i >= 0) {
      final old = items[i];
      items[i] = MerchantAlias(
        key: key,
        category: category ?? old.category,
        wallet: wallet ?? old.wallet,
        count: old.count + 1,
        lastUsed: now,
      );
    } else {
      items.add(MerchantAlias(
        key: key,
        category: category,
        wallet: wallet,
        count: 1,
        lastUsed: now,
      ));
    }
    while (items.length > merchantAliasCap) {
      var worst = 0;
      for (var j = 1; j < items.length; j++) {
        if (items[j].count < items[worst].count ||
            (items[j].count == items[worst].count &&
                items[j].lastUsed.compareTo(items[worst].lastUsed) < 0)) {
          worst = j;
        }
      }
      items.removeAt(worst);
    }
    await _saveMerchantAliases(items);
  } catch (_) {}
}

/// Sinkron best-effort semua alias lokal ke tabel user_merchant_aliases
/// (upsert per kunci unik org+user+merchant_key). Tak pernah throw.
Future<void> syncMerchantAliases() async {
  try {
    final client = SupabaseConfig.client;
    final uid = client.auth.currentUser?.id;
    if (uid == null) return;
    final orgId = await activeOrgId();
    if (orgId.isEmpty) return;
    final items = await loadMerchantAliases();
    if (items.isEmpty) return;
    await client.from('user_merchant_aliases').upsert(
      [
        for (final a in items)
          {
            'org_id': orgId,
            'user_id': uid,
            'merchant_key': a.key,
            'category': a.category,
            'wallet_name': a.wallet,
            'use_count': a.count,
            'last_used_at': a.lastUsed,
          },
      ],
      onConflict: 'org_id,user_id,merchant_key',
    );
  } catch (_) {}
}
