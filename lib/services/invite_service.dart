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

  /// Jalur baru (migration_33): RPC `join_org_by_invite_v2` mengembalikan
  /// kode hasil, bukan melempar exception. Kontrak sama dgn [join]:
  /// sukses -> org id, gagal -> [InviteException] berpesan UI (tak pernah
  /// exception mentah). Bila function v2 belum ada di DB (PGRST202 /
  /// "schema cache"), jatuh ke RPC lama `join_org_by_invite` supaya DB
  /// versi lama tetap jalan.
  Future<String> joinOrgV2(String rawToken) async {
    final token = normalizeInviteToken(rawToken);
    final Map<String, dynamic> res;
    try {
      final raw = await _c.rpc(
        'join_org_by_invite_v2',
        params: {'p_token': token},
      );
      res = (raw as Map).cast<String, dynamic>();
    } on PostgrestException catch (err) {
      if (_v2Missing(err)) {
        return join(token);
      }
      throw InviteException.fromRpc('${err.message} ${err.code ?? ''}');
    } catch (err) {
      throw InviteException.fromRpc('$err');
    }
    final code = res['code'] as String? ?? 'invalid';
    final orgId = res['org_id'] as String?;
    if (code == 'ok' || code == 'already_member') {
      if (orgId == null || orgId.isEmpty) {
        throw InviteException(tr('iv_joinfail'));
      }
      return orgId;
    }
    throw InviteException(inviteCodeMessage(code));
  }

  /// True bila PostgrestException menandakan RPC v2 belum ada (DB lama).
  bool _v2Missing(PostgrestException err) {
    if (err.code == 'PGRST202') return true;
    final m = err.message.toLowerCase();
    return m.contains('join_org_by_invite_v2') &&
        (m.contains('schema cache') || m.contains('could not find the function'));
  }
}

/// Pesan UI untuk kode hasil `join_org_by_invite_v2`. Kode `ok` /
/// `already_member` bukan error (org id dipakai pemanggil); bila sampai
/// ke sini tetap dipetakan ke `iv_joinfail` sebagai jaring pengaman.
String inviteCodeMessage(String code) {
  switch (code) {
    case 'invalid':
      return tr('iv_invalid');
    case 'expired':
      return tr('iv_expired');
    case 'exhausted':
      return tr('iv_exhausted');
    case 'rate_limited':
      return tr('iv_ratelimited');
    case 'already_member':
      return tr('iv_already_member');
    default:
      return tr('iv_joinfail');
  }
}
