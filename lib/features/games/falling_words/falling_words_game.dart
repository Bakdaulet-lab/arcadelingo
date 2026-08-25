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
///
/// Джус (`SPEC.md`, раздел «Джус») своих контроллеров не заводит вовсе:
/// тряска, полёт очков и пульс счёта читают `value` тех же двух. Отсюда
/// три следствия. Пауза при сворачивании достаётся украшениям даром.
/// Вопрос «а этот контроллер `preserve` или нет» не возникает. И
/// выключение по системному «убрать анимации» — умножение на ноль здесь,
/// в `build`, а не подмена скорости часов: подсветка промаха обязана
/// остаться восьмисотмиллисекундной, потому что это время чтения.
///
/// Единственная неявная анимация — перелив тона поля; её длительность
/// зануляется явно, а не отдаётся на откуп поведению по умолчанию.
library;

import 'dart:async';
import 'dart:math';

import 'package:arcadelingo/domain/review/review_contract.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'falling_words_juice.dart';
import 'falling_words_run.dart';
import 'falling_words_views.dart';

/// Падающие слова: слово сверху, варианты перевода снизу, время на ответ.
class FallingWordsGame extends StatefulWidget {
  /// Сессию создаёт хост (задача 0.8): игра её не строит и не сохраняет.
  /// [seed] делает порядок вариантов воспроизводимым в тестах и голденах;
  /// null — обычная игра со случайным порядком.
  const FallingWordsGame({
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
  /// Спрашивается один раз, в момент перехода к итогам: остались ли слова к
  /// повторению — вопрос к хосту, и ответ на него к этому моменту уже
  /// учитывает последний доклад.
  final String Function()? summaryFooter;

  /// Партия дошла до конца — итогов или потерянных жизней.
  ///
  /// Единственное, что игра сообщает хосту сверх контракта `ReviewSession`, и
  /// сообщает потому, что больше об этом узнать неоткуда: жизни живут внутри
  /// игры, и «доиграл» от «бросил на середине» снаружи не отличить. День
  /// серии засчитывает законченная партия (`lib/app/games.dart`).
  ///
  /// Зовётся там же, где спрашивается [summaryFooter], — в момент перехода к
  /// экрану конца, ровно один раз за партию. Уход с середины сюда не
  /// попадает: там `dispose` докладывает неответ, а экрана конца не бывает.
  final VoidCallback? onRoundOver;

  @override
  State<FallingWordsGame> createState() => _FallingWordsGameState();
}

class _FallingWordsGameState extends State<FallingWordsGame>
    with TickerProviderStateMixin {
  late final FallingWordsRun _run;

  /// Взвод перед первым падением.
  ///
  /// Свой контроллер, а не удлинение падения: `responseTime` отсчитывается
  /// от начала падения, и взвод, вшитый в тот же контроллер, пришлось бы
  /// вычитать из каждого ответа. И не переиспользование контроллера
  /// подсветки: его значение читает джус, и связь «взвод дёргает тряску»
  /// ждала бы своего часа.
  late final AnimationController _windUp;

  late final AnimationController _fall;
  late final AnimationController _reveal;
  late final AppLifecycleListener _lifecycle;

  /// Система шлёт состояния пачками (`resumed → inactive → hidden →
  /// paused` и обратно), поэтому пауза и возврат обязаны быть
  /// идемпотентными.
  bool _paused = false;

  /// Идёт взвод перед первым падением: слово наверху, ничего не движется,
  /// тапы не принимаются.
  ///
  /// Флагом виджета, а не фазой `FallingWordsRun`: взвод — про то, что
  /// человек ещё не нашёл кнопки на экране, а не про правила игры. Чистый
  /// класс о нём не знает, и его тесты от появления взвода не изменились ни
  /// одной строкой.
  bool _windingUp = false;

  /// Ответ хоста на «что дальше», взятый на входе в итоги. Не в `build`:
  /// на итогах ничего не меняется, а хост считал бы очередь заново на
  /// каждую перестройку экрана.
  String? _footer;

  @override
  void initState() {
    super.initState();
    _run = FallingWordsRun(
      session: widget.session,
      random: Random(widget.seed),
    );
    _windUp = AnimationController(
      vsync: this,
      duration: FallingWordsRun.windUpTime,
      // `preserve` — как у падения: взвод игровое время, и системное
      // «убрать анимации» его не отменяет.
      animationBehavior: AnimationBehavior.preserve,
    )..addListener(_onWindUpTick);
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
    if (_run.phase == FallingPhase.falling) {
      _windingUp = true;
      _windUp.forward(from: 0);
    }
  }

  @override
  void dispose() {
    // Игрок ушёл с невыданным ответом: доложить неответ, пока контроллер
    // ещё жив и по нему можно прочитать прожитое время. Сам страж фазы —
    // внутри abandon().
    _run.abandon(_elapsed);
    _lifecycle.dispose();
    _windUp.dispose();
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

  void _onWindUpTick() {
    if (!_windingUp || _windUp.value < 1) return;
    _windUp.stop();
    setState(() => _windingUp = false);
    _startFall();
  }

  void _onFallTick() {
    if (_run.phase != FallingPhase.falling || _fall.value < 1) return;
    _fall.stop();
    if (_run.timeout()) {
      _feel();
      setState(() {});
      _startReveal();
    }
  }

  void _onRevealTick() {
    if (_run.phase != FallingPhase.reveal || _reveal.value < 1) return;
    _reveal.stop();
    _run.advance();
    if (_run.phase == FallingPhase.over) {
      _footer = widget.summaryFooter?.call();
      widget.onRoundOver?.call();
    }
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
    // 700 мс взвода даны на то, чтобы найти кнопки, а не ответить: тап в
    // этом окне — рефлекс, а не ответ (`SPEC.md`).
    if (_windingUp) return;
    if (!_run.choose(index, _elapsed)) return;
    _fall.stop();
    _feel();
    setState(() {});
    _startReveal();
  }

  /// Отдать руке итог ответа.
  ///
  /// Зовётся только там, где ответ принят: страж фазы в `run` уже сказал
  /// «да». Тап на паузе, второй тап того же кадра и уход из игры сюда не
  /// доходят — и не должны, отзываться там не на что.
  ///
  /// Флаг «убрать анимации» здесь не смотрится намеренно: вибрация не
  /// движение на экране, и для того, кому движение мешает, это
  /// единственный оставшийся канал. У системы для неё свой переключатель,
  /// и он ниже нас.
  void _feel() {
    switch (hapticFor(
      correct: _run.verdict == Verdict.correct,
      combo: _run.combo,
      nearMiss: _run.nearMiss,
    )) {
      case Haptic.light:
        unawaited(HapticFeedback.lightImpact());
      case Haptic.medium:
        unawaited(HapticFeedback.mediumImpact());
      case Haptic.heavy:
        unawaited(HapticFeedback.heavyImpact());
    }
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
    _windUp.stop();
    _fall.stop();
    _reveal.stop();
  }

  void _resume() {
    if (!_paused) return;
    _paused = false;
    switch (_run.phase) {
      case FallingPhase.falling:
        // Взвод пауз не боится: 700 мс не сгорают в фоне.
        _windingUp ? _windUp.forward() : _fall.forward();
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
          FallingPhase.nothingToday => NothingTodayView(onExit: widget.onExit),
          FallingPhase.over => SummaryView(
            score: _run.score,
            bestCombo: _run.bestCombo,
            correctCount: _run.correctCount,
            answeredCount: _run.answeredCount,
            // Партия оборвана жизнями: advance() уходит в итоги по нулю
            // жизней раньше, чем спрашивает следующее слово.
            outOfLives: _run.lives == 0,
            footer: _footer,
            onPlayAgain: widget.onPlayAgain,
            onExit: widget.onExit,
          ),
          FallingPhase.falling || FallingPhase.reveal => _playfield(context),
        },
      ),
    );
  }

  Widget _playfield(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final juicy = !MediaQuery.disableAnimationsOf(context);
    final revealing = _run.phase == FallingPhase.reveal;
    return SafeArea(
      // Кнопки строятся один раз на перестройку и приезжают в builder
      // готовыми: их содержимое меняется с фазой, а не с кадром, и гонять
      // четыре виджета заново шестьдесят раз в секунду незачем. Обёртка
      // Transform вокруг них при этом новая на каждый кадр — она и есть
      // тряска.
      child: AnimatedBuilder(
        animation: Listenable.merge([_fall, _reveal]),
        child: _answers(revealing),
        builder: (context, answers) {
          final shake = _shake(juicy: juicy, revealing: revealing);
          return Column(
            children: [
              Transform.translate(
                offset: Offset(shake, 0),
                child: GameHud(
                  lives: _run.lives,
                  maxLives: FallingWordsRun.startLives,
                  score: _run.score,
                  multiplier: _run.scoreMultiplier,
                  combo: _run.combo,
                  scorePulse: _pulse(juicy: juicy, revealing: revealing),
                  // В фазе подсветки ответ уже доложен, и answered его
                  // считает; в падении текущее слово ещё впереди счётчика.
                  current: widget.session.answered + (revealing ? 0 : 1),
                  total: widget.session.total,
                ),
              ),
              Expanded(
                child: _field(scheme, juicy: juicy, revealing: revealing),
              ),
              Transform.translate(offset: Offset(shake, 0), child: answers),
            ],
          );
        },
      ),
    );
  }

  /// Насколько сдвинуты HUD и кнопки в этом кадре.
  ///
  /// Пары «слово → перевод» здесь нет и быть не должно: она живёт в поле,
  /// которое между этими двумя Transform, и остаётся неподвижной все 800 мс
  /// подсветки. Это единственный момент, когда человек чему-то учится.
  ///
  /// Время тряски пересчитывается из прожитых микросекунд подсветки, а не
  /// из доли `_reveal.value`: доля даёт на границе 0.9999999999999999, и
  /// «к 300 мс экран стоит ровно» перестало бы быть правдой буквально.
  double _shake({required bool juicy, required bool revealing}) {
    if (!juicy || !revealing || _run.verdict == Verdict.correct) return 0;
    final lived = (_run.revealTime.inMicroseconds * _reveal.value).round();
    return shakeAmplitude * shakeIntensity(lived / shakeTime.inMicroseconds);
  }

  /// Раздувание счёта в момент прилёта: ноль до половины полёта, пик к трём
  /// четвертям, снова ноль к концу.
  double _pulse({required bool juicy, required bool revealing}) {
    if (!juicy || !revealing || _run.verdict != Verdict.correct) return 0;
    if (_reveal.value < 0.5) return 0;
    return 1 - ((_reveal.value - 0.75).abs() / 0.25).clamp(0.0, 1.0);
  }

  /// Поле падения вместе с тоном серии и прилетающими очками.
  Widget _field(
    ColorScheme scheme, {
    required bool juicy,
    required bool revealing,
  }) {
    final missed = revealing && _run.verdict != Verdict.correct;
    return TweenAnimationBuilder<Color?>(
      tween: ColorTween(
        begin: scheme.surface,
        end: comboTint(scheme, _run.combo),
      ),
      // Перелив только когда тон густеет; обрыв серии гасит поле сразу.
      // Не стиль: пара «слово → перевод» показывается ровно в момент
      // обрыва, и на гаснущем тоне её перевод читался бы под контрастом
      // 3.6. Явный ноль нужен и второй раз — под системным «убрать
      // анимации»: неявная анимация иначе просто побежала бы в двадцать
      // раз быстрее, то есть недетерминированно для теста.
      duration: juicy && _run.combo > 0 ? comboTintFade : Duration.zero,
      builder:
          (context, color, _) => DecoratedBox(
            key: FallingWordsKeys.playfield,
            // Градиент, а не заливка: заливкой поле читалось панелью —
            // жёсткая граница о HUD сверху и о ряд кнопок снизу. Это увидели
            // голдены 0.9, числами оно не ловилось.
            decoration: BoxDecoration(
              gradient: comboGradientFor(scheme, color ?? scheme.surface),
            ),
            child: Stack(
              children: [
                if (missed)
                  RevealPair(
                    word: _run.item!.word.text,
                    answer: _run.item!.word.translation,
                  )
                else
                  FallingField(
                    text: _run.item!.word.text,
                    progress: _fall.value,
                    fadeProgress: revealing ? _reveal.value : 0,
                  ),
                // Positioned.fill, а не обычный ребёнок: прилёт очков не
                // должен участвовать в том, какого размера получится поле.
                if (juicy && revealing && _run.lastPoints > 0)
                  Positioned.fill(
                    child: ScorePop(
                      points: _run.lastPoints,
                      // Оттуда, где слово стояло в момент ответа: _fall
                      // остановлен, и его value всю подсветку держит именно
                      // эту точку.
                      from: _fall.value,
                      progress: _reveal.value,
                      nearMiss: _run.nearMiss,
                    ),
                  ),
              ],
            ),
          ),
    );
  }

  Widget _answers(bool revealing) {
    return Padding(
      key: FallingWordsKeys.answers,
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
    );
  }
}
