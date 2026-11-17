import 'dart:async';

import 'package:arcadelingo/domain/ports/word_speech.dart';

class FakeWordSpeech implements WordSpeech {
  FakeWordSpeech({this.result = SpeechResult.completed});

  final List<String> spoken = [];
  int stopCalls = 0;
  SpeechResult result;
  Completer<SpeechResult>? pending;

  @override
  Future<SpeechResult> speak(String englishText) {
    spoken.add(englishText);
    return pending?.future ?? Future.value(result);
  }

  @override
  Future<void> stop() async {
    stopCalls++;
    final current = pending;
    if (current != null && !current.isCompleted) {
      current.complete(SpeechResult.cancelled);
    }
  }
}
