import 'package:arcadelingo/domain/ports/answer_log.dart';
import 'package:arcadelingo/domain/ports/card_store.dart';
import 'package:arcadelingo/domain/ports/favorites_store.dart';
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
    this.favorites,
    this.speech = const NoopWordSpeech(),
  });

  final StudyCourse course;
  final List<ReviewItem> items;
  final CardStore cards;
  final AnswerLog answers;
  final FavoritesStore? favorites;
  final WordSpeech speech;
}
