import 'package:shared_preferences/shared_preferences.dart';
import 'package:ssr_space/services/space_logic.dart';
import 'package:ssr_space/services/supabase_config.dart';
import 'package:ssr_space/services/pg_trigger_codes.dart';
import 'package:ssr_space/utils/strings.dart';

class SpaceException implements Exception {
  final String message;
  SpaceException(this.message);
  @override
  String toString() => message;
}

class SpaceActivity {
  final String event;
  final String? actorId;
  final Map<String, dynamic> meta;
  final DateTime at;
  const SpaceActivity(this.event, this.actorId, this.meta, this.at);
}

class SpaceService {
  /// Mode workspace. Fail-open 'bebas' bila query gagal (baca tetap jalan).
  Future<String> getMode(String orgId) async {
    try {
      final row = await SupabaseConfig.client
          .from('organizations')
          .select('space_mode')
          .eq('id', orgId)
          .maybeSingle();
      return parseSpaceMode(row?['space_mode']);
    } catch (_) {
      return 'bebas';
    }
  }

  /// Ganti mode via RPC (server wajib owner/admin). Map error RPC ke pesan lokal.
  Future<void> setMode(String orgId, String mode) async {
    try {
      await SupabaseConfig.client.rpc(
        'set_space_mode',
        params: {'p_org_id': orgId, 'p_mode': mode},
      );
    } on Exception catch (err) {
      if (pgIsNotAdmin(err)) throw SpaceException(tr('sp_adminonly'));
      if (pgIsBadMode(err)) throw SpaceException(tr('sp_badmode'));
      rethrow;
    }
  }

  Future<List<SpaceActivity>> activity(String orgId, {int limit = 100}) async {
    final rows = await SupabaseConfig.client
        .from('audit_logs')
        .select('event, actor_user_id, meta, created_at')
        .eq('org_id', orgId)
        .order('created_at', ascending: false)
        .limit(limit);
    final out = <SpaceActivity>[];
    for (final m in List<Map<String, dynamic>>.from(rows)) {
      // created_at malformed -> baris log ini dilewati, bukan menumbangkan
      // seluruh daftar aktivitas (pola sama: transaction_service tryFromMap).
      final ts = DateTime.tryParse((m['created_at'] ?? '').toString());
      if (ts == null) continue;
      out.add(
        SpaceActivity(
          (m['event'] ?? '').toString(),
          m['actor_user_id']?.toString(),
          Map<String, dynamic>.from(m['meta'] ?? {}),
          ts.toLocal(),
        ),
      );
    }
    return out;
  }

  Future<DateTime?> lastSeen(String orgId) async {
    final p = await SharedPreferences.getInstance();
    final raw = p.getString(spaceSeenKey(orgId));
    return raw == null ? null : DateTime.tryParse(raw);
  }

  Future<void> markSeen(String orgId) async {
    final p = await SharedPreferences.getInstance();
    await p.setString(spaceSeenKey(orgId), DateTime.now().toIso8601String());
  }
}
