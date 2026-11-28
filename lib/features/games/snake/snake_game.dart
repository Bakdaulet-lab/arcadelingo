import 'dart:async';
import 'dart:math';

import 'package:arcadelingo/domain/ports/sounds.dart';
import 'package:arcadelingo/domain/ports/word_speech.dart';
import 'package:arcadelingo/domain/review/review_contract.dart';
import 'package:arcadelingo/domain/review/study_course.dart';
import 'package:arcadelingo/ui/app_strings.dart';
import 'package:arcadelingo/ui/arcade_answer_feedback.dart';
import 'package:arcadelingo/ui/arcade_panel.dart';
import 'package:arcadelingo/ui/arcade_round_summary.dart';
import 'package:arcadelingo/ui/arcade_status_layout.dart';
import 'package:arcadelingo/ui/theme.dart';
import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart';
import 'package:flutter/services.dart';

import 'snake_field.dart';
import 'snake_run.dart';

abstract final class SnakeKeys {
  static const field = Key('snake.field');
  static const word = Key('snake.word');
  static const pause = Key('snake.pause');
  static const resume = Key('snake.resume');
  static const finish = Key('snake.finish');
  static const next = Key('snake.next');
  static const summary = Key('snake.summary');
}

class SnakeGame extends StatefulWidget {
  const SnakeGame({
    required this.session,
    required this.vocabulary,
    required this.onPlayAgain,
    required this.onExit,
    this.continuous = false,
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
  final bool continuous;
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
  late final SnakeRun _run;
  static const _turnWindow = Duration(milliseconds: 85);
  final _motion = ValueNotifier(1.0);
  late final Ticker _ticker;
  Duration _lastFrame = Duration.zero;
  double _cellMicros = SnakeRun.stepTime.inMicroseconds.toDouble();
  final _reading = Stopwatch();
  bool _active = true;
  bool _roundComplete = false;
  String? _footer;
  Widget? _record;

  bool get _canSteer =>
      _run.phase == SnakePhase.ready || _run.phase == SnakePhase.moving;

  @override
  void initState() {
    super.initState();
    _run = SnakeRun(
      widget.session,
      widget.vocabulary,
      Random(widget.seed),
      continuous: widget.continuous,
    );
    _ticker = createTicker(_onFrame);
    WidgetsBinding.instance.addObserver(this);
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    _active = state == AppLifecycleState.resumed;
    if (!_active) {
      _pause();
      _ticker.stop();
      unawaited(widget.speech.stop());
    } else if (_run.phase == SnakePhase.feedback &&
        _motion.value < 1 &&
        !_ticker.isActive) {
      _lastFrame = Duration.zero;
      _ticker.start();
    }
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _ticker.dispose();
    _reading.stop();
    _motion.dispose();
    unawaited(widget.speech.stop());
    super.dispose();
  }

  void _turn(SnakeDirection direction) {
    if (!_active || !_canSteer || !_run.steer(direction)) return;
    if (_run.phase == SnakePhase.ready) {
      _start();
    } else {
      _approachCorner();
    }
  }

  // Reach the next legal corner promptly without jumping along the board.
  void _approachCorner() {
    final remaining = 1 - _motion.value;
    if (remaining > 0) {
      _cellMicros = min(_cellMicros, _turnWindow.inMicroseconds / remaining);
    }
  }

  void _start() {
    final resuming = _run.phase == SnakePhase.paused;
    if (!_active || !_run.start()) return;
    _reading.start();
    _lastFrame = Duration.zero;
    if (resuming) {
      setState(() {});
    } else {
      _advanceCell();
    }
    if (_run.phase != SnakePhase.finished) _ticker.start();
  }

  void _pause() {
    if (_run.phase != SnakePhase.moving) return;
    _run.pause();
    _stop();
    _cellMicros = _run.pace.inMicroseconds.toDouble();
    setState(() {});
  }

  void _stop() {
    _ticker.stop();
    _reading.stop();
  }

  void _exit() {
    _stop();
    unawaited(widget.speech.stop());
    widget.onExit();
  }

  void _onFrame(Duration elapsed) {
    final delta = (elapsed - _lastFrame).inMicroseconds;
    _lastFrame = elapsed;
    if (!_active || delta == 0) return;
    final remaining = (1 - _motion.value) * _cellMicros;
    if (delta < remaining) {
      _motion.value += delta / _cellMicros;
      return;
    }
    if (_run.phase != SnakePhase.moving) {
      _motion.value = 1;
      _ticker.stop();
      return;
    }
    _advanceCell();
    // Carry frame overshoot forward. A stalled frame must not play multiple
    // unseen moves or consume a second buffered corner before drawing it.
    _motion.value = ((delta - remaining) / _cellMicros).clamp(0, 1);
  }

  void _advanceCell() {
    final answered = widget.session.answered;
    _run.step(_reading.elapsed);
    _motion.value = 0;
    _cellMicros = _run.pace.inMicroseconds.toDouble();
    if (_run.hasQueuedTurn) _approachCorner();
    if (widget.session.answered != answered) {
      if (widget.continuous) {
        _reading.reset();
      } else {
        _reading.stop();
      }
      final answer = _run.selectedAnswer!;
      widget.sounds.play(
        _run.answerCorrect ? GameSound.clawCatch : GameSound.miss,
      );
      unawaited(widget.speech.speak(answer.text));
    }
    if (_run.phase == SnakePhase.finished) {
      _stop();
      _finish();
    }
    setState(() {});
  }

  void _endRun() {
    _stop();
    unawaited(widget.speech.stop());
    _run.finish();
    _finish();
    setState(() {});
  }

  void _next() {
    if (_run.phase != SnakePhase.feedback) return;
    _ticker.stop();
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
    final finishBeforeExit =
        widget.continuous &&
        phase != SnakePhase.finished &&
        phase != SnakePhase.ready;
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
          canPop: !finishBeforeExit,
          onPopInvokedWithResult: (didPop, _) {
            if (didPop) {
              _stop();
            } else if (finishBeforeExit) {
              _endRun();
            }
          },
          child: Scaffold(
            appBar: AppBar(
              leading: BackButton(
                onPressed: finishBeforeExit ? _endRun : _exit,
              ),
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
              SnakePlayfield(
                fieldKey: SnakeKeys.field,
                run: _run,
                motion: _motion,
                onTurn: _canSteer ? _turn : null,
                overlay: paused ? _pausePanel(context) : null,
              ),
              const SizedBox(height: 10),
              _feedback(context),
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
                widget.continuous
                    ? strings.continuousProgress(widget.session.answered + 1)
                    : strings.snakeCount(
                      _run.correctCount,
                      widget.session.total,
                    ),
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
    final responding = answer != null;
    final status =
        answer != null
            ? strings.snakeAnswer(
              _run.answeredWord!,
              answer,
              correct: _run.answerCorrect,
            )
            : widget.continuous
            ? strings.snakeContinuousGuide
            : strings.snakeGuide;
    final color =
        !responding
            ? theme.colorScheme.onSurfaceVariant
            : _run.answerCorrect
            ? theme.colorScheme.primary
            : theme.colorScheme.error;
    final message = Text(
      status,
      style: (responding
              ? theme.textTheme.bodyMedium
              : theme.textTheme.bodySmall)
          ?.copyWith(color: color),
    );
    return ArcadePanel(
      padding: const EdgeInsets.symmetric(horizontal: 11, vertical: 4),
      accent: responding ? color : null,
      child: ConstrainedBox(
        constraints: const BoxConstraints(minHeight: 40),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          mainAxisAlignment: MainAxisAlignment.center,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Semantics(
              liveRegion: responding,
              child:
                  responding
                      ? ArcadeAnswerFeedback(
                        key: ValueKey(widget.session.answered),
                        correct: _run.answerCorrect,
                        child: message,
                      )
                      : message,
            ),
            if (_run.phase == SnakePhase.feedback)
              Align(
                alignment: AlignmentDirectional.centerEnd,
                child: TextButton(
                  key: SnakeKeys.next,
                  onPressed: _next,
                  child: Text(
                    widget.session.isFinished
                        ? strings.snakeResults
                        : strings.next,
                  ),
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
          child: SingleChildScrollView(
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
                    if (widget.continuous)
                      TextButton(
                        key: SnakeKeys.finish,
                        onPressed: _endRun,
                        child: Text(strings.finishRun),
                      )
                    else
                      TextButton(onPressed: _exit, child: Text(strings.exit)),
                  ],
                ),
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
      if (_run.hitObstacle) strings.snakeObstacle,
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
}
