import 'package:flutter/material.dart';
import 'package:ssr_space/screens/lainnya/billing_screen.dart';
import 'package:ssr_space/services/month.dart';
import 'package:ssr_space/services/supabase_config.dart';

/// Kuota paket: Gratis dibatasi, Pro bebas (tanpa angka).
class PlanLimits {
  PlanLimits._();

  /// Maks workspace yang diikuti per user (Gratis).
  static const freeWorkspaces = 2;

  /// Maks anggota per workspace (Gratis).
  static const freeMembers = 3;

  /// Maks auto-track per workspace per bulan (Gratis).
  static const freeAutoPerMonth = 150;
}

bool isPro(String plan) => plan == 'pro';

bool canCreateWorkspace({required String plan, required int joined}) =>
    isPro(plan) || joined < PlanLimits.freeWorkspaces;

bool canInvite({required String plan, required int members}) =>
    isPro(plan) || members < PlanLimits.freeMembers;

bool canAutoTrack({required String plan, required int used}) =>
    isPro(plan) || used < PlanLimits.freeAutoPerMonth;

bool canExportPdf({required String plan}) => isPro(plan);

/// Kebenaran kuota dari server (migration_17, RPC check_quota).
/// Null bila gagal (belum migration / offline) → pemanggil wajib pakai
/// hitungan lokal lama sebagai fallback, jangan blokir buta.
Future<Map<String, dynamic>?> quotaCheck(String orgId, String kind) async {
  try {
    final res = await SupabaseConfig.client.rpc(
      'check_quota',
      params: {'p_org_id': orgId, 'p_kind': kind},
    );
    return Map<String, dynamic>.from(res as Map);
  } catch (_) {
    return null;
  }
}

/// Gate auto-track: server dulu, lokal bila server tak jawab.
Future<bool> canAutoTrackServer(String orgId) async {
  final q = await quotaCheck(orgId, 'auto');
  if (q != null) return q['allowed'] == true;
  final plan = await currentPlan(orgId);
  final used = await autoUsedThisMonth(orgId, currentMonth());
  return canAutoTrack(plan: plan, used: used);
}

/// Gate invite anggota: server dulu, lokal bila server tak jawab.
Future<bool> canInviteServer(String orgId) async {
  final q = await quotaCheck(orgId, 'members');
  if (q != null) return q['allowed'] == true;
  final plan = await currentPlan(orgId);
  final members = await memberCount(orgId);
  return canInvite(plan: plan, members: members);
}

/// Gate buat workspace: server dulu, lokal bila server tak jawab.
/// [contextOrgId] boleh kosong (user tanpa org) → langsung lokal.
Future<bool> canCreateWorkspaceServer({
  required String contextOrgId,
  required int joined,
}) async {
  if (contextOrgId.isNotEmpty) {
    final q = await quotaCheck(contextOrgId, 'workspaces');
    if (q != null) return q['allowed'] == true;
    final plan = await currentPlan(contextOrgId);
    return canCreateWorkspace(plan: plan, joined: joined);
  }
  return canCreateWorkspace(plan: 'free', joined: joined);
}

/// Beri tahu user ia mentok kuota Gratis, tawarkan ke Billing.
Future<void> requirePro(BuildContext context, String reason) async {
  ScaffoldMessenger.of(context).showSnackBar(
    SnackBar(content: Text('$reason Naik ke Pro untuk batas lebih longgar.')),
  );
  await Navigator.push(
    context,
    MaterialPageRoute(builder: (_) => const BillingScreen()),
  );
}

/// Hitung auto-track workspace bulan berjalan (untuk kuota).
Future<int> autoUsedThisMonth(String orgId, String monthPrefix) async {
  final rows = await SupabaseConfig.client
      .from('transactions')
      .select('id')
      .eq('org_id', orgId)
      .not('source_package', 'is', null)
      .gte('date', '$monthPrefix-01');
  return (rows as List).length;
}

/// Hitung anggota workspace (untuk kuota invite).
Future<int> memberCount(String orgId) async {
  final rows = await SupabaseConfig.client
      .from('org_members')
      .select('user_id')
      .eq('org_id', orgId);
  return (rows as List).length;
}
