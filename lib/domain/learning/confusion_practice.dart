import 'dart:math';

import '../review/review_contract.dart';
import '../review/study_course.dart';

part 'confusion_sentences.dart';

enum ConfusionPromptKind { sentence, meaning }

class ConfusionQuestion {
  const ConfusionQuestion._({
    required this.target,
    required this.choices,
    required this.kind,
    required this.prompt,
    this.cue,
    this.completedSentence,
  });

  final Word target;
  final List<Word> choices;
  final ConfusionPromptKind kind;
  final String prompt;

  /// The course translation disambiguates the intended sense in a gap.
  final String? cue;
  final String? completedSentence;
}

/// Both cards must come from the selected course's word repository.
List<ConfusionQuestion> buildConfusionPractice({
  required Word first,
  required Word second,
  required StudyCourse course,
  required Random random,
}) {
  final words = [first, second];
  if (first.level != second.level ||
      first.id == second.id ||
      _normalized(first.text) == _normalized(second.text) ||
      _normalized(first.translation) == _normalized(second.translation) ||
      words.any(
        (word) => word.text.trim().isEmpty || word.translation.trim().isEmpty,
      )) {
    return const [];
  }

  final targets = words.toList()..shuffle(random);
  return [
    for (final (index, target) in targets.indexed)
      _question(target, words.toList()..shuffle(random), course, index),
  ];
}

ConfusionQuestion _question(
  Word target,
  List<Word> choices,
  StudyCourse course,
  int index,
) {
  final example = target.example?.trim();
  final other = choices.firstWhere((word) => word.id != target.id);
  if (example != null &&
      example.isNotEmpty &&
      !_term(other.text).hasMatch(example)) {
    final occurrences = _term(target.text).allMatches(example).toList();
    if (occurrences.length == 1) {
      final match = occurrences.single;
      return ConfusionQuestion._(
        target: target,
        choices: List.unmodifiable(choices),
        kind: ConfusionPromptKind.sentence,
        prompt: example.replaceRange(
          match.start + match[1]!.length,
          match.end,
          '___',
        ),
        cue: target.translation,
        completedSentence: example,
      );
    }
  }

  final entries = switch (course.studyLanguage) {
    'es' => _spanishSentences,
    'en' => _englishSentences,
    _ => null,
  };
  final headword = _normalized(target.text);
  final entry = entries?[headword];
  final aliases = switch (course.translationLanguage) {
    'ru' => entry?.russian,
    'en' when course.studyLanguage == 'es' => entry?.other,
    'es' when course.studyLanguage == 'en' => entry?.other,
    _ => null,
  };
  if (entry != null &&
      aliases != null &&
      aliases.split('|').contains(_normalized(target.translation)) &&
      !_term(other.text).hasMatch(entry.gap)) {
    return ConfusionQuestion._(
      target: target,
      choices: List.unmodifiable(choices),
      kind: ConfusionPromptKind.sentence,
      prompt: entry.gap,
      cue: target.translation,
      completedSentence: entry.gap.replaceFirst('___', headword),
    );
  }

  // Even an arbitrary personal phrase has a user-provided meaning. Quote it
  // verbatim; inventing an example could teach the wrong sense or inflection.
  final gloss = target.translation.trim();
  final prompt = switch (course.translationLanguage) {
    'ru' =>
      index == 0
          ? 'В разговоре ты хочешь сказать «$gloss». Какое слово подойдёт?'
          : 'Как передать «$gloss» в сообщении другу?',
    'es' =>
      index == 0
          ? 'En una conversación quieres decir «$gloss». ¿Qué palabra usarías?'
          : '¿Cómo dirías «$gloss» en un mensaje a un amigo?',
    'kk' =>
      index == 0
          ? 'Әңгімеде «$gloss» дегенді қалай айтасың?'
          : 'Досыңа «$gloss» дегенді қалай жазар едің?',
    _ =>
      index == 0
          ? 'You want to say “$gloss” in a conversation. Which word would you use?'
          : 'How would you say “$gloss” in a message to a friend?',
  };
  return ConfusionQuestion._(
    target: target,
    choices: List.unmodifiable(choices),
    kind: ConfusionPromptKind.meaning,
    prompt: prompt,
  );
}

String _normalized(String value) => value.trim().toLowerCase();

// Dart's ASCII word boundary would treat the accented é in "té" as punctuation.
RegExp _term(String text) => RegExp(
  r'(^|[^\p{L}\p{M}\p{N}])' +
      RegExp.escape(text.trim()) +
      r'(?![\p{L}\p{M}\p{N}])',
  caseSensitive: false,
  unicode: true,
);
