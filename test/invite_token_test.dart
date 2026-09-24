import 'dart:math';
import 'package:flutter_test/flutter_test.dart';
import 'package:ssr_space/core/saas/invite_token.dart';

void main() {
  test('generate: 6 grup x 4 char, charset tanpa I/O/0/1', () {
    final t = generateInviteToken(Random(42));
    expect(RegExp(r'^[A-HJ-NP-Z2-9]{4}(-[A-HJ-NP-Z2-9]{4}){5}$').hasMatch(t),
        isTrue,
        reason: t);
  });

  test('hash: deterministik, trim + uppercase dulu, hex lowercase 64', () {
    final a = hashInviteToken(' abcd-efgh-jklm-nopq-rstu-vwxy ');
    final b = hashInviteToken('ABCD-EFGH-JKLM-NOPQ-RSTU-VWXY');
    expect(a, b);
    expect(RegExp(r'^[0-9a-f]{64}$').hasMatch(a), isTrue, reason: a);
  });

  test('mask tampilkan grup pertama dan terakhir saja', () {
    expect(
      maskInviteToken('ABCD-EFGH-JKLM-NOPQ-RSTU-VWXY'),
      'ABCD-…-VWXY',
    );
  });

  test('label status', () {
    final now = DateTime(2026, 9, 24);
    expect(
      inviteStatusLabel(
          expiresAt: now.add(const Duration(days: 1)),
          revoked: false,
          usedCount: 0,
          maxUses: 1,
          now: now),
      'Aktif',
    );
    expect(
      inviteStatusLabel(
          expiresAt: now.subtract(const Duration(minutes: 1)),
          revoked: false,
          usedCount: 0,
          maxUses: 1,
          now: now),
      'Kedaluwarsa',
    );
    expect(
      inviteStatusLabel(
          expiresAt: now.add(const Duration(days: 1)),
          revoked: false,
          usedCount: 1,
          maxUses: 1,
          now: now),
      'Habis',
    );
    expect(
      inviteStatusLabel(
          expiresAt: now.add(const Duration(days: 1)),
          revoked: true,
          usedCount: 0,
          maxUses: 1,
          now: now),
      'Dicabut',
    );
  });

  test('pesan error RPC → UI', () {
    expect(inviteErrorMessage('INVITE_EXPIRED'), 'Kode undangan kedaluwarsa.');
    expect(inviteErrorMessage('INVITE_EXHAUSTED'),
        'Kode undangan sudah habis.');
    expect(inviteErrorMessage('INVITE_INVALID'), 'Kode undangan tidak valid.');
    expect(
        inviteErrorMessage('NOT_AUTHENTICATED'), 'Masuk dulu ke aplikasi.');
    expect(inviteErrorMessage('PGRST116'), 'Gagal bergabung. Coba lagi.');
    expect(inviteErrorMessage('anything'), 'Gagal bergabung. Coba lagi.');
  });
}
