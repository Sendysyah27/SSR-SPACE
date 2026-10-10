import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:ssr_space/services/supabase_config.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

/// Topik channel per org aktif. Murni (testable).
String realtimeTopic(String orgId) => 'org-sync-$orgId';

/// Tabel yang memicu muat-ulang. Murni (testable).
bool isSyncTable(String table) =>
    table == 'transactions' ||
    table == 'org_members' ||
    table == 'wallets' ||
    table == 'budgets';

const _syncTables = <String>[
  'transactions',
  'org_members',
  'wallets',
  'budgets',
];

/// Sinkron realtime workspace aktif (Batch 6 Sprint).
/// Satu channel per org; ledakan event digabung 2 detik → satu reload UI.
/// Gagal/offline/logout = diam: fallback = reload saat resume (sudah ada).
class RealtimeSync {
  RealtimeSync._();
  static RealtimeChannel? _ch;
  static String? _orgId;
  static bool _subscribed = false;
  static Timer? _debounce;

  /// Pastikan subscribe org [orgId]; pindah org = ganti channel.
  /// [onBurst] dipanggil max 1x/2 detik saat ada perubahan data.
  static Future<void> ensure(
    String orgId, {
    required VoidCallback onBurst,
  }) async {
    try {
      if (SupabaseConfig.client.auth.currentSession == null) return;
      if (orgId.isEmpty) return;
      if (_subscribed && _orgId == orgId) return;
      await stop();
      final ch = SupabaseConfig.client.channel(realtimeTopic(orgId));
      for (final t in _syncTables) {
        ch.onPostgresChanges(
          event: PostgresChangeEvent.all,
          schema: 'public',
          table: t,
          filter: PostgresChangeFilter(
            type: PostgresChangeFilterType.eq,
            column: 'org_id',
            value: orgId,
          ),
          callback: (_) => _ping(onBurst),
        );
      }
      ch.subscribe((status, [err]) {
        if (status == RealtimeSubscribeStatus.subscribed) {
          _subscribed = true;
          _orgId = orgId;
        } else if (status == RealtimeSubscribeStatus.channelError ||
            status == RealtimeSubscribeStatus.timedOut) {
          debugPrint('realtime status: $status $err');
        }
      });
      _ch = ch;
    } catch (e) {
      debugPrint('realtime ensure gagal: $e');
    }
  }

  static void _ping(VoidCallback onBurst) {
    _debounce?.cancel();
    _debounce = Timer(const Duration(seconds: 2), onBurst);
  }

  /// Berhenti (ganti org / logout / dispose). Tak pernah melempar.
  static Future<void> stop() async {
    _debounce?.cancel();
    _debounce = null;
    final ch = _ch;
    _ch = null;
    _orgId = null;
    _subscribed = false;
    if (ch != null) {
      try {
        await SupabaseConfig.client.removeChannel(ch);
      } catch (_) {}
    }
  }
}
