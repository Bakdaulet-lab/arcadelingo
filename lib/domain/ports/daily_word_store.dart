import 'package:arcadelingo/domain/review/review_contract.dart';

/// A confirmed board in one course, level and local calendar day.
class DailyWordRecord {
  DailyWordRecord({
    required this.targetId,
    required List<String> guesses,
    required this.finished,
  }) : guesses = List.unmodifiable(guesses);

  final String targetId;
  final List<String> guesses;
  final bool finished;
}

enum DailyWordSaveResult { saved, conflict, failed }

abstract interface class DailyWordStore {
  DailyWordRecord? load({required CefrLevel level, required DateTime day});

  /// Appends to the board the player actually saw. Retrying the same append
  /// succeeds, while a conflicting board must be read again before playing.
  Future<DailyWordSaveResult> append({
    required CefrLevel level,
    required DateTime day,
    required String targetId,
    required List<String> previousGuesses,
    required String guess,
    required bool finished,
  });
}
