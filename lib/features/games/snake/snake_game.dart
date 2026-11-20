import 'dart:async';
import 'dart:math';

import 'package:arcadelingo/domain/ports/sounds.dart';
import 'package:arcadelingo/domain/ports/word_speech.dart';
import 'package:arcadelingo/domain/review/review_contract.dart';
import 'package:arcadelingo/domain/review/study_course.dart';
import 'package:arcadelingo/ui/app_strings.dart';
import 'package:arcadelingo/ui/arcade_panel.dart';
import 'package:arcadelingo/ui/arcade_round_summary.dart';
import 'package:arcadelingo/ui/arcade_status_layout.dart';
import 'package:arcadelingo/ui/theme.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'snake_field.dart';
import 'snake_run.dart';

abstract final class SnakeKeys {
  static const field = Key('snake.field');
  static const word = Key('snake.word');
  static const pause = Key('snake.pause');
  static const resume = Key('snake.resume');
  static const next = Key('snake.next');
  static const summary = Key('snake.summary');

  static Key direction(SnakeDirection direction) =>
      ValueKey('snake.direction.${direction.name}');
}

class SnakeGame extends StatefulWidget {
  const SnakeGame({
    required this.session,
    required this.vocabulary,
    required this.onPlayAgain,
    required this.onExit,
    this.onRoundOver,
    this.onRoundScore,
    this.summaryFooter,
    this.mistakeCount,
    this.onReviewMistakes,
    this.course,
    this.level,
    this.speech = const NoopWordSpeech(),
    this.sounds = const NoopSounds(),
    this.seed,
    super.key,
  });

  final BoardReviewSession session;
  final List<Word> vocabulary;
  final VoidCallback onPlayAgain;
  final VoidCallback onExit;
  final VoidCallback? onRoundOver;
  final Widget Function(int score)? onRoundScore;
  final String Function()? summaryFooter;
  final int Function()? mistakeCount;
  final VoidCallback? onReviewMistakes;
  final StudyCourse? course;
  final CefrLevel? level;
  final WordSpeech speech;
  final Sounds sounds;
  final int? seed;

  @override
  State<SnakeGame> createState() => _SnakeGameState();
}

