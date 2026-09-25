import 'dart:convert';
import 'dart:math';
import 'package:crypto/crypto.dart';
import 'package:ssr_space/utils/strings.dart';

const _inviteAlphabet = 'ABCDEFGHJKLMNPQRSTUVWXYZ23456789';

String generateInviteToken([Random? random]) {
  final r = random ?? Random.secure();
  final parts = <String>[];
  for (var g = 0; g < 6; g++) {
    final buf = StringBuffer();
    for (var i = 0; i < 4; i++) {
      buf.write(_inviteAlphabet[r.nextInt(_inviteAlphabet.length)]);
    }
    parts.add(buf.toString());
  }
  return parts.join('-');
}

String normalizeInviteToken(String raw) => raw.trim().toUpperCase();

String hashInviteToken(String raw) =>
    sha256.convert(utf8.encode(normalizeInviteToken(raw))).toString();

String maskInviteToken(String token) {
  final groups = token.split('-');
  if (groups.length < 2) return token;
  return '${groups.first}-…-${groups.last}';
}

String inviteStatusLabel({
  required DateTime expiresAt,
  required bool revoked,
  required int usedCount,
  required int maxUses,
  required DateTime now,
}) {
  if (revoked) return tr('iv_st_revoked');
  if (expiresAt.isBefore(now)) return tr('iv_st_expired');
  if (usedCount >= maxUses) return tr('iv_st_used');
  return tr('iv_st_active');
}

String inviteErrorMessage(String rpcMessage) {
  if (rpcMessage.contains('INVITE_EXPIRED')) {
    return tr('iv_expired');
  }
  if (rpcMessage.contains('INVITE_EXHAUSTED')) {
    return tr('iv_exhausted');
  }
  if (rpcMessage.contains('INVITE_INVALID')) {
    return tr('iv_invalid');
  }
  if (rpcMessage.contains('NOT_AUTHENTICATED')) {
    return tr('iv_needlogin');
  }
  return tr('iv_joinfail');
}
