/// Validasi password baru (Batch 1 Sprint). Murni Dart, tanpa Flutter.
/// Kembalikan kode error (`mismatch`/`short`/`weak`) atau null bila sah.
///
/// P3-2: panjang minimum 8 karakter + tolak blok kecil sandi umum
/// (perbandingan tanpa peduli besar-kecil huruf).
const _blockedPasswords = <String>{
  '12345678',
  '123456789',
  'password',
  'password1',
  'qwerty123',
  '11111111',
  'admin123',
};

String? newPasswordError(String p1, String p2, {int minLen = 8}) {
  if (p1 != p2) return 'mismatch';
  if (p1.length < minLen) return 'short';
  if (_blockedPasswords.contains(p1.toLowerCase())) return 'weak';
  return null;
}
