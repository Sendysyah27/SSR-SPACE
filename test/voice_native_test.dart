import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:ssr_space/services/voice_native.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  const ch = MethodChannel(VoiceNative.channelName);
  const codec = StandardMethodCodec();

  Future<void> incoming(String method, [dynamic args]) {
    return TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .handlePlatformMessage(
      VoiceNative.channelName,
      codec.encodeMethodCall(MethodCall(method, args)),
      (_) {},
    );
  }

  tearDown(() {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(ch, null);
  });

  test('isAvailable true/false/throw', () async {
    final v = VoiceNative();
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(ch, (c) async => true);
    expect(await v.isAvailable(), isTrue);
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(ch, (c) async => null);
    expect(await v.isAvailable(), isFalse);
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(ch, (c) async => throw Exception('x'));
    expect(await v.isAvailable(), isFalse);
  });

  test('start teruskan hasil + error native', () async {
    final v = VoiceNative();
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(ch, (c) async {
      expect(c.method, 'start');
      return true;
    });
    var words = '';
    var fin = false;
    var err = '';
    final ok = await v.start(
      onResult: (w, f) {
        words = w;
        fin = f;
      },
      onError: (c) => err = c,
      onStatus: (_) {},
      localeId: 'id-ID',
    );
    expect(ok, isTrue);
    await incoming('onResult', {'words': 'makan 20 ribu', 'final': true});
    expect(words, 'makan 20 ribu');
    expect(fin, isTrue);
    await incoming('onError', {'code': 'no_match'});
    expect(err, 'no_match');
    await v.stop();
    expect(v.isListening, isFalse);
  });

  test('tanpa plugin = gagal jujur', () async {
    final v = VoiceNative();
    expect(
      await v.start(onResult: (_, __) {}, onError: (_) {}, onStatus: (_) {}),
      isFalse,
    );
    await v.stop();
  });
}
