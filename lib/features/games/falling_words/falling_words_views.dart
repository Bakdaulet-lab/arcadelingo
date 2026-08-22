/// Части экрана игры «падающие слова» и ключи, по которым их находят
/// тесты и голдены.
///
/// Реализации виджетов здесь ещё нет — только сигнатуры, на которых
/// компилируются тесты задачи 0.7. Ключи настоящие: имя — часть контракта
/// с тестом, менять его молча нельзя.
library;

import 'package:flutter/material.dart';

const String _todo = 'игра «падающие слова» не реализована — задача 0.7';

/// Ключи частей экрана. Тест ищет по ним то, что не опознать по тексту:
/// падающее слово (текст у него меняется каждый раунд) и счётчики HUD.
abstract final class FallingWordsKeys {
  /// Падающее слово. По нему же тест меряет, сдвинулось ли оно.
  static const Key word = Key('falling_words.word');

  static const Key score = Key('falling_words.score');

  static const Key combo = Key('falling_words.combo');

  /// «сколько показано / сколько запланировано».
  static const Key progress = Key('falling_words.progress');

  static const Key summary = Key('falling_words.summary');

  static const Key nothingToday = Key('falling_words.nothing_today');
}

/// Как выглядит кнопка ответа. Различие между [correct] и [wrong] —
/// не только цвет: дальтонизм это 8% мужчин, поэтому у каждой ещё иконка.
enum AnswerState {
  /// Обычная, нажимаемая.
  idle,

  /// Верный вариант в фазе подсветки.
  correct,

  /// Ошибочно нажатая.
  wrong,

  /// Остальные в фазе подсветки: приглушены, чтобы не спорить за внимание.
  dimmed,
}

/// Кнопка с вариантом перевода.
class AnswerButton extends StatelessWidget {
  const AnswerButton({
    required this.label,
    required this.state,
    super.key,
    this.onTap,
  });

  final String label;
  final AnswerState state;

  /// null в фазе подсветки: тап уже не считается.
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) => throw UnimplementedError(_todo);
}
