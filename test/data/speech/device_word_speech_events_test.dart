import 'dart:async';

import 'package:arcadelingo/data/speech/device_word_speech.dart';
import 'package:arcadelingo/domain/ports/word_speech.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  const channel = MethodChannel('flutter_tts');
  late DeviceWordSpeech speech;
  late Completer<Object?> utterance;
  Completer<Object?>? voices;
  late List<String> calls;

  void initialize() {
    speech = DeviceWordSpeech(platform: TargetPlatform.windows);
    utterance = Completer<Object?>();
    voices = null;
    calls = [];
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(channel, (call) async {
          calls.add(call.method);
          switch (call.method) {
            case 'getVoices':
              return voices?.future ??
                  [
                    {'name': 'Local', 'locale': 'en-US'},
                  ];
            case 'speak':
              return utterance.future;
            default:
              return 1;
          }
        });
  }

  tearDown(() {
    unawaited(speech.stop());
    if (!utterance.isCompleted) utterance.complete(0);
    if (voices != null && !voices!.isCompleted) voices!.complete([]);
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(channel, null);
  });

  testWidgets(
    'native error event releases a request whose future never resolves',
    (tester) async {
      initialize();
      SpeechResult? outcome;
      speech.speak('library').then((value) => outcome = value);
      await _settle(tester);
      expect(calls, contains('speak'));
      await _event(tester, 'speak.onError', 'Engine unavailable');
      expect(outcome, SpeechResult.failed);
    },
  );

  testWidgets(
    'native cancellation is not reported as successful pronunciation',
    (tester) async {
      initialize();
      SpeechResult? outcome;
      speech.speak('library').then((value) => outcome = value);
      await _settle(tester);
      await _event(tester, 'speak.onCancel', null);
      utterance.complete(1);
      await _settle(tester);
      expect(outcome, SpeechResult.cancelled);
    },
  );

  testWidgets('stalled preparation is bounded and never speaks later', (
    tester,
  ) async {
    initialize();
    voices = Completer<Object?>();
    SpeechResult? outcome;
    speech.speak('library').then((value) => outcome = value);
    await _settle(tester);
    await tester.pump(const Duration(seconds: 4));
    expect(outcome, SpeechResult.failed);
    voices!.complete([
      {'name': 'Local', 'locale': 'en-US'},
    ]);
    await _settle(tester);
    expect(calls, isNot(contains('speak')));
  });

  testWidgets('lost completion is bounded and stops the native engine', (
    tester,
  ) async {
    initialize();
    SpeechResult? outcome;
    speech.speak('library').then((value) => outcome = value);
    await _settle(tester);
    expect(calls.last, 'speak');
    await tester.pump(const Duration(seconds: 26));
    await _settle(tester);
    expect(outcome, SpeechResult.failed);
    expect(calls.last, 'stop');
  });
}

Future<void> _settle(WidgetTester tester) async {
  for (var i = 0; i < 10; i++) {
    await tester.pump();
  }
}

Future<void> _event(
  WidgetTester tester,
  String method,
  Object? arguments,
) async {
  await tester.binding.defaultBinaryMessenger.handlePlatformMessage(
    'flutter_tts',
    const StandardMethodCodec().encodeMethodCall(MethodCall(method, arguments)),
    (_) {},
  );
  await _settle(tester);
}
