import 'package:flutter_test/flutter_test.dart';
import 'package:ssr_space/services/auto_saved_notify.dart';

void main() {
  test('id stabil, dalam rentang, beda per transaksi', () {
    final a = autoSavedId('tx-abc');
    expect(a, autoSavedId('tx-abc'));
    expect(a >= 0 && a <= 0x7fffffff, true);
    expect(autoSavedId('tx-abd') == a, false);
  });

  test('konstanta kanal + payload tak kosong', () {
    expect(AutoSavedNotify.channelId, 'ssr_auto_saved');
    expect(AutoSavedNotify.channelName.trim().isNotEmpty, true);
    expect(AutoSavedNotify.payloadOpen, 'open_correct');
  });
}
