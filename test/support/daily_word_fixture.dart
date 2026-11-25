import 'dart:async';

import 'package:arcadelingo/domain/daily_word/daily_word.dart';
import 'package:arcadelingo/domain/ports/daily_word_store.dart';
import 'package:arcadelingo/domain/review/review_contract.dart';
import 'package:arcadelingo/domain/review/study_course.dart';

DailyWordPuzzle dailyFixture() =>
    selectDailyWord(
      course: StudyCourse.spanishFromRussian,
      level: CefrLevel.a1,
      date: DateTime(2026, 11, 25),
      targetId: 'playa',
      vocabulary: const [
        Word(id: 'playa', text: 'playa', translation: 'пляж'),
        Word(id: 'plaza', text: 'plaza', translation: 'площадь'),
        Word(id: 'baños', text: 'baños', translation: 'туалеты'),
        Word(id: 'calor', text: 'calor', translation: 'жара'),
        Word(id: 'campo', text: 'campo', translation: 'поле'),
        Word(id: 'carta', text: 'carta', translation: 'письмо'),
        Word(id: 'banco', text: 'banco', translation: 'банк'),
      ],
    )!;

class MemoryDailyStore implements DailyWordStore {
  MemoryDailyStore({this.record});
  DailyWordRecord? record;
  int writes = 0;
  DailyWordSaveResult result = DailyWordSaveResult.saved;
  Completer<void>? gate;

  @override
  DailyWordRecord? load({required CefrLevel level, required DateTime day}) =>
      record;

  @override
  Future<DailyWordSaveResult> append({
    required CefrLevel level,
    required DateTime day,
    required String targetId,
    required List<String> previousGuesses,
    required String guess,
    required bool finished,
  }) async {
    writes++;
    await gate?.future;
    if (result == DailyWordSaveResult.saved) {
      record = DailyWordRecord(
        targetId: targetId,
        guesses: [...previousGuesses, guess],
        finished: finished,
      );
    }
    return result;
  }
}
