import 'package:ssr_space/services/error_reporter.dart';
import 'package:ssr_space/services/supabase_config.dart';

/// Feature flag / konfigurasi aplikasi sederhana via tabel Supabase
/// `app_config` (key TEXT PK, value TEXT, updated_at).
/// Fondasi untuk rollout bertahap & kill-switch fitur besar berikutnya.
///
/// Fail-closed: bila config tak terbaca (offline / error / migration 25
/// belum dijalankan), flag dianggap MATI kecuali [defaultValue] disebut
/// eksplisit. Nilai '1'/'true'/'on'/'ya' (case-insensitive) = nyala.
class AppConfigService {
  AppConfigService();

  Map<String, String> _cache = const {};
  DateTime? _loadedAt;
  static const _ttl = Duration(hours: 1);

  /// Ambil ulang dari Supabase (cache 1 jam; [force] abaikan cache).
  /// Gagal = cache lama dipertahankan; belum pernah load = kosong.
  Future<void> refresh({bool force = false}) async {
    if (!force &&
        _loadedAt != null &&
        DateTime.now().difference(_loadedAt!) < _ttl) {
      return;
    }
    try {
      final rows =
          await SupabaseConfig.client.from('app_config').select('key, value');
      final map = <String, String>{};
      for (final r in (rows as List)) {
        final k = (r['key'] ?? '').toString();
        if (k.isEmpty) continue;
        map[k] = (r['value'] ?? '').toString();
      }
      _cache = map;
      _loadedAt = DateTime.now();
    } catch (e, st) {
      ErrorReporter.capture(e, st, context: 'app_config_refresh');
    }
  }

  bool isEnabled(String key, {bool defaultValue = false}) {
    final v = _cache[key]?.trim().toLowerCase();
    if (v == null) return defaultValue;
    return v == '1' || v == 'true' || v == 'on' || v == 'ya';
  }

  String getString(String key, {String defaultValue = ''}) =>
      _cache[key] ?? defaultValue;

  /// Untuk test: inject nilai langsung tanpa Supabase.
  void debugSeed(Map<String, String> values) {
    _cache = Map.of(values);
    _loadedAt = DateTime.now();
  }

  /// Untuk test: kosongkan cache.
  void debugReset() {
    _cache = const {};
    _loadedAt = null;
  }
}
