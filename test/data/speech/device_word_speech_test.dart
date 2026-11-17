import 'dart:async';

import 'package:arcadelingo/data/speech/device_word_speech.dart';
import 'package:arcadelingo/domain/ports/word_speech.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  const channel = MethodChannel('flutter_tts');
  late _SpeechEngine engine;
  late DeviceWordSpeech speech;

  setUp(() {
    engine = _SpeechEngine();
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(channel, engine.handle);
    speech = DeviceWordSpeech(platform: TargetPlatform.windows);
  });

  tearDown(() async {
    await speech.stop();
    engine.finishAll();
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(channel, null);
  });

  test(
    'uses an installed English voice and waits for native completion',
    () async {
      engine.voices = [
        {'name': 'Russian', 'locale': 'ru-RU'},
        {'name': 'British', 'locale': 'en-GB'},
        {'name': 'American', 'locale': 'en-US'},
      ];
      var completed = false;
      final result = speech.speak('  opportunity  ')
        ..then((_) => completed = true);
      await _drain();

      expect(engine.spoken, ['opportunity']);
      expect(
        engine.calls.any(
          (call) =>
              call.method == 'awaitSpeakCompletion' && call.arguments == true,
        ),
        isTrue,
      );
      expect(engine.selectedVoice, {'name': 'American', 'locale': 'en-US'});
      expect(completed, isFalse);
      engine.finish(0);
      expect(await result, SpeechResult.completed);
    },
  );

  test(
    'Android selects only English voices explicitly marked offline',
    () async {
      speech = DeviceWordSpeech(platform: TargetPlatform.android);
      engine.voices = [
        {'name': 'Cloud', 'locale': 'en-US', 'network_required': 'true'},
        {'name': 'Unknown', 'locale': 'en-US'},
        {'name': 'Local', 'locale': 'en-GB', 'network_required': 'false'},
      ];
      final result = speech.speak('library');
      await _drain();
      expect(engine.selectedVoice, {'name': 'Local', 'locale': 'en-GB'});
      expect(engine.spoken, ['library']);
      engine.finish(0);
      expect(await result, SpeechResult.completed);
    },
  );

  test(
    'missing English voice is unavailable and never speaks Russian',
    () async {
      engine.voices = [
        {'name': 'Russian', 'locale': 'ru-RU'},
      ];
      expect(await speech.speak('library'), SpeechResult.unavailable);
      expect(engine.spoken, isEmpty);
    },
  );

  test('network-only Android voices are unavailable', () async {
    speech = DeviceWordSpeech(platform: TargetPlatform.android);
    engine.voices = [
      {'name': 'Cloud', 'locale': 'en-US', 'network_required': true},
      {'name': 'Unknown', 'locale': 'en-GB'},
    ];
    expect(await speech.speak('library'), SpeechResult.unavailable);
    expect(engine.spoken, isEmpty);
  });

  test(
    'invalid voice lists are unavailable without an unhandled cast',
    () async {
      engine.voices = [
        null,
        'en-US',
        {'name': 4, 'locale': 'en-US'},
      ];
      expect(await speech.speak('library'), SpeechResult.unavailable);
      expect(engine.spoken, isEmpty);
    },
  );

  test(
    'failed voice selection never falls back to the default voice',
    () async {
      engine.voiceResult = 0;
      expect(await speech.speak('library'), SpeechResult.unavailable);
      expect(engine.spoken, isEmpty);
    },
  );

  test('an absent native plugin is unavailable and stop is harmless', () async {
    engine.missing = true;
    expect(await speech.speak('library'), SpeechResult.unavailable);
    await speech.stop();
  });

  test(
    'engine errors produce a failure and another request can recover',
    () async {
      engine.error = PlatformException(code: 'tts_error');
      expect(await speech.speak('library'), SpeechResult.failed);
      engine.error = null;
      final retried = speech.speak('library');
      await _drain();
      engine.finish(0);
      expect(await retried, SpeechResult.completed);
    },
  );

  test('a rejected native utterance is not reported as completed', () async {
    final result = speech.speak('library');
    await _drain();
    engine.finish(0, result: 0);
    expect(await result, SpeechResult.failed);
  });

  test('stop cancels preparation and prevents late pronunciation', () async {
    engine.voiceGate = Completer<Object?>();
    final result = speech.speak('library');
    await _drain();
    final stopped = speech.stop();
    expect(await result, SpeechResult.cancelled);
    engine.voiceGate!.complete(engine.voices);
    await stopped;
    await _drain();
    expect(engine.spoken, isEmpty);
  });

  test('a newer request wins even while the first is preparing', () async {
    engine.voiceGate = Completer<Object?>();
    final old = speech.speak('old');
    await _drain();
    final latest = speech.speak('latest');
    expect(await old, SpeechResult.cancelled);
    engine.voiceGate!.complete(engine.voices);
    await _drain();
    expect(engine.spoken, ['latest']);
    engine.finish(0);
    expect(await latest, SpeechResult.completed);
  });

  test(
    'replacement stops the old voice and ignores its late completion',
    () async {
      final old = speech.speak('old');
      await _drain();
      final latest = speech.speak('latest');
      expect(await old, SpeechResult.cancelled);
      await _drain();
      expect(engine.spoken, ['old', 'latest']);
      final methods = engine.calls.map((call) => call.method).toList();
      final firstSpeak = methods.indexOf('speak');
      final lastSpeak = methods.lastIndexOf('speak');
      expect(methods.sublist(firstSpeak + 1, lastSpeak), contains('stop'));
      var latestCompleted = false;
      latest.then((_) => latestCompleted = true);
      engine.finish(0);
      await _drain();
      expect(latestCompleted, isFalse);
      engine.finish(1);
      expect(await latest, SpeechResult.completed);
    },
  );

  test(
    'stop cancels a speaking word even if native completion never arrives',
    () async {
      final result = speech.speak('library');
      await _drain();
      await speech.stop();
      expect(await result, SpeechResult.cancelled);
      expect(engine.calls.last.method, 'stop');
      engine.finish(0);
      await _drain();
    },
  );

  test('blank text never reaches the engine', () async {
    expect(await speech.speak('  '), SpeechResult.unavailable);
    expect(engine.calls, isEmpty);
  });

  test('unsupported Linux is unavailable without native calls', () async {
    speech = DeviceWordSpeech(platform: TargetPlatform.linux);
    expect(await speech.speak('library'), SpeechResult.unavailable);
    await speech.stop();
    expect(engine.calls, isEmpty);
  });

  test('no-op speech truthfully reports unavailable', () async {
    const noop = NoopWordSpeech();
    expect(await noop.speak('library'), SpeechResult.unavailable);
    await noop.stop();
  });
}

