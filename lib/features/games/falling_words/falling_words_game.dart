/// Экран игры «падающие слова» — SPEC.md.
///
/// Игра говорит с ядром только через [ReviewSession] и не знает, как
/// планируются повторы: `.claude/rules/games.md`, `arch_check.sh`.
///
/// Всё время игры живёт в двух [AnimationController] и больше нигде: ни
/// `Timer`, ни `Stopwatch`, ни `DateTime.now()`. Из этого следует три
/// вещи. Пауза при сворачивании — это `stop()`: он замораживает `value`, а
/// `forward()` продолжает с той же скоростью, поэтому `value × duration`
/// не видит времени, проведённого в фоне (`Ticker.muted` так не умеет —
/// часы под ним идут дальше, и слово телепортируется). Конец падения ловим
/// по значению, а не по `AnimationStatus.completed`: симуляция считает
/// себя done только на следующем тике, и статус пришёл бы кадром позже.
/// И оба контроллера — `AnimationBehavior.preserve`: системное «убрать
/// анимации» ускорило бы обычный контроллер в двадцать раз, а здесь время
/// падения это геймплей, а не украшение.
library;

import 'dart:math';

import 'package:arcadelingo/domain/review/review_contract.dart';
import 'package:flutter/material.dart';

import 'falling_words_run.dart';
import 'falling_words_views.dart';

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

