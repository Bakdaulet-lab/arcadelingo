/// Result of a pronunciation request, separate from game sound effects.
enum SpeechResult {
  /// The speech engine confirmed that the utterance finished.
  completed,

  /// A newer request or [WordSpeech.stop] cancelled this utterance.
  cancelled,

  /// This device has no supported, installed English voice.
  unavailable,

  /// The installed engine could not finish the utterance.
  failed,
}

/// Speaks a card's English text using an installed device voice.
///
/// A new request replaces the previous one. Operational engine failures are
/// returned as [SpeechResult]; neither method throws for an unavailable engine.
abstract class WordSpeech {
  Future<SpeechResult> speak(String englishText);

  /// Cancels preparation and playback. Safe to call repeatedly or on disposal.
  Future<void> stop();
}

class NoopWordSpeech implements WordSpeech {
  const NoopWordSpeech();

  @override
  Future<SpeechResult> speak(String englishText) async =>
      SpeechResult.unavailable;

  @override
  Future<void> stop() async {}
}