class _SnakeGameState extends State<SnakeGame>
    with SingleTickerProviderStateMixin, WidgetsBindingObserver {
  static const _arrows = [
    SnakeDirection.left,
    SnakeDirection.up,
    SnakeDirection.down,
    SnakeDirection.right,
  ];

  late final SnakeRun _run;
  late final AnimationController _motion;
  final _reading = Stopwatch();
  Timer? _timer;
  bool _active = true;
  bool _roundComplete = false;
  String? _footer;
  Widget? _record;

  bool get _canSteer =>
      _run.phase == SnakePhase.ready || _run.phase == SnakePhase.moving;

  @override
  void initState() {
    super.initState();
    _run = SnakeRun(widget.session, widget.vocabulary, Random(widget.seed));
    _motion = AnimationController(
      vsync: this,
      duration: SnakeRun.stepTime,
      value: 1,
    );
    WidgetsBinding.instance.addObserver(this);
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    _active = state == AppLifecycleState.resumed;
    if (!_active) {
      _pause();
      unawaited(widget.speech.stop());
    }
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _timer?.cancel();
    _reading.stop();
    _motion.dispose();
    unawaited(widget.speech.stop());
    super.dispose();
  }

  void _turn(SnakeDirection direction) {
    if (!_active || !_canSteer || !_run.steer(direction)) return;
    if (_run.phase == SnakePhase.ready) _start();
  }

  void _start() {
    if (!_active || !_run.start()) return;
    _reading.start();
    _tick();
    if (_run.phase == SnakePhase.moving) {
      _timer = Timer.periodic(SnakeRun.stepTime, (_) => _tick());
    }
  }

  void _pause() {
    if (_run.phase != SnakePhase.moving) return;
    _run.pause();
    _stop();
    _motion.value = 1;
    setState(() {});
  }

  void _stop() {
    _timer?.cancel();
    _timer = null;
    _reading.stop();
  }

  void _exit() {
    _stop();
    unawaited(widget.speech.stop());
    widget.onExit();
  }

  void _tick() {
    if (!_active || _run.phase != SnakePhase.moving) return;
    _run.step(_reading.elapsed);
    if (MediaQuery.disableAnimationsOf(context)) {
      _motion.value = 1;
    } else {
      _motion.forward(from: 0);
    }
    if (_run.phase == SnakePhase.feedback) {
      _stop();
      final answer = _run.selectedAnswer!;
      widget.sounds.play(
        _run.answerCorrect ? GameSound.clawCatch : GameSound.miss,
      );
      unawaited(widget.speech.speak(answer.text));
    } else if (_run.phase == SnakePhase.finished) {
      _stop();
      _finish();
    }
    setState(() {});
  }

  void _next() {
    if (_run.phase != SnakePhase.feedback) return;
    unawaited(widget.speech.stop());
    _reading.reset();
    _motion.value = 1;
    _run.next();
    if (_run.phase == SnakePhase.finished) _finish();
    setState(() {});
  }

  void _finish() {
    if (_roundComplete) return;
    _roundComplete = true;
    _footer = widget.summaryFooter?.call();
    _record = widget.onRoundScore?.call(_run.score);
    widget.sounds.play(GameSound.roundEnd);
    widget.onRoundOver?.call();
  }

  @override
  Widget build(BuildContext context) {
    final strings = context.strings;
    final phase = _run.phase;
    final moving = phase == SnakePhase.moving;
    final iconEnabled = phase == SnakePhase.ready || moving;
    return CallbackShortcuts(
      bindings: {
        const SingleActivator(LogicalKeyboardKey.arrowLeft):
            () => _turn(SnakeDirection.left),
        const SingleActivator(LogicalKeyboardKey.arrowUp):
            () => _turn(SnakeDirection.up),
        const SingleActivator(LogicalKeyboardKey.arrowDown):
            () => _turn(SnakeDirection.down),
        const SingleActivator(LogicalKeyboardKey.arrowRight):
            () => _turn(SnakeDirection.right),
      },
      child: Focus(
        autofocus: true,
        child: PopScope<void>(
          onPopInvokedWithResult: (didPop, _) {
            if (didPop) _stop();
          },
          child: Scaffold(
            appBar: AppBar(
              leading: BackButton(onPressed: _exit),
              title: Text(strings.snake),
              actions: [
                if (phase != SnakePhase.finished)
                  IconButton.filledTonal(
                    key: SnakeKeys.pause,
                    tooltip: moving ? strings.snakePause : strings.snakeStart,
                    onPressed: iconEnabled ? (moving ? _pause : _start) : null,
                    icon: Icon(
                      moving ? Icons.pause_rounded : Icons.play_arrow_rounded,
                    ),
                  ),
                const SizedBox(width: 8),
              ],
            ),
            body:
                phase == SnakePhase.finished
                    ? _summary(context)
                    : _playfield(context),
          ),
        ),
      ),
    );
  }

  Widget _playfield(BuildContext context) {
    final theme = Theme.of(context);
    final colors = theme.colorScheme;
    final strings = context.strings;
    final course = widget.course;
    final level = widget.level;
    final phase = _run.phase;
    final paused = phase == SnakePhase.paused;
    return SafeArea(
      child: Align(
        alignment: Alignment.topCenter,
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 432),
          child: ListView(
            padding: const EdgeInsets.fromLTRB(14, 8, 14, 16),
            children: [
              if (course != null || level != null) ...[
                Row(
                  children: [
                    if (course != null)
                      Expanded(
                        child: Text(
                          strings.courseName(course),
                          style: theme.textTheme.labelLarge?.copyWith(
                            color: colors.onSurfaceVariant,
                          ),
                        ),
                      )
                    else
                      const Spacer(),
                    if (level != null)
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 9,
                          vertical: 4,
                        ),
                        decoration: BoxDecoration(
                          color: colors.primaryContainer,
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Text(
                          level.name.toUpperCase(),
                          style: theme.textTheme.labelMedium?.copyWith(
                            color: colors.onPrimaryContainer,
                          ),
                        ),
                      ),
                  ],
                ),
                const SizedBox(height: 10),
              ],
              _prompt(context),
              const SizedBox(height: 10),
              ArcadePanel(
                padding: const EdgeInsets.all(7),
                child: Stack(
                  alignment: Alignment.center,
                  children: [
                    SnakeField(
                      key: SnakeKeys.field,
                      run: _run,
                      motion: _motion,
                      onTurn: _canSteer ? _turn : null,
                    ),
                    if (paused) Positioned.fill(child: _pausePanel(context)),
                  ],
                ),
              ),
              const SizedBox(height: 10),
              _feedback(context),
              const SizedBox(height: 8),
              Row(
                spacing: 6,
                children: [
                  for (final direction in _arrows)
                    Expanded(
                      child: OutlinedButton(
                        key: SnakeKeys.direction(direction),
                        onPressed: _canSteer ? () => _turn(direction) : null,
                        style: OutlinedButton.styleFrom(
                          minimumSize: const Size(0, 48),
                          padding: EdgeInsets.zero,
                        ),
                        child: Tooltip(
                          message: _directionName(strings, direction),
                          child: Icon(_directionIcon(direction), size: 22),
                        ),
                      ),
                    ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _prompt(BuildContext context) {
    final theme = Theme.of(context);
    final strings = context.strings;
    final secondary = theme.textTheme.labelMedium?.copyWith(
      color: theme.colorScheme.onSurfaceVariant,
    );
    return ArcadePanel(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 9),
      child: Wrap(
        alignment: WrapAlignment.spaceBetween,
        crossAxisAlignment: WrapCrossAlignment.center,
        spacing: 8,
        runSpacing: 5,
        children: [
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            spacing: 3,
            children: [
              Text(strings.snakePrompt, style: secondary),
              Text(
                _run.item!.word.translation,
                key: SnakeKeys.word,
                style: withWeight(
                  theme.textTheme.headlineSmall!,
                  FontWeight.w700,
                ),
              ),
            ],
          ),
          Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Text(strings.score(_run.score), textAlign: TextAlign.end),
              Text(
                strings.snakeCount(_run.correctCount, widget.session.total),
                textAlign: TextAlign.end,
                style: secondary,
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _feedback(BuildContext context) {
    final strings = context.strings;
    final theme = Theme.of(context);
    final answer = _run.selectedAnswer;
    final responding = _run.phase == SnakePhase.feedback;
    final status =
        responding && answer != null
            ? strings.snakeAnswer(
              _run.item!.word,
              answer,
              correct: _run.answerCorrect,
            )
            : strings.snakeGuide;
    final color =
        !responding
            ? theme.colorScheme.onSurfaceVariant
            : _run.answerCorrect
            ? theme.colorScheme.primary
            : theme.colorScheme.error;
    return ArcadePanel(
      padding: const EdgeInsets.symmetric(horizontal: 11, vertical: 4),
      accent: responding ? color : null,
      child: ConstrainedBox(
        constraints: const BoxConstraints(minHeight: 40),
        child: Row(
          spacing: 5,
          children: [
            Expanded(
              child: Semantics(
                liveRegion: responding,
                child: Text(
                  status,
                  style: theme.textTheme.bodySmall?.copyWith(color: color),
                ),
              ),
            ),
            if (responding)
              TextButton(
                key: SnakeKeys.next,
                onPressed: _next,
                style: TextButton.styleFrom(
                  minimumSize: const Size(56, 44),
                  padding: const EdgeInsets.symmetric(horizontal: 6),
                ),
                child: Text(
                  widget.session.isFinished
                      ? strings.snakeResults
                      : strings.next,
                ),
              ),
          ],
        ),
      ),
    );
  }

  Widget _pausePanel(BuildContext context) {
    final strings = context.strings;
    return ClipRRect(
      borderRadius: BorderRadius.circular(12),
      child: ColoredBox(
        color: Theme.of(context).colorScheme.scrim.withValues(alpha: .57),
        child: Center(
          child: SizedBox(
            width: 216,
            child: ArcadePanel(
              padding: const EdgeInsets.all(12),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                spacing: 8,
                children: [
                  Text(
                    strings.snakePause,
                    style: Theme.of(context).textTheme.titleLarge,
                  ),
                  FilledButton(
                    key: SnakeKeys.resume,
                    onPressed: _start,
                    child: Text(strings.snakeResume),
                  ),
                  TextButton(onPressed: _exit, child: Text(strings.exit)),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _summary(BuildContext context) {
    final strings = context.strings;
    if (widget.session.total == 0) {
      return ArcadeStatusLayout(
        icon: Icons.nightlight_round,
        title: strings.nothingToday,
        body: Text(strings.comeBackTomorrow, textAlign: TextAlign.center),
        actions: FilledButton(onPressed: _exit, child: Text(strings.exit)),
      );
    }
    final mistakes = widget.mistakeCount?.call() ?? 0;
    final reason = [
      if (_run.hitTail) strings.snakeTail,
      if (_footer case final footer?) footer,
    ];
    return ArcadeRoundSummary(
      key: SnakeKeys.summary,
      score: _run.score,
      bestCombo: _run.bestCombo,
      correctCount: _run.correctCount,
      answeredCount: widget.session.answered,
      outOfLives: false,
      footer: reason.isEmpty ? null : reason.join('\n'),
      challengeRecord: _record,
      actions: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          if (mistakes > 0 && widget.onReviewMistakes != null)
            OutlinedButton(
              key: const Key('game.review_mistakes'),
              onPressed: widget.onReviewMistakes,
              child: Text(strings.reviewMistakesCount(mistakes)),
            ),
          FilledButton(
            onPressed: widget.onPlayAgain,
            child: Text(strings.playAgain),
          ),
          TextButton(onPressed: _exit, child: Text(strings.exit)),
        ],
      ),
    );
  }

  static String _directionName(AppStrings strings, SnakeDirection direction) =>
      switch (direction) {
        SnakeDirection.left => strings.snakeLeft,
        SnakeDirection.up => strings.snakeUp,
        SnakeDirection.down => strings.snakeDown,
        SnakeDirection.right => strings.snakeRight,
      };

  static IconData _directionIcon(SnakeDirection direction) =>
      switch (direction) {
        SnakeDirection.left => Icons.arrow_back_rounded,
        SnakeDirection.up => Icons.arrow_upward_rounded,
        SnakeDirection.down => Icons.arrow_downward_rounded,
        SnakeDirection.right => Icons.arrow_forward_rounded,
      };
}
