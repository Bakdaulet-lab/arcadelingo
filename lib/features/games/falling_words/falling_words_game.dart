/// Экран игры «падающие слова» — SPEC.md.
///
/// Реализации здесь ещё нет — только сигнатуры, на которых компилируются
/// тесты задачи 0.7. Тело появляется в той же задаче следующим коммитом,
/// тесты в этот момент не трогаются.
///
/// Игра говорит с ядром только через [ReviewSession] и не знает, как
/// планируются повторы: `.claude/rules/games.md`, `arch_check.sh`.
library;

import 'package:arcadelingo/domain/review/review_contract.dart';
import 'package:flutter/material.dart';

const String _todo = 'игра «падающие слова» не реализована — задача 0.7';

/// Падающие слова: слово сверху, варианты перевода снизу, время на ответ.
class FallingWordsGame extends StatefulWidget {
  /// Сессию создаёт хост (задача 0.8): игра её не строит и не сохраняет.
  /// [seed] делает порядок вариантов воспроизводимым в тестах и голденах;
  /// null — обычная игра со случайным порядком.
  const FallingWordsGame({required this.session, super.key, this.seed});

  final ReviewSession session;
  final int? seed;

  @override
  State<FallingWordsGame> createState() => _FallingWordsGameState();
}

class _FallingWordsGameState extends State<FallingWordsGame> {
  @override
  Widget build(BuildContext context) => throw UnimplementedError(_todo);
}
