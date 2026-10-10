import 'package:flutter_test/flutter_test.dart';
import 'package:ssr_space/services/invite_service.dart';

void main() {
  test('InviteException membawa pesan UI, bukan kode mentah', () {
    final e = InviteException.fromRpc('INVITE_EXPIRED');
    expect(e.message, 'Kode undangan kedaluwarsa.');
    expect(InviteException.fromRpc('boom').message,
        'Gagal bergabung. Coba lagi.');
    expect(InviteException.fromRpc('QUOTA_EXCEEDED').message,
        'Anggota workspace penuh (maksimal 3 di paket Gratis).');
  });
}
