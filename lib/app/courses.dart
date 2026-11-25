import 'package:arcadelingo/domain/ports/answer_log.dart';
import 'package:arcadelingo/domain/ports/card_store.dart';
import 'package:arcadelingo/domain/ports/custom_words_store.dart';
import 'package:arcadelingo/domain/ports/event_log.dart';
import 'package:arcadelingo/domain/ports/favorites_store.dart';
import 'package:arcadelingo/domain/ports/streak_store.dart';
import 'package:arcadelingo/domain/ports/word_sets_store.dart';
import 'package:arcadelingo/domain/ports/word_speech.dart';
import 'package:arcadelingo/domain/review/review_contract.dart';
import 'package:arcadelingo/domain/review/study_course.dart';

/// Готовый курс со своим словарём и собственным прогрессом.
class CourseDeck {
  const CourseDeck({
    required this.course,
    required this.items,
    required this.cards,
    required this.answers,
    required this.streaks,
    this.events = const NoopEventLog(),
    this.favorites,
    this.customWords,
    this.wordSets,
    this.speech = const NoopWordSpeech(),
  });

  final StudyCourse course;
  final List<ReviewItem> items;
  final CardStore cards;
  final AnswerLog answers;
  final StreakStore streaks;
  final EventLog events;
  final FavoritesStore? favorites;
  final CustomWordsStore? customWords;
  final WordSetsStore? wordSets;
  final WordSpeech speech;
}
