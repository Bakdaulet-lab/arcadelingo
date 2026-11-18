import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:flutter_tts/flutter_tts.dart';

import '../../domain/ports/word_speech.dart';

/// One speech adapter per application: FlutterTts owns a shared native channel.
/// Selects installed voices for the requested language; Android network voices are never used.
class DeviceWordSpeech implements WordSpeech {
  DeviceWordSpeech({TargetPlatform? platform})
    : _platform = platform ?? defaultTargetPlatform;

  final TargetPlatform _platform;
  FlutterTts? _tts;
  _Request? _active;
  _Request? _speaking;
  Future<void> _commands = Future.value();
  String? _voiceLanguage;

  // A broken plugin must not leave navigation or the pronunciation button stuck.
  static const _commandTimeout = Duration(seconds: 3);
  static const _utteranceTimeout = Duration(seconds: 25);

  // Browser voice metadata in this plugin does not identify remote voices.
  bool get _supported =>
      !kIsWeb &&
      _platform != TargetPlatform.linux &&
      _platform != TargetPlatform.fuchsia;

  /// Binds a course to this engine without creating another native channel.
  WordSpeech forLanguage(String language) => _CourseSpeech(this, language);

  @override
  Future<SpeechResult> speak(String text) => _speak(text, 'en');

  Future<SpeechResult> _speak(String text, String language) {
    _active?.finish(SpeechResult.cancelled);
    final request = _Request(text.trim(), language);
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
      if (_voiceLanguage != request.language) {
        final voices = await tts.getVoices.timeout(_commandTimeout);
        if (!_current(request)) return;
        final voice = _localVoice(voices, request.language);
        if (voice == null) {
          request.finish(SpeechResult.unavailable);
          return;
        }
        _voiceLanguage = null;
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
        _voiceLanguage = request.language;
      }
      // Keep setup/stop commands serial, but never hold the command queue while
      // waiting for speech: a subsequent stop must be able to interrupt it.
      request.timer = Timer(_utteranceTimeout, () {
        if (!_current(request)) return;
        request.finish(SpeechResult.failed);
        _voiceLanguage = null;
        unawaited(_enqueue(_stopEngine));
      });
      _speaking = request;
      unawaited(_complete(request, tts.speak(request.text)));
    } on MissingPluginException {
      _voiceLanguage = null;
      request.finish(SpeechResult.unavailable);
    } catch (_) {
      _voiceLanguage = null;
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
      _voiceLanguage = null;
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
      _voiceLanguage = null;
    }
  }

  Map<String, String>? _localVoice(Object? rawVoices, String language) {
    if (rawVoices is! List) return null;
    final voices = <Map<String, String>>[];
    for (final raw in rawVoices) {
      if (raw is! Map) continue;
      final name = raw['name'];
      final locale = raw['locale'];
      if (name is! String || name.isEmpty || locale is! String) continue;
      final tag = _normalizeTag(locale);
      if (tag != language && !tag.startsWith('$language-')) continue;
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

  String _normalizeTag(String locale) =>
      locale.toLowerCase().replaceAll('_', '-');

  int _priority(String locale) => switch (_normalizeTag(locale)) {
    'en-us' || 'es-es' => 0,
    'en-gb' || 'es-mx' => 1,
    _ => 2,
  };
}

class _CourseSpeech implements WordSpeech {
  const _CourseSpeech(this._engine, this._language);

  final DeviceWordSpeech _engine;
  final String _language;

  @override
  Future<SpeechResult> speak(String text) => _engine._speak(text, _language);

  @override
  Future<void> stop() => _engine.stop();
}

class _Request {
  _Request(this.text, this.language);

  final String text;
  final String language;
  final result = Completer<SpeechResult>();
  Timer? timer;

  void finish(SpeechResult value) {
    timer?.cancel();
    if (!result.isCompleted) result.complete(value);
  }
}
