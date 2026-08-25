/// Экран игры «ниндзя-слэш» — `SPEC.md`, раздел «Ниндзя-слэш».
///
/// Игра говорит с ядром только через [ReviewSession] и не знает, как
/// планируются повторы: `.claude/rules/games.md`, `arch_check.sh`. Соседнюю
/// игру она тоже не знает — правило 5, и оно с этого каталога перестало
/// быть вакуумным.
///
/// Всё время игры живёт в трёх [AnimationController] и больше нигде: ни
/// `Timer`, ни `Stopwatch`, ни `DateTime.now()`. Это и есть исполненный
/// вердикт по Flame (`docs/dev/context.md`): собственный игровой цикл
/// сломал бы паузу, которая держится на `stop()` — он замораживает `value`,
/// а `forward()` продолжает с той же скоростью, поэтому `value × duration`
/// не видит времени, проведённого в фоне. Конец полёта ловим по значению, а
/// не по `AnimationStatus.completed`: симуляция считает себя done только на
/// следующем тике, и статус пришёл бы кадром позже. Все три контроллера —
/// `AnimationBehavior.preserve`: системное «убрать анимации» ускорило бы
/// обычный в двадцать раз, а время полёта здесь геймплей, а не украшение.
///
/// Позиции объектов считает `wavePositions` — та же функция, по которой
/// поле их рисует. Рисовать одно, а резать другое здесь невозможно по
/// построению.
library;

import 'package:arcadelingo/domain/review/review_contract.dart';
import 'package:flutter/material.dart';

/// Ниндзя-слэш: слово наверху, три объекта на параболах, рез свайпом.
class NinjaSlashGame extends StatefulWidget {
  /// Сессию создаёт хост: игра её не строит и не сохраняет. [seed] делает
  /// состав и порядок волны воспроизводимым в тестах и голденах; null —
  /// обычная игра со случайным порядком.
  const NinjaSlashGame({
    required this.session,
    required this.onPlayAgain,
    required this.onExit,
    super.key,
    this.seed,
    this.summaryFooter,
    this.onRoundOver,
  });

  final ReviewSession session;
  final int? seed;

  /// «Ещё раз»: новую сессию строит хост — игра не знает ни про хранилище,
  /// ни про размер сессии.
  final VoidCallback onPlayAgain;

  /// «Выйти» с итогов и с «на сегодня всё».
  final VoidCallback onExit;

  /// Строка «что дальше» под статистикой итогов; null — строки нет.
  /// Спрашивается один раз, в момент перехода к итогам.
  final String Function()? summaryFooter;

  /// Партия дошла до конца — итогов или потерянных жизней.
  ///
  /// Зовётся там же, где спрашивается [summaryFooter], ровно один раз за
  /// партию. Уход с середины сюда не попадает: там `dispose` докладывает
  /// неответ, а экрана конца не бывает.
  final VoidCallback? onRoundOver;

  @override
  State<NinjaSlashGame> createState() => _NinjaSlashGameState();
}

class _NinjaSlashGameState extends State<NinjaSlashGame>
    with TickerProviderStateMixin {
  @override
  Widget build(BuildContext context) => throw UnimplementedError();
}
