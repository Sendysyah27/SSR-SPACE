import 'package:flutter_test/flutter_test.dart';
import 'package:ssr_space/services/auth_link_parse.dart';

void main() {
  test('link magiclink valid terparse', () {
    final t = parseAuthLinkToken(
      Uri.parse('com.ssr.space.ssrspace://login-callback'
          '?token_hash=abc123&type=magiclink'),
    );
    expect(t?.tokenHash, 'abc123');
    expect(t?.type, 'magiclink');
  });

  test('tanpa token_hash ditolak', () {
    expect(
      parseAuthLinkToken(
        Uri.parse('com.ssr.space.ssrspace://login-callback?type=magiclink'),
      ),
      isNull,
    );
  });

  test('tanpa type ditolak', () {
    expect(
      parseAuthLinkToken(
        Uri.parse(
            'com.ssr.space.ssrspace://login-callback?token_hash=abc123'),
      ),
      isNull,
    );
  });

  test('uri asing ditolak', () {
    expect(parseAuthLinkToken(Uri.parse('https://example.com/a?b=c')), isNull);
    expect(parseAuthLinkToken(Uri.parse('com.ssr.space.ssrspace://other')),
        isNull);
  });
}
