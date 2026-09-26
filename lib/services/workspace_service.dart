import 'package:ssr_space/services/supabase_config.dart';

class OrgMember {
  final String userId;
  final String role;
  const OrgMember({required this.userId, required this.role});
}

class WorkspaceService {
  Future<List<OrgMember>> members(String orgId) async {
    final rows = await SupabaseConfig.client.rpc(
      'list_org_members',
      params: {'p_org_id': orgId},
    );
    final uid = SupabaseConfig.client.auth.currentUser?.id;
    return List<Map<String, dynamic>>.from(rows)
        .map((m) => OrgMember(
              userId: m['user_id'].toString(),
              role: (m['role'] ?? 'member').toString(),
            ))
        .toList()
      ..sort((a, b) {
        if ((a.userId == uid) != (b.userId == uid)) {
          return a.userId == uid ? -1 : 1;
        }
        return a.role.compareTo(b.role);
      });
  }

  Future<void> kickMember(String orgId, String userId) async {
    await SupabaseConfig.client.rpc(
      'kick_member',
      params: {'p_org_id': orgId, 'p_user_id': userId},
    );
  }

  Future<void> deleteWorkspace(String orgId) async {
    await SupabaseConfig.client.rpc(
      'delete_workspace',
      params: {'p_org_id': orgId},
    );
  }
}
