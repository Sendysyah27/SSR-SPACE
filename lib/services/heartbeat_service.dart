import 'package:shared_preferences/shared_preferences.dart';
import 'package:ssr_space/services/supabase_config.dart';

const _kHeartbeatLast = 'heartbeat_last_ymd';

/// Sentuh heartbeat anti-pause max 1/hari/device (Batch 5 Sprint).
/// Tak pernah melempar: offline / belum migration_18 / logout = diam.
/// Dipanggil fire-and-forget dari main() setiap start.
Future<void> touchHeartbeatDaily() async {
  try {
    if (SupabaseConfig.client.auth.currentSession == null) return;
    final now = DateTime.now();
    final today =
        '${now.year.toString().padLeft(4, '0')}-'
        '${now.month.toString().padLeft(2, '0')}-'
        '${now.day.toString().padLeft(2, '0')}';
    final prefs = await SharedPreferences.getInstance();
    if (prefs.getString(_kHeartbeatLast) == today) return;
    await SupabaseConfig.client
        .rpc('touch_heartbeat', params: {'p_source': 'app-start'});
    await prefs.setString(_kHeartbeatLast, today);
  } catch (_) {}
}
