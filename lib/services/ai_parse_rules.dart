import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';
import 'package:ssr_space/services/app_config_service.dart';

// Aturan parse dari server (batch 281D tahap 3, pola quick_record_rules
// Ollo): kosakata kategori + petunjuk parse disimpan sebagai JSON di
// tabel app_config kunci 'quick_record_rules' (seed migration_28).
// Mengubah nilai di server (SQL Editor) mengubah perilaku parse TANPA
// rilis app. Fail-open berlapis: server -> cache prefs -> bawaan app.

const _kParseRulesCache = 'ai_parse_rules_cache';

class AiParseRules {
  final int version;
  final Map<String, String> categoryHints;
  final List<String> parseHints;

  const AiParseRules({
    required this.version,
    required this.categoryHints,
    required this.parseHints,
  });

  /// Bawaan app — cermin seed migration_28; dipakai bila server tak
  /// terjangkau dan cache kosong.
  factory AiParseRules.builtin() => const AiParseRules(
        version: 1,
        categoryHints: {
          'kopi': 'Minuman',
          'kopken': 'Minuman',
          'starbucks': 'Minuman',
          'indomaret': 'Belanja',
          'alfamart': 'Belanja',
          'grab': 'Transportasi',
          'gojek': 'Transportasi',
          'spbu': 'Transportasi',
          'pertamina': 'Transportasi',
          'pln': 'Tagihan',
          'pdam': 'Tagihan',
          'apotek': 'Kesehatan',
        },
        parseHints: [
          'Nominal ditulis angka penuh rupiah tanpa titik ribuan.',
          'Catatan/merchant diambil dari teks user apa adanya.',
        ],
      );
}

/// Urai JSON konfigurasi server -> [AiParseRules]. MURNI, fail-open:
/// input null/rusak/bukan Map -> bawaan app. Field yang valid menimpa
/// bawaan per-field (category_hints valid = pakai peta server apa
/// adanya; parse_hints valid = pakai daftar server).
AiParseRules parseQuickRecordRules(String? raw) {
  final base = AiParseRules.builtin();
  if (raw == null || raw.trim().isEmpty) return base;
  dynamic d;
  try {
    d = jsonDecode(raw);
  } catch (_) {
    return base;
  }
  if (d is! Map) return base;
  final m = Map<String, dynamic>.from(d);
  var version = base.version;
  if (m['version'] is num) version = (m['version'] as num).toInt();
  var cats = base.categoryHints;
  final ch = m['category_hints'];
  if (ch is Map && ch.isNotEmpty) {
    final out = <String, String>{};
    ch.forEach((k, v) {
      final key = k.toString().trim().toLowerCase();
      if (key.isNotEmpty && v is String && v.trim().isNotEmpty) {
        out[key] = v.trim();
      }
    });
    if (out.isNotEmpty) cats = out;
  }
  var hints = base.parseHints;
  final ph = m['parse_hints'];
  if (ph is List && ph.isNotEmpty) {
    final out = [
      for (final e in ph)
        if (e is String && e.trim().isNotEmpty) e.trim(),
    ];
    if (out.isNotEmpty) hints = out;
  }
  return AiParseRules(version: version, categoryHints: cats, parseHints: hints);
}

/// Blok aturan yang disuntikkan ke prompt Mode Catat. MURNI, dibatasi
/// agar hemat token (maks 30 kosakata, 5 petunjuk).
String parseRulesBlock(AiParseRules r) {
  final entries = r.categoryHints.entries
      .take(30)
      .map((e) => '"${e.key}" -> ${e.value}')
      .join('; ');
  final hints = r.parseHints.take(5).join(' ');
  return 'ATURAN PARSE DARI SERVER (v${r.version}): kosakata kategori: '
      '$entries. $hints';
}

AiParseRules? _rulesMemCache;
DateTime? _rulesMemCacheAt;
const _rulesTtl = Duration(hours: 1);

/// Muat aturan parse: cache memori (TTL 1 jam) -> server app_config ->
/// cache prefs -> bawaan app. Tak pernah throw.
Future<AiParseRules> loadParseRules({bool force = false}) async {
  final now = DateTime.now();
  if (!force &&
      _rulesMemCache != null &&
      _rulesMemCacheAt != null &&
      now.difference(_rulesMemCacheAt!) < _rulesTtl) {
    return _rulesMemCache!;
  }
  String? cachedRaw;
  try {
    final p = await SharedPreferences.getInstance();
    cachedRaw = p.getString(_kParseRulesCache);
  } catch (_) {}
  try {
    final svc = AppConfigService();
    await svc.refresh();
    final raw = svc.getString('quick_record_rules');
    if (raw.trim().isNotEmpty) {
      final rules = parseQuickRecordRules(raw);
      _rulesMemCache = rules;
      _rulesMemCacheAt = now;
      try {
        final p = await SharedPreferences.getInstance();
        await p.setString(_kParseRulesCache, raw);
      } catch (_) {}
      return rules;
    }
  } catch (_) {}
  final rules = parseQuickRecordRules(cachedRaw);
  _rulesMemCache = rules;
  _rulesMemCacheAt = now;
  return rules;
}
