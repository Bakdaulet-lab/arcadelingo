import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:flutter_tts/flutter_tts.dart';

import '../../domain/ports/word_speech.dart';

/// One speech adapter per application: FlutterTts owns a shared native channel.
/// Selects installed English voices; Android network voices are never used.
class DeviceWordSpeech implements WordSpeech {
  DeviceWordSpeech({TargetPlatform? platform})
    : _platform = platform ?? defaultTargetPlatform;

  final TargetPlatform _platform;
  FlutterTts? _tts;
  _Request? _active;
  _Request? _speaking;
  Future<void> _commands = Future.value();
  bool _prepared = false;

  // A broken plugin must not leave navigation or the pronunciation button stuck.
  static const _commandTimeout = Duration(seconds: 3);
  static const _utteranceTimeout = Duration(seconds: 25);

  // Browser voice metadata in this plugin does not identify remote voices.
  bool get _supported =>
      !kIsWeb &&
      _platform != TargetPlatform.linux &&
      _platform != TargetPlatform.fuchsia;

  @override
  Future<SpeechResult> speak(String englishText) {
    _active?.finish(SpeechResult.cancelled);
    final request = _Request(englishText.trim());
    _active = request;
    if (!_supported || request.text.isEmpty) {
      request.finish(SpeechResult.unavailable);
    } else {
      _enqueue(() => _start(request));
    }
    return request.result.future;
  }

  bool _current(_Request request) =>
      identical(_active, request) && !request.result.isCompleted;

  @override
  Future<void> stop() {
    _active?.finish(SpeechResult.cancelled);
    _active = null;
    return _enqueue(_stopEngine);
  }

  Future<void> _enqueue(Future<void> Function() command) {
    _commands = _commands.then((_) => command());
    return _commands;
  }

  Future<void> _start(_Request request) async {
    if (!_current(request)) return;
    try {
      final tts = _tts ??= _createEngine();
      await _stopEngine();
      if (!_current(request)) return;
      if (!_prepared) {
        final voices = await tts.getVoices.timeout(_commandTimeout);
        if (!_current(request)) return;
        final voice = _englishVoice(voices);
        if (voice == null) {
          request.finish(SpeechResult.unavailable);
          return;
        }
        final selected = await tts.setVoice(voice).timeout(_commandTimeout);
        if (!_current(request)) return;
        if (selected != 1) {
          request.finish(SpeechResult.unavailable);
          return;
        }
        final completion = await tts
            .awaitSpeakCompletion(true)
            .timeout(_commandTimeout);
        if (!_current(request)) return;
        if (completion != 1) {
          request.finish(SpeechResult.unavailable);
          return;
        }
        await tts.setSpeechRate(0.45).timeout(_commandTimeout);
        if (!_current(request)) return;
        _prepared = true;
      }
      // Keep setup/stop commands serial, but never hold the command queue while
      // waiting for speech: a subsequent stop must be able to interrupt it.
      request.timer = Timer(_utteranceTimeout, () {
        if (!_current(request)) return;
        request.finish(SpeechResult.failed);
        _prepared = false;
        unawaited(_enqueue(_stopEngine));
      });
      _speaking = request;
      unawaited(_complete(request, tts.speak(request.text)));
    } on MissingPluginException {
      _prepared = false;
      request.finish(SpeechResult.unavailable);
    } catch (_) {
      _prepared = false;
      request.finish(SpeechResult.failed);
    }
  }

  FlutterTts _createEngine() {
    return FlutterTts()
      ..setErrorHandler((_) => _nativeResult(SpeechResult.failed))
      ..setCancelHandler(() => _nativeResult(SpeechResult.cancelled));
  }

  void _nativeResult(SpeechResult result) {
    final request = _speaking;
    if (request == null || !_current(request)) return;
    request.finish(result);
    _speaking = null;
    if (result == SpeechResult.failed) {
      _prepared = false;
      unawaited(_enqueue(_stopEngine));
    }
  }

  Future<void> _complete(_Request request, Future<dynamic> utterance) async {
    try {
      final result = await utterance;
      if (_current(request)) {
        request.finish(
          result == 1 ? SpeechResult.completed : SpeechResult.failed,
        );
      }
    } on MissingPluginException {
      if (_current(request)) request.finish(SpeechResult.unavailable);
    } catch (_) {
      if (_current(request)) request.finish(SpeechResult.failed);
    }
  }

  Future<void> _stopEngine() async {
    // A cancel event from our own stop belongs to the previous utterance.
    _speaking = null;
    final tts = _tts;
    if (tts == null) return;
    try {
      await tts.stop().timeout(_commandTimeout);
    } catch (_) {
      // Lifecycle cleanup remains safe when a device removes/disables its TTS.
      _prepared = false;
    }
  }

  Map<String, String>? _englishVoice(Object? rawVoices) {
    if (rawVoices is! List) return null;
    final voices = <Map<String, String>>[];
    for (final raw in rawVoices) {
      if (raw is! Map) continue;
      final name = raw['name'];
      final locale = raw['locale'];
      if (name is! String || name.isEmpty || locale is! String) continue;
      final language = locale.toLowerCase().replaceAll('_', '-');
      if (language != 'en' && !language.startsWith('en-')) continue;
      if (_platform == TargetPlatform.android) {
        final network = raw['network_required'];
        if (network != false &&
            network != 'false' &&
            network != 0 &&
            network != '0') {
          continue;
        }
        if (raw['features'].toString().contains('notInstalled')) continue;
      }
      voices.add({'name': name, 'locale': locale});
    }
    voices.sort(
      (a, b) => _priority(a['locale']!).compareTo(_priority(b['locale']!)),
    );
    return voices.isEmpty ? null : voices.first;
  }

  int _priority(String locale) => switch (locale.toLowerCase().replaceAll(
    '_',
    '-',
  )) {
    'en-us' => 0,
    'en-gb' => 1,
    _ => 2,
  };
}

class _Request {
  _Request(this.text);

  final String text;
  final result = Completer<SpeechResult>();
  Timer? timer;

  void finish(SpeechResult value) {
    timer?.cancel();
    if (!result.isCompleted) result.complete(value);
  }
}
