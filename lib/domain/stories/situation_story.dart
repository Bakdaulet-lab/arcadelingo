import 'dart:math';

import '../review/review_contract.dart';
import '../review/study_course.dart';

part 'english_stories.dart';
part 'spanish_stories.dart';

enum StorySituation { breakfast, hotel, station }

class SituationStory {
  const SituationStory({
    required this.situation,
    required this.firstRound,
    required this.secondRound,
    required this.clue,
    required this.question,
    required this.choices,
    required this.correctIndex,
    required this.explanation,
  });

  final StorySituation situation;
  final List<ReviewItem> firstRound;
  final List<ReviewItem> secondRound;
  final String clue;
  final String question;
  final List<String> choices;
  final int correctIndex;
  final String explanation;
}

class _Scene {
  const _Scene({
    required this.situation,
    required this.words,
    required this.clue,
    required this.readings,
  });

  final StorySituation situation;
  // First two cards introduce the situation, the next two prepare the decision.
  final List<String> words;
  final String clue;
  final Map<String, _Reading> readings;
}

class _Reading {
  const _Reading(this.question, this.choices, this.explanation);
  final String question;
  // In the authored content, the correct choice always comes first.
  final List<String> choices;
  final String explanation;
}

/// Uses the actual selected course's cards so arcade outcomes keep their
/// ordinary word IDs and translations. A partial deck may omit a situation.
List<SituationStory> buildSituationStories({
  required StudyCourse course,
  required CefrLevel level,
  required Iterable<ReviewItem> courseItems,
  required Random random,
}) {
  final scenes = switch (course.studyLanguage) {
    'en' => _englishStories[level],
    'es' => _spanishStories[level],
    _ => null,
  };
  if (scenes == null) return const [];
  final byWord = {
    for (final item in courseItems)
      if (item.word.level == level) item.word.text: item,
  };
  final stories = <SituationStory>[];
  for (final scene in scenes) {
    final reading = scene.readings[course.translationLanguage];
    if (reading == null || !scene.words.every(byWord.containsKey)) continue;
    final cards = [for (final text in scene.words) byWord[text]!];
    final choices = reading.choices.toList()..shuffle(random);
    stories.add(
      SituationStory(
        situation: scene.situation,
        firstRound: List.unmodifiable(cards.take(2)),
        secondRound: List.unmodifiable(cards.skip(2)),
        clue: scene.clue,
        question: reading.question,
        choices: List.unmodifiable(choices),
        correctIndex: choices.indexOf(reading.choices.first),
        explanation: reading.explanation,
      ),
    );
  }
  return stories;
}
