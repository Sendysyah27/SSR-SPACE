import 'package:ssr_space/services/plan_limits.dart';
import 'package:ssr_space/services/supabase_config.dart';

// Gate kuota AI (entitlement Fase 1): Gratis 30 panggilan/bulan per
// user+workspace, Pro bebas. Server (migration_20: RPC check_quota kind
// 'ai' + record_ai_usage) adalah sumber kebenaran; klien fail-open:
// server tak jawab / RPC belum ada di DB lama / offline -> izinkan,
// jangan blokir buta. Prefill tetap, simpan tetap manual.

// true bila boleh pakai AI untuk [orgId] (server check_quota 'ai').
// null/exception -> true (fail-open, jangan blokir buta).
Future<bool> aiAllowed(String orgId) async {
  try {
    final q = await quotaCheck(orgId, 'ai');
    if (q == null) return true;
    return q['allowed'] == true;
  } catch (_) {
    return true;
  }
}

// Catat satu pemakaian AI ([kind]: 'chat' | 'receipt' | 'quick') via RPC
// record_ai_usage. Dipanggil SETELAH panggilan AI sukses. Gagal = diam
// (fail-silent): RPC belum ada di DB lama, offline, dsb.
Future<void> recordAiUse(String orgId, String kind) async {
  try {
    await SupabaseConfig.client.rpc(
      'record_ai_usage',
      params: {'p_org_id': orgId, 'p_kind': kind},
    );
  } catch (_) {}
}
