import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:ssr_space/services/invite_token.dart';
import 'package:ssr_space/services/supabase_config.dart';
import 'package:ssr_space/utils/strings.dart';

class InviteException implements Exception {
  final String message;
  InviteException(this.message);
  InviteException.fromRpc(String rpcMessage)
      : message = inviteErrorMessage(rpcMessage);
  @override
  String toString() => message;
}

class InviteService {
  SupabaseClient get _c => SupabaseConfig.client;

  Future<({String token, String id})> createInvite({
    required String orgId,
    required String role,
  }) async {
    final token = generateInviteToken();
    final uid = _c.auth.currentUser!.id;
    try {
      final row = await _c
          .from('org_invites')
          .insert({
            'org_id': orgId,
            'role': role,
            'token_hash': hashInviteToken(token),
            'created_by': uid,
          })
          .select('id')
          .single();
      return (token: token, id: row['id'] as String);
    } on PostgrestException catch (err) {
      if (err.code == '42501') {
        throw InviteException(tr('iv_adminonly'));
      }
      rethrow;
    }
  }

  /// Peran user sendiri di org. Policy "own memberships" (migration_08)
  /// mengizinkan member membaca baris keanggotaannya sendiri.
  Future<String> myRole(String orgId) async {
    final uid = _c.auth.currentUser!.id;
    final row = await _c
        .from('org_members')
        .select('role')
        .eq('org_id', orgId)
        .eq('user_id', uid)
        .maybeSingle();
    return row?['role'] as String? ?? '';
  }

  Future<List<Map<String, dynamic>>> listInvites(String orgId) async {
    final rows = await _c
        .from('org_invites')
        .select(
          'id, role, expires_at, used_count, max_uses, revoked, created_at',
        )
        .eq('org_id', orgId)
        .order('created_at', ascending: false);
    return List<Map<String, dynamic>>.from(rows);
  }

  Future<void> revokeInvite(String id) async {
    await _c.from('org_invites').update({'revoked': true}).eq('id', id);
  }

  Future<String> join(String rawToken) async {
    try {
      final orgId = await _c.rpc(
        'join_org_by_invite',
        params: {'p_token': normalizeInviteToken(rawToken)},
      );
      return orgId as String;
    } on PostgrestException catch (err) {
      throw InviteException.fromRpc('${err.message} ${err.code ?? ''}');
    } catch (err) {
      throw InviteException.fromRpc('$err');
    }
  }
}
