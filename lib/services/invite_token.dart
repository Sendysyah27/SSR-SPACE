import 'dart:convert';
import 'dart:math';
import 'package:crypto/crypto.dart';

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
  if (revoked) return 'Dicabut';
  if (expiresAt.isBefore(now)) return 'Kedaluwarsa';
  if (usedCount >= maxUses) return 'Habis';
  return 'Aktif';
}

String inviteErrorMessage(String rpcMessage) {
  if (rpcMessage.contains('INVITE_EXPIRED')) {
    return 'Kode undangan kedaluwarsa.';
  }
  if (rpcMessage.contains('INVITE_EXHAUSTED')) {
    return 'Kode undangan sudah habis.';
  }
  if (rpcMessage.contains('INVITE_INVALID')) {
    return 'Kode undangan tidak valid.';
  }
  if (rpcMessage.contains('NOT_AUTHENTICATED')) {
    return 'Masuk dulu ke aplikasi.';
  }
  return 'Gagal bergabung. Coba lagi.';
}