// Method channels have multiple asynchronous hops. Real futures avoid coupling
// these race assertions to any adapter-internal queue or implementation timer.
Future<void> _drain() async {
  for (var i = 0; i < 30; i++) {
    await Future<void>.delayed(Duration.zero);
  }
}

class _SpeechEngine {
  final calls = <MethodCall>[];
  final spoken = <String>[];
  final utterances = <Completer<Object?>>[];
  Object? voices = [
    {'name': 'Local', 'locale': 'en-US'},
  ];
  Object? voiceResult = 1;
  Object? error;
  bool missing = false;
  Completer<Object?>? voiceGate;
  Object? selectedVoice;

  Future<Object?> handle(MethodCall call) async {
    calls.add(call);
    if (missing) throw MissingPluginException();
    if (error != null) throw error!;
    switch (call.method) {
      case 'getVoices':
        return voiceGate?.future ?? voices;
      case 'setVoice':
        selectedVoice = call.arguments;
        return voiceResult;
      case 'speak':
        final args = call.arguments;
        spoken.add(args is Map ? args['text'] as String : args as String);
        final utterance = Completer<Object?>();
        utterances.add(utterance);
        return utterance.future;
      default:
        return 1;
    }
  }

  void finish(int index, {Object? result = 1}) {
    final utterance = utterances[index];
    if (!utterance.isCompleted) utterance.complete(result);
  }

  void finishAll() {
    for (var i = 0; i < utterances.length; i++) {
      finish(i);
    }
  }
}
