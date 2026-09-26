/// Parse URI callback auth Supabase (magic link deep-link).
/// Murni Dart, tanpa dependensi Flutter — bisa di-test & diverifikasi lokal.
class AuthLinkToken {
  final String tokenHash;
  final String type;
  const AuthLinkToken({required this.tokenHash, required this.type});
}

/// Ambil `token_hash` + `type` dari URI callback
/// (`scheme://host?token_hash=..&type=magiclink`).
/// Null bila bukan link auth yang dikenali (jangan diproses).
AuthLinkToken? parseAuthLinkToken(Uri uri) {
  final q = uri.queryParameters;
  final hash = q['token_hash'];
  if (hash == null || hash.isEmpty) return null;
  final t = (q['type'] ?? '').trim();
  if (t.isEmpty) return null;
  return AuthLinkToken(tokenHash: hash, type: t);
}
