import 'dart:async';

import 'package:arcadelingo/data/speech/device_word_speech.dart';
import 'package:arcadelingo/domain/ports/word_speech.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

const _channel = MethodChannel('flutter_tts');

class _AndroidVoice {
  final pending = <Completer<int>>[];

  Future<Object?> handle(MethodCall call) async {
    if (call.method == 'getVoices') {
      return [
        for (final tag in ['en', 'es'])
          {'name': tag, 'locale': tag, 'network_required': '0'},
      ];
    }
    if (call.method == 'speak') {
      pending.add(Completer<int>());
      return pending.last.future;
    }
    if (call.method == 'stop' &&
        pending.isNotEmpty &&
        !pending.last.isCompleted) {
      // The plugin returns 0 to the old speak caller. Android onStop arrives
      // separately on the channel, without the utterance ID.
      pending.last.complete(0);
    }
    return 1;
  }
}

Future<void> _drain(WidgetTester tester) async {
  for (var i = 0; i < 8; i++) {
    await tester.pump();
  }
}

Future<void> _event(WidgetTester tester, String method) async {
  await tester.binding.defaultBinaryMessenger.handlePlatformMessage(
    _channel.name,
    const StandardMethodCodec().encodeMethodCall(MethodCall(method, true)),
    (_) {},
  );
  await _drain(tester);
}

void main() {
  late DeviceWordSpeech speech;
  late _AndroidVoice voice;
  void initialize() {
    speech = DeviceWordSpeech(platform: TargetPlatform.android);
    voice = _AndroidVoice();
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(_channel, voice.handle);
  }

  tearDown(() {
    unawaited(speech.stop());
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(_channel, null);
  });

  testWidgets('delayed Android stops cannot cancel another course or replay', (
    tester,
  ) async {
    initialize();
    final spanish = speech.forLanguage('es');
    final first = spanish.speak('llave');
    await _drain(tester);
    await spanish.stop();
    expect(await first, SpeechResult.cancelled);
    final replay = spanish.speak('llave');
    await _drain(tester);
    final last = speech.speak('key');
    expect(await replay, SpeechResult.cancelled);
    await _drain(tester);
    expect(voice.pending, hasLength(3));
    SpeechResult? heard;
    unawaited(last.then<void>((result) => heard = result));
    await _event(tester, 'speak.onStart');
    await _event(tester, 'speak.onCancel');
    await _event(tester, 'speak.onCancel');
    expect(heard, isNull);
    voice.pending.last.complete(1);
    expect(await last, SpeechResult.completed);

    final interrupted = speech.speak('door');
    await _drain(tester);
    await _event(tester, 'speak.onCancel');
    expect(await interrupted, SpeechResult.cancelled);
  });

  testWidgets(
    'a lost stop notification cannot leave a real interruption pending',
    (tester) async {
      initialize();
      final first = speech.speak('key');
      await _drain(tester);
      await speech.stop();
      expect(await first, SpeechResult.cancelled);
      final interrupted = speech.speak('door');
      await _drain(tester);
      // Exactly one anonymous event for two possible sources. There is no
      // completion from the newer utterance because the system interrupted it.
      await _event(tester, 'speak.onCancel');
      await tester.pump(const Duration(seconds: 26));
      expect(await interrupted, SpeechResult.cancelled);
    },
  );
}
