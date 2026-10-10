import 'package:flutter_test/flutter_test.dart';
import 'package:ssr_space/services/transaction_service.dart';

void main() {
  test('halaman penuh → mungkin ada lagi', () {
    expect(txPageHasMore(100, 100), isTrue);
    expect(txPageHasMore(120, 100), isTrue);
  });

  test('halaman tak penuh → habis', () {
    expect(txPageHasMore(0, 100), isFalse);
    expect(txPageHasMore(37, 100), isFalse);
    expect(txPageHasMore(99, 100), isFalse);
  });

  test('ukuran halaman default 100', () {
    expect(txPageSize, 100);
  });
}
