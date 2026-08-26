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

import 'dart:async';
import 'dart:math';

import 'package:arcadelingo/domain/review/review_contract.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'ninja_geometry.dart';
import 'ninja_run.dart';
import 'ninja_slash_juice.dart';
import 'ninja_slash_views.dart';
import 'ninja_trajectory.dart';

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
  late final NinjaRun _run;

  /// Взвод перед первой волной.
  ///
  /// Свой контроллер, а не удлинение полёта: `responseTime` отсчитывается
  /// от старта волны, и взвод, вшитый в тот же контроллер, пришлось бы
  /// вычитать из каждого ответа.
  late final AnimationController _windUp;

  late final AnimationController _flight;
  late final AnimationController _reveal;
  late final AppLifecycleListener _lifecycle;

  /// Поле: по нему считаются позиции объектов, и его же координаты приходят
  /// в жест. Одна система координат на рисование и на рез.
  final GlobalKey _fieldKey = GlobalKey();

  /// Система шлёт состояния пачками (`resumed → inactive → hidden →
  /// paused` и обратно), поэтому пауза и возврат обязаны быть
  /// идемпотентными.
  bool _paused = false;

  /// Идёт взвод перед первой волной: слово наверху, поле пусто, жест не
  /// принимается.
  ///
  /// Флагом виджета, а не фазой `NinjaRun`: взвод — про то, что человек ещё
  /// не понял, где поле, а не про правила игры.
  bool _windingUp = false;

  /// Предыдущая точка жеста; null — жеста нет.
  Offset? _last;

  /// Сколько пути прошёл палец с начала жеста.
  double _travelled = 0;

  /// Точки текущего жеста в координатах поля.
  final List<Offset> _gesture = [];

  /// След реза: точки жеста, замороженные в момент реза.
  List<Offset> _trail = const [];

  /// Направление реза в радианах — по нему делится круг на половинки.
  double _sliceAngle = 0;

  /// Точка реза: откуда летят искры и прирост очков.
  Offset _slicePoint = Offset.zero;

  /// Искры этого реза; пусто — искр нет (промах, таймаут, джус выключен).
  List<Offset> _sparks = const [];

  /// Свой генератор искр.
  ///
  /// Не тот, что у `NinjaRun`: там он перемешивает волну, и деление одного
  /// на двоих означало бы, что число нарисованных искр меняет состав
  /// обманок. Сид тот же — без него голден не снять.
  late final Random _sparkRandom = Random(widget.seed);

  /// Ответ хоста на «что дальше», взятый на входе в итоги.
  String? _footer;

  @override
  void initState() {
    super.initState();
    _run = NinjaRun(session: widget.session, random: Random(widget.seed));
    _windUp = AnimationController(
      vsync: this,
      duration: NinjaRun.windUpTime,
      // `preserve` — как у полёта: взвод игровое время, и системное
      // «убрать анимации» его не отменяет.
      animationBehavior: AnimationBehavior.preserve,
    )..addListener(_onWindUpTick);
    _flight = AnimationController(
      vsync: this,
      duration: NinjaRun.baseFlightTime,
      animationBehavior: AnimationBehavior.preserve,
    )..addListener(_onFlightTick);
    _reveal = AnimationController(
      vsync: this,
      duration: NinjaRun.correctReveal,
      animationBehavior: AnimationBehavior.preserve,
    )..addListener(_onRevealTick);
    _lifecycle = AppLifecycleListener(onStateChange: _onLifecycle);
    _run.start();
    if (_run.phase == NinjaPhase.flying) {
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
    _flight.dispose();
    _reveal.dispose();
    super.dispose();
  }

  /// Сколько прожила текущая волна. Считается от `value`, а не от
  /// `lastElapsedDuration`: последний обнуляется на каждом `forward()` и
  /// после паузы показал бы только время последнего отрезка.
  Duration get _elapsed => Duration(
    microseconds:
        ((_flight.duration ?? Duration.zero).inMicroseconds * _flight.value)
            .round(),
  );

  /// Размер поля в этом кадре; null — поля ещё нет в дереве.
  Size? get _fieldSize {
    final box = _fieldKey.currentContext?.findRenderObject();
    if (box is! RenderBox || !box.hasSize) return null;
    return box.size;
  }

  void _startFlight() {
    // Украшения прошлой волны со сцены: иначе след от реза первого слова
    // дожил бы до таймаута второго.
    _trail = const [];
    _sparks = const [];
    _flight.duration = _run.timeLimit;
    _flight.forward(from: 0);
  }

  void _startReveal() {
    _reveal.duration = _run.revealTime;
    _reveal.forward(from: 0);
  }

  void _onWindUpTick() {
    if (!_windingUp || _windUp.value < 1) return;
    _windUp.stop();
    setState(() => _windingUp = false);
    _startFlight();
  }

  void _onFlightTick() {
    if (_run.phase != NinjaPhase.flying || _flight.value < 1) return;
    _flight.stop();
    if (_run.timeout()) {
      _feel();
      setState(() {});
      _startReveal();
    }
  }

  void _onRevealTick() {
    if (_run.phase != NinjaPhase.reveal || _reveal.value < 1) return;
    _reveal.stop();
    _run.advance();
    if (_run.phase == NinjaPhase.over) {
      _footer = widget.summaryFooter?.call();
      widget.onRoundOver?.call();
    }
    setState(() {});
    if (_run.phase == NinjaPhase.flying) _startFlight();
  }

  /// Начало жеста. Ничего не режет: до 16 dp пути реза не бывает вовсе.
  void _onPointerDown(PointerDownEvent event) {
    _last = event.localPosition;
    _travelled = 0;
    _gesture
      ..clear()
      ..add(event.localPosition);
  }

  /// Движение пальца. Проверяется отрезок «предыдущая точка → текущая»
  /// против каждого объекта **в его позиции на этот кадр**.
  ///
  /// Расстояние до отрезка, а не до точки: быстрый свайп даёт точки реже,
  /// чем диаметр объекта, и проверка «точка в круге» пропускала бы объект
  /// насквозь.
  void _onPointerMove(PointerMoveEvent event) {
    final from = _last;
    if (from == null) return;
    final to = event.localPosition;
    _travelled += (to - from).distance;
    _last = to;
    _gesture.add(to);
    if (_gesture.length > trailPoints) _gesture.removeAt(0);
    // На паузе жест не принимается: окно бывает интерактивным и без фокуса
    // (split-screen, системный диалог, баннер звонка). Принятый здесь рез
    // перезапустил бы контроллеры и снял бы паузу де-факто.
    if (_paused || _windingUp) return;
    if (_run.phase != NinjaPhase.flying) return;
    if (!swipeCounts(_travelled)) return;
    final size = _fieldSize;
    if (size == null) return;
    final centers = wavePositions(
      count: _run.options.length,
      t: _flight.value,
      width: size.width,
      height: size.height,
    );
    final target = sliceTarget(
      from: from,
      to: to,
      centers: centers,
      radius: objectRadius,
    );
    if (target == null) return;
    if (!_run.slice(target, _elapsed)) return;
    _flight.stop();
    _trail = List.of(_gesture);
    _sliceAngle = (to - from).direction;
    // Точка реза, а не центр объекта: касательный рез виден именно краем, и
    // искры из центра при нём читались бы как посторонний взрыв. Считает её
    // та же функция, по которой проверено попадание.
    _slicePoint = closestPointOnSegment(
      from: from,
      to: to,
      point: centers[target],
    );
    // Частицы на промахе — вне скоупа (`SPEC.md`): рез неверного объекта
    // получает след и половинки, но не искры.
    _sparks =
        _run.verdict == Verdict.correct ? sparkBurst(_sparkRandom) : const [];
    _feel();
    setState(() {});
    _startReveal();
  }

  /// Отдать руке итог реза.
  ///
  /// Зовётся только там, где ответ принят: страж фазы в `run` уже сказал
  /// «да». Жест на паузе, вторая точка того же свайпа и уход из игры сюда
  /// не доходят — и не должны, отзываться там не на что.
  ///
  /// Флаг «убрать анимации» здесь не смотрится намеренно: вибрация не
  /// движение на экране, и для того, кому движение мешает, это
  /// единственный оставшийся канал.
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

  /// Насколько сдвинуты HUD и содержимое поля в этом кадре.
  ///
  /// Пары «слово → перевод» здесь нет и быть не должно: она соседний
  /// ребёнок того же Stack и остаётся неподвижной все 800 мс подсветки.
  ///
  /// Время тряски пересчитывается из прожитых микросекунд подсветки, а не
  /// из доли `_reveal.value`: доля даёт на границе 0.9999999999999999, и
  /// «к 300 мс экран стоит ровно» перестало бы быть правдой буквально.
  double _shake({required bool juicy, required bool revealing}) {
    if (!juicy || !revealing || _run.verdict == Verdict.correct) return 0;
    final lived = (_run.revealTime.inMicroseconds * _reveal.value).round();
    return shakeAmplitude * shakeIntensity(lived / shakeTime.inMicroseconds);
  }

  /// Доля прожитого времени реза, 0…1.
  ///
  /// Считается от 300 мс, а не от длины подсветки. На промахе подсветка
  /// длится 800 мс, и след, привязанный к ней, доживал до конца — жирная
  /// линия ложилась поперёк пары «слово → перевод», то есть поперёк
  /// единственного места, где человек учится. Нашлось картинкой на этапе
  /// 4.3; числами это не ловилось, потому что след проверялся на верном
  /// резе, где подсветка ровно 300 мс и разницы нет.
  ///
  /// Микросекундами, а не долей `_reveal.value`, по той же причине, что и
  /// у тряски: доля даёт на границе 0.9999999999999999.
  double get _slicePhase {
    final lived = (_run.revealTime.inMicroseconds * _reveal.value).round();
    return (lived / NinjaRun.correctReveal.inMicroseconds).clamp(0.0, 1.0);
  }

  /// Раздувание счёта в момент прилёта: ноль до половины полёта, пик к трём
  /// четвертям, снова ноль к концу.
  double _pulse({required bool juicy, required bool revealing}) {
    if (!juicy || !revealing || _run.verdict != Verdict.correct) return 0;
    if (_reveal.value < 0.5) return 0;
    return 1 - ((_reveal.value - 0.75).abs() / 0.25).clamp(0.0, 1.0);
  }

  void _onPointerUp(PointerUpEvent event) {
    _last = null;
    _travelled = 0;
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
    _flight.stop();
    _reveal.stop();
  }

  void _resume() {
    if (!_paused) return;
    _paused = false;
    switch (_run.phase) {
      case NinjaPhase.flying:
        // Взвод пауз не боится: 700 мс не сгорают в фоне.
        _windingUp ? _windUp.forward() : _flight.forward();
      case NinjaPhase.reveal:
        _reveal.forward();
      case NinjaPhase.over:
      case NinjaPhase.nothingToday:
        break;
    }
  }

  ObjectState _stateFor(int index, {required bool revealing}) {
    if (!revealing) return ObjectState.idle;
    if (_run.verdict == Verdict.correct) {
      return index == _run.correctIndex
          ? ObjectState.correct
          : ObjectState.dimmed;
    }
    // Промах и таймаут: верный перевод показан парой по центру, и метить
    // его ещё и в полёте значило бы тянуть взгляд туда, откуда мы его
    // увели. Помеченным остаётся только разрезанный по ошибке.
    if (index == _run.slicedIndex) return ObjectState.wrong;
    return ObjectState.dimmed;
  }

  @override
  Widget build(BuildContext context) {
    // Масштаб текста зажат сверху: при системном увеличении втрое перевод
    // в круг радиусом 34 dp не помещается вовсе, а размер объекта — часть
    // геометрии реза и меняться под контент не может.
    return MediaQuery.withClampedTextScaling(
      maxScaleFactor: 2,
      child: Scaffold(
        body: switch (_run.phase) {
          NinjaPhase.nothingToday => NothingTodayView(onExit: widget.onExit),
          NinjaPhase.over => SummaryView(
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
          NinjaPhase.flying || NinjaPhase.reveal => _playfield(context),
        },
      ),
    );
  }

  Widget _playfield(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final juicy = !MediaQuery.disableAnimationsOf(context);
    return SafeArea(
      child: AnimatedBuilder(
        animation: Listenable.merge([_flight, _reveal]),
        builder: (context, _) {
          final revealing = _run.phase == NinjaPhase.reveal;
          final shake = _shake(juicy: juicy, revealing: revealing);
          return Column(
            children: [
              Transform.translate(
                offset: Offset(shake, 0),
                child: GameHud(
                  lives: _run.lives,
                  maxLives: NinjaRun.startLives,
                  score: _run.score,
                  multiplier: _run.scoreMultiplier,
                  combo: _run.combo,
                  scorePulse: _pulse(juicy: juicy, revealing: revealing),
                  // В фазе подсветки ответ уже доложен, и answered его
                  // считает; в полёте текущее слово ещё впереди счётчика.
                  current: widget.session.answered + (revealing ? 0 : 1),
                  total: widget.session.total,
                ),
              ),
              Expanded(
                child: _field(
                  scheme,
                  juicy: juicy,
                  revealing: revealing,
                  shake: shake,
                ),
              ),
            ],
          );
        },
      ),
    );
  }

  /// Поле волны вместе с тоном серии и жестом.
  Widget _field(
    ColorScheme scheme, {
    required bool juicy,
    required bool revealing,
    required double shake,
  }) {
    final missed = revealing && _run.verdict != Verdict.correct;
    // Половинки, след и искры живут ровно 300 мс — столько, сколько длится
    // рез. Дальше объект стоит целым и помеченным: на промахе он обязан
    // остаться на кадре, а пара по центру — читаться без помех.
    final phase = _slicePhase;
    final sliced = juicy && revealing && phase < 1 ? _run.slicedIndex : null;
    return TweenAnimationBuilder<Color?>(
      tween: ColorTween(
        begin: scheme.surface,
        end: comboTint(scheme, _run.combo),
      ),
      // Перелив только когда тон густеет; обрыв серии гасит поле сразу.
      // Явный ноль нужен и второй раз — под системным «убрать анимации»:
      // неявная анимация иначе просто побежала бы в двадцать раз быстрее,
      // то есть недетерминированно для теста.
      duration: juicy && _run.combo > 0 ? comboTintFade : Duration.zero,
      builder:
          (context, color, _) => DecoratedBox(
            key: NinjaKeys.playfield,
            decoration: BoxDecoration(
              gradient: comboGradientFor(scheme, color ?? scheme.surface),
            ),
            child: Listener(
              key: _fieldKey,
              behavior: HitTestBehavior.opaque,
              onPointerDown: _onPointerDown,
              onPointerMove: _onPointerMove,
              onPointerUp: _onPointerUp,
              child: Stack(
                fit: StackFit.expand,
                children: [
                  // Трясётся содержимое поля, а не поле: фон и его градиент
                  // обязаны остаться на месте, иначе у поля появился бы
                  // край, который ездит.
                  Transform.translate(
                    offset: Offset(shake, 0),
                    child: NinjaField(
                      word: _run.item!.word.text,
                      objects: [
                        // Взвод: слово уже на экране, волны ещё нет.
                        if (!_windingUp)
                          for (var i = 0; i < _run.options.length; i++)
                            (
                              label: _run.options[i],
                              state: _stateFor(i, revealing: revealing),
                            ),
                      ],
                      progress: _flight.value,
                      faded: missed,
                      sliced: sliced,
                      sliceAngle: _sliceAngle,
                      sliceProgress: phase,
                    ),
                  ),
                  if (sliced != null && _trail.length > 1)
                    SliceTrail(
                      key: NinjaKeys.trail,
                      points: _trail,
                      progress: phase,
                    ),
                  if (sliced != null && _sparks.isNotEmpty)
                    SparkBurst(
                      key: NinjaKeys.sparks,
                      origin: _slicePoint,
                      sparks: _sparks,
                      progress: phase,
                    ),
                  // Прилёт очков — над полем, но под парой: пару он не
                  // перекрывает, а на промахе его и нет вовсе.
                  if (juicy && revealing && _run.lastPoints > 0)
                    ScorePop(
                      points: _run.lastPoints,
                      from: _slicePoint,
                      progress: phase,
                      nearMiss: _run.nearMiss,
                    ),
                  if (missed)
                    RevealPair(
                      word: _run.item!.word.text,
                      answer: _run.item!.word.translation,
                    ),
                ],
              ),
            ),
          ),
    );
  }
}
