/// Validasi password baru (Batch 1 Sprint). Murni Dart, tanpa Flutter.
/// Kembalikan kode error (`mismatch`/`short`) atau null bila sah.
String? newPasswordError(String p1, String p2, {int minLen = 6}) {
  if (p1 != p2) return 'mismatch';
  if (p1.length < minLen) return 'short';
  return null;
}
