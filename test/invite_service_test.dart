import 'package:flutter_test/flutter_test.dart';
import 'package:ssr_space/services/invite_service.dart';

void main() {
  test('inviteCodeMessage memetakan kode v2 ke pesan UI', () {
    expect(inviteCodeMessage('invalid'), 'Kode undangan tidak valid.');
    expect(inviteCodeMessage('expired'), 'Kode undangan kedaluwarsa.');
    expect(inviteCodeMessage('exhausted'), 'Kode undangan sudah habis.');
    expect(inviteCodeMessage('rate_limited'),
        'Terlalu banyak percobaan. Tunggu sebentar lalu coba lagi.');
    expect(inviteCodeMessage('already_member'),
        'Kamu sudah menjadi anggota workspace ini.');
    expect(inviteCodeMessage('kode-tak-dikenal'),
        'Gagal bergabung. Coba lagi.');
  });
}