class _FallingWordsGameState extends State<FallingWordsGame>
    with TickerProviderStateMixin {
  late final FallingWordsRun _run;
  late final AnimationController _fall;
  late final AnimationController _reveal;
  late final AppLifecycleListener _lifecycle;

  /// Система шлёт состояния пачками (`resumed → inactive → hidden →
  /// paused` и обратно), поэтому пауза и возврат обязаны быть
  /// идемпотентными.
  bool _paused = false;

  @override
  void initState() {
    super.initState();
    _run = FallingWordsRun(
      session: widget.session,
      random: Random(widget.seed),
    );
    _fall = AnimationController(
      vsync: this,
      duration: FallingWordsRun.baseFallTime,
      animationBehavior: AnimationBehavior.preserve,
    )..addListener(_onFallTick);
    _reveal = AnimationController(
      vsync: this,
      duration: FallingWordsRun.correctReveal,
      animationBehavior: AnimationBehavior.preserve,
    )..addListener(_onRevealTick);
    _lifecycle = AppLifecycleListener(onStateChange: _onLifecycle);
    _run.start();
    if (_run.phase == FallingPhase.falling) _startFall();
  }

  @override
  void dispose() {
    // Игрок ушёл с невыданным ответом: доложить неответ, пока контроллер
    // ещё жив и по нему можно прочитать прожитое время. Сам страж фазы —
    // внутри abandon().
    _run.abandon(_elapsed);
    _lifecycle.dispose();
    _fall.dispose();
    _reveal.dispose();
    super.dispose();
  }

  /// Сколько прожило текущее слово. Считается от `value`, а не от
  /// `lastElapsedDuration`: последний обнуляется на каждом `forward()` и
  /// после паузы показал бы только время последнего отрезка.
  Duration get _elapsed => Duration(
    microseconds:
        ((_fall.duration ?? Duration.zero).inMicroseconds * _fall.value)
            .round(),
  );

  void _startFall() {
    _fall.duration = _run.timeLimit;
    _fall.forward(from: 0);
  }

  void _startReveal() {
    _reveal.duration = _run.revealTime;
    _reveal.forward(from: 0);
  }

  void _onFallTick() {
    if (_run.phase != FallingPhase.falling || _fall.value < 1) return;
    _fall.stop();
    if (_run.timeout()) {
      setState(() {});
      _startReveal();
    }
  }

  void _onRevealTick() {
    if (_run.phase != FallingPhase.reveal || _reveal.value < 1) return;
    _reveal.stop();
    _run.advance();
    setState(() {});
    if (_run.phase == FallingPhase.falling) _startFall();
  }

  void _onTap(int index) {
    // На паузе кнопка остаётся живой: окно бывает интерактивным и без
    // фокуса (split-screen, системный диалог, баннер звонка). Принятый
    // здесь тап перезапустил бы контроллеры и снял бы паузу де-факто —
    // при `_paused == true` игра поехала бы дальше, а ядру ушёл бы
    // таймаут по слову, которого никто не видел.
    if (_paused) return;
    if (!_run.choose(index, _elapsed)) return;
    _fall.stop();
    setState(() {});
    _startReveal();
  }

  void _onLifecycle(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      _resume();
    } else {
      _pause();
    }
  }

  /// Пауза на любом состоянии, кроме `resumed`: на `inactive` (звонок,
  /// шторка, переключатель приложений) играть всё равно нельзя, а время
  /// шло бы.
  void _pause() {
    if (_paused) return;
    _paused = true;
    _fall.stop();
    _reveal.stop();
  }

  void _resume() {
    if (!_paused) return;
    _paused = false;
    switch (_run.phase) {
      case FallingPhase.falling:
        _fall.forward();
      case FallingPhase.reveal:
        _reveal.forward();
      case FallingPhase.over:
      case FallingPhase.nothingToday:
        break;
    }
  }

  AnswerState _stateFor(int index, {required bool revealing}) {
    if (!revealing) return AnswerState.idle;
    if (_run.verdict == Verdict.correct) {
      return index == _run.correctIndex
          ? AnswerState.correct
          : AnswerState.dimmed;
    }
    // Промах и таймаут: верный вариант показан парой в поле, и подсвечивать
    // его ещё и внизу значило бы тянуть взгляд туда, откуда мы его увели.
    // Помеченной остаётся только ошибочно нажатая кнопка: что именно нажал
    // игрок — часть ответа.
    if (index == _run.chosenIndex) return AnswerState.wrong;
    return AnswerState.dimmed;
  }

  @override
  Widget build(BuildContext context) {
    // Масштаб текста зажат сверху: при системном увеличении втрое четыре
    // кнопки по две строки и HUD на телефонный экран уже не помещаются, и
    // выбор стоит между обрезанным текстом и уменьшенным. Здесь — второе.
    return MediaQuery.withClampedTextScaling(
      maxScaleFactor: 2,
      child: Scaffold(
        body: switch (_run.phase) {
          FallingPhase.nothingToday => const NothingTodayView(),
          FallingPhase.over => SummaryView(
            score: _run.score,
            bestCombo: _run.bestCombo,
            correctCount: _run.correctCount,
            answeredCount: _run.answeredCount,
          ),
          FallingPhase.falling || FallingPhase.reveal => _playfield(),
        },
      ),
    );
  }

  Widget _playfield() {
    final revealing = _run.phase == FallingPhase.reveal;
    return SafeArea(
      child: Column(
        children: [
          GameHud(
            lives: _run.lives,
            maxLives: FallingWordsRun.startLives,
            score: _run.score,
            multiplier: _run.scoreMultiplier,
            // В фазе подсветки ответ уже доложен, и answered его считает;
            // в падении текущее слово ещё впереди счётчика.
            current: widget.session.answered + (revealing ? 0 : 1),
            total: widget.session.total,
          ),
          Expanded(
            child:
                revealing && _run.verdict != Verdict.correct
                    ? RevealPair(
                      word: _run.item!.word.text,
                      answer: _run.item!.word.translation,
                    )
                    : AnimatedBuilder(
                      animation: Listenable.merge([_fall, _reveal]),
                      builder:
                          (context, _) => FallingField(
                            text: _run.item!.word.text,
                            progress: _fall.value,
                            fadeProgress: revealing ? _reveal.value : 0,
                          ),
                    ),
          ),
          Padding(
            padding: const EdgeInsets.all(16),
            child: IgnorePointer(
              // Страховка поверх стража фазы в run: тап по кнопке во время
              // подсветки не должен даже пытаться пройти.
              ignoring: revealing,
              child: Column(
                children: [
                  for (var i = 0; i < _run.options.length; i++) ...[
                    if (i > 0) const SizedBox(height: 12),
                    AnswerButton(
                      label: _run.options[i],
                      state: _stateFor(i, revealing: revealing),
                      onTap: revealing ? null : () => _onTap(i),
                    ),
                  ],
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}
