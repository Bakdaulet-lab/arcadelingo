import 'dart:async';
import 'dart:math';

import 'package:arcadelingo/domain/ports/sounds.dart';
import 'package:arcadelingo/domain/ports/word_speech.dart';
import 'package:arcadelingo/domain/review/review_contract.dart';
import 'package:arcadelingo/domain/review/study_course.dart';
import 'package:arcadelingo/domain/review/word_choices.dart';
import 'package:arcadelingo/ui/app_strings.dart';
import 'package:arcadelingo/ui/arcade_answer_feedback.dart';
import 'package:arcadelingo/ui/arcade_panel.dart';
import 'package:arcadelingo/ui/arcade_round_summary.dart';
import 'package:arcadelingo/ui/arcade_status_layout.dart';
import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart';

import 'maze_field.dart';
import 'maze_run.dart';

abstract final class MazeKeys {
  static const field = Key('maze.field');
  static const word = Key('maze.word');
  static const pause = Key('maze.pause');
  static const resume = Key('maze.resume');
  static const respawn = Key('maze.respawn');
  static const finish = Key('maze.finish');
  static const feedback = Key('maze.feedback');
  static const next = Key('maze.next');
  static const summary = Key('maze.summary');
  static ValueKey<String> gate(int index) => ValueKey('maze.gate.$index');
}

class WordMazeGame extends StatefulWidget {
  const WordMazeGame({
    required this.session,
    required this.vocabulary,
    required this.onPlayAgain,
    required this.onExit,
    this.continuous = false,
    this.course,
    this.level,
    this.sounds = const NoopSounds(),
    this.speech = const NoopWordSpeech(),
    this.summaryFooter,
    this.onRoundOver,
    this.onRoundScore,
    this.mistakeCount,
    this.onReviewMistakes,
    this.seed,
    super.key,
  });

  final bool continuous;
  final ReviewSession session;
  final List<Word> vocabulary;
  final VoidCallback onPlayAgain;
  final VoidCallback onExit;
  final StudyCourse? course;
  final CefrLevel? level;
  final Sounds sounds;
  final WordSpeech speech;
  final String Function()? summaryFooter;
  final VoidCallback? onRoundOver;
  final Widget Function(int score)? onRoundScore;
  final int Function()? mistakeCount;
  final VoidCallback? onReviewMistakes;
  final int? seed;

  @override
  State<WordMazeGame> createState() => _WordMazeGameState();
}

enum _Stage { ready, moving, paused, caught, feedback, finished }

class _WordMazeGameState extends State<WordMazeGame>
    with SingleTickerProviderStateMixin, WidgetsBindingObserver {
  late final Random _random;
  late final Ticker _ticker;
  final _frames = ValueNotifier(0);
  final _score = ValueNotifier(0);
  final _reading = Stopwatch();
  late MazeRun _run;
  late List<Word> _choices;
  ReviewItem? _item;
  Word? _selected;
  ({Word target, Word choice})? _lastAnswer;
  _Stage _stage = _Stage.ready;
  Duration _last = Duration.zero;
  int _correct = 0;
  int _combo = 0;
  int _bestCombo = 0;
  bool _startedRun = false;
  bool _active = true;
  bool _leaving = false;
  String? _footer;
  Widget? _record;

  bool get _finishBeforeExit =>
      widget.continuous && _startedRun && _stage != _Stage.finished;

  bool get _canContinueFromGate =>
      _stage == _Stage.feedback &&
      _selected!.id == _item!.word.id &&
      !widget.session.isFinished;

  @override
  void initState() {
    super.initState();
    _random = Random(widget.seed);
    _ticker = createTicker(_onFrame);
    WidgetsBinding.instance.addObserver(this);
    _loadQuestion();
  }

  void _loadQuestion({bool carry = false}) {
    _selected = null;
    _item = widget.session.nextItem();
    final question = _item;
    if (question == null) {
      _stage = _Stage.finished;
      return;
    }
    _choices = [
      question.word,
      ...wordDistractors(question, widget.vocabulary, _random).take(2),
    ]..shuffle(_random);
    if (carry) {
      _run.nextGates(gateCount: _choices.length, correctAnswers: _correct);
    } else {
      _run = MazeRun(
        seed: _random.nextInt(1 << 30),
        gateCount: _choices.length,
        correctAnswers: _correct,
        wave: widget.session.answered,
      );
    }
    _reading
      ..reset()
      ..start();
    _stage = carry ? _Stage.moving : _Stage.ready;
  }

  void _turn(MazeDirection direction) {
    if (!_active || (_stage != _Stage.ready && _stage != _Stage.moving)) return;
    _run.steer(direction);
    if (_stage == _Stage.ready && _run.moving) {
      setState(() {
        _startedRun = true;
        _stage = _Stage.moving;
      });
      _startTicker();
    }
  }

  void _continueToward(MazeDirection direction) {
    if (!_active || _leaving || !_canContinueFromGate) return;
    _next();
    _turn(direction);
  }

  void _startTicker() {
    _last = Duration.zero;
    _ticker.start();
  }

  void _onFrame(Duration elapsed) {
    final micros = (elapsed - _last).inMicroseconds;
    _last = elapsed;
    if (!_active || _stage != _Stage.moving || micros <= 0) return;
    // Do not replay an unseen chase if the platform stalls for several seconds.
    final before = _run.collected;
    final event = _run.advance(
      min(micros, 64000) / Duration.microsecondsPerSecond,
    );
    _frames.value++;
    if (_run.collected > before) _score.value += (_run.collected - before) * 5;
    if (event == null) return;
    _reading.stop();
    switch (event) {
      case MazeEvent.caught:
        _ticker.stop();
        _combo = 0;
        widget.sounds.play(GameSound.miss);
        setState(() => _stage = _Stage.caught);
      case MazeEvent.gate:
        final target = _item!.word;
        final choice = _choices[_run.selectedGate!];
        final correct = choice.id == target.id;
        widget.session.report(
          ReviewOutcome.untimed(
            correct: correct,
            responseTime: _reading.elapsed,
            selectedAnswer: choice.text,
          ),
        );
        if (correct) {
          _correct++;
          _bestCombo = max(_bestCombo, ++_combo);
          _score.value += 100;
        } else {
          _combo = 0;
        }
        widget.sounds.play(correct ? GameSound.clawCatch : GameSound.miss);
        unawaited(widget.speech.speak(target.text));
        if (widget.continuous) {
          _lastAnswer = (target: target, choice: choice);
          setState(() => _loadQuestion(carry: true));
          if (_stage == _Stage.finished) _complete();
          return;
        }
        _ticker.stop();
        setState(() {
          _selected = choice;
          _stage = _Stage.feedback;
        });
    }
  }

  void _pause() {
    if (_stage != _Stage.moving) return;
    _ticker.stop();
    _reading.stop();
    setState(() => _stage = _Stage.paused);
  }

  void _resume() {
    if (!_active || _stage != _Stage.paused) return;
    setState(() => _stage = _Stage.moving);
    _reading.start();
    _startTicker();
  }

  void _respawn() {
    if (!_active || _stage != _Stage.caught) return;
    _run.respawn();
    _frames.value++;
    _reading.start();
    setState(() => _stage = _Stage.ready);
  }

  void _next() {
    if (_leaving || _stage != _Stage.feedback) return;
    unawaited(widget.speech.stop());
    setState(_loadQuestion);
    if (_stage == _Stage.finished) _complete();
  }

  void _finishRun() {
    if (!_finishBeforeExit) return;
    unawaited(widget.speech.stop());
    setState(() {
      _item = null;
      _stage = _Stage.finished;
    });
    _complete();
  }

  void _complete() {
    _ticker.stop();
    _reading.stop();
    _footer = widget.summaryFooter?.call();
    if (widget.session.answered > 0) {
      _record = widget.onRoundScore?.call(_score.value);
    }
    widget.sounds.play(GameSound.roundEnd);
    widget.onRoundOver?.call();
  }

  void _exit() {
    _leave();
    widget.onExit();
  }

  void _leave() {
    if (_leaving) return;
    _leaving = true;
    _active = false;
    _ticker.stop();
    _reading.stop();
    if (!widget.continuous && _item != null && _selected == null) {
      widget.session.report(
        ReviewOutcome.untimed(correct: false, responseTime: _reading.elapsed),
      );
    }
    unawaited(widget.speech.stop());
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (_leaving) return;
    final active = state == AppLifecycleState.resumed;
    if (_active == active) return;
    _active = active;
    if (_canContinueFromGate) setState(() {});
    if (!_active) {
      _pause();
      _reading.stop();
      unawaited(widget.speech.stop());
    } else if (_stage == _Stage.ready) {
      _reading.start();
    }
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _leave();
    _ticker.dispose();
    _frames.dispose();
    _score.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final strings = context.strings;
    return PopScope<void>(
      canPop: !_finishBeforeExit,
      onPopInvokedWithResult: (didPop, _) {
        if (didPop) {
          _leave();
        } else if (_finishBeforeExit) {
          _finishRun();
        }
      },
      child: Scaffold(
        appBar: AppBar(
          leading: BackButton(
            onPressed: _finishBeforeExit ? _finishRun : _exit,
          ),
          title: Text(strings.wordMaze),
          actions: [
            if (_stage != _Stage.finished)
              IconButton.filledTonal(
                key: MazeKeys.pause,
                tooltip: strings.snakePause,
                onPressed: _stage == _Stage.moving ? _pause : null,
                icon: const Icon(Icons.pause_rounded),
              ),
            const SizedBox(width: 10),
          ],
        ),
        body:
            _stage == _Stage.finished ? _summary(context) : _gameplay(context),
      ),
    );
  }

  Widget _summary(BuildContext context) {
    final strings = context.strings;
    if (!widget.continuous && widget.session.answered == 0) {
      return ArcadeStatusLayout(
        icon: Icons.nightlight_round,
        title: strings.nothingToday,
        body: Text(strings.comeBackTomorrow, textAlign: TextAlign.center),
        actions: FilledButton(onPressed: _exit, child: Text(strings.exit)),
      );
    }
    final mistakes = widget.mistakeCount?.call() ?? 0;
    return ArcadeRoundSummary(
      key: MazeKeys.summary,
      score: _score.value,
      bestCombo: _bestCombo,
      correctCount: _correct,
      answeredCount: widget.session.answered,
      outOfLives: false,
      footer: _footer,
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

  Widget _gameplay(BuildContext context) {
    final strings = context.strings;
    final theme = Theme.of(context);
    final course = widget.course;
    final level = widget.level;
    final left = _stage == _Stage.paused || _stage == _Stage.caught;
    final field = Stack(
      alignment: Alignment.center,
      children: [
        AspectRatio(
          // In classic play a gate waits for a fresh swipe. Continuous play
          // keeps the same pointer and the same board across answers.
          key: ValueKey(widget.continuous ? -1 : widget.session.answered),
          aspectRatio: MazeRun.columns / MazeRun.rows,
          child: MazeField(
            key: MazeKeys.field,
            run: _run,
            frames: _frames,
            boardLabel: strings.mazeBoard,
            gateLabels: [for (final word in _choices) word.text],
            onTurn: switch (_stage) {
              _Stage.ready || _Stage.moving => _turn,
              _Stage.feedback when _active && _canContinueFromGate =>
                _continueToward,
              _ => null,
            },
          ),
        ),
        if (left) Positioned.fill(child: _overlay(context)),
      ],
    );
    final question = _item!.word;
    final answered = _selected;
    final number = widget.session.answered + (answered == null ? 1 : 0);
    final prompt = ArcadePanel(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      accent: theme.colorScheme.primary,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  widget.continuous
                      ? strings.continuousProgress(number)
                      : strings.mazeProgress(number, widget.session.total),
                  style: theme.textTheme.labelMedium?.copyWith(
                    color: theme.colorScheme.onSurfaceVariant,
                  ),
                ),
              ),
              ValueListenableBuilder<int>(
                valueListenable: _score,
                builder:
                    (_, score, _) => Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(
                          Icons.stars_rounded,
                          size: 16,
                          color: theme.colorScheme.primary,
                        ),
                        const SizedBox(width: 4),
                        Semantics(
                          label: strings.score(score),
                          excludeSemantics: true,
                          child: Text(
                            '$score',
                            style: theme.textTheme.labelLarge,
                          ),
                        ),
                      ],
                    ),
              ),
            ],
          ),
          const SizedBox(height: 4),
          Text(
            question.translation,
            key: MazeKeys.word,
            style: theme.textTheme.headlineSmall?.copyWith(
              fontWeight: FontWeight.w700,
            ),
          ),
        ],
      ),
    );
    final legend = _gateLegend(context);
    final last = _lastAnswer;
    final lastCorrect = last == null ? null : last.target.id == last.choice.id;
    final (guideIcon, guideColor) = switch (lastCorrect) {
      true => (Icons.check_circle_outline_rounded, theme.colorScheme.primary),
      false => (Icons.info_outline_rounded, theme.colorScheme.error),
      null => (Icons.swipe_outlined, theme.colorScheme.onSurfaceVariant),
    };
    final guideText =
        last != null
            ? strings.snakeAnswer(
              last.target,
              last.choice,
              correct: lastCorrect!,
            )
            : _stage == _Stage.ready
            ? strings.mazeReadyGuide
            : strings.mazeSteering;
    final guidance = Semantics(
      liveRegion: last != null,
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(guideIcon, color: guideColor, size: 17),
          const SizedBox(width: 7),
          Expanded(
            child: Text(
              guideText,
              style: theme.textTheme.bodySmall?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
              ),
            ),
          ),
        ],
      ),
    );
    final foot = AnimatedSwitcher(
      duration:
          MediaQuery.disableAnimationsOf(context)
              ? Duration.zero
              : const Duration(milliseconds: 160),
      child:
          answered == null
              ? Column(
                key: const ValueKey('guide'),
                crossAxisAlignment: CrossAxisAlignment.stretch,
                spacing: 10,
                children: [legend, guidance],
              )
              : _feedback(context, question, answered),
    );
    final scope = Wrap(
      spacing: 8,
      crossAxisAlignment: WrapCrossAlignment.center,
      children: [
        if (course != null)
          Text(strings.courseName(course), style: theme.textTheme.labelMedium),
        if (level != null)
          Text(
            level.name.toUpperCase(),
            style: theme.textTheme.labelLarge?.copyWith(
              color: theme.colorScheme.primary,
            ),
          ),
      ],
    );
    return SafeArea(
      child: LayoutBuilder(
        builder: (context, available) {
          final wide =
              available.maxWidth >= 680 &&
              available.maxHeight < available.maxWidth;
          return Align(
            alignment: Alignment.topCenter,
            child: SingleChildScrollView(
              padding: const EdgeInsets.fromLTRB(14, 4, 14, 18),
              child: ConstrainedBox(
                constraints: BoxConstraints(maxWidth: wide ? 900 : 470),
                child:
                    wide
                        ? Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Expanded(flex: 6, child: field),
                            const SizedBox(width: 14),
                            Expanded(
                              flex: 5,
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.stretch,
                                spacing: 12,
                                children: [scope, prompt, foot],
                              ),
                            ),
                          ],
                        )
                        : Column(
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          spacing: 10,
                          children: [
                            if (course != null || level != null) scope,
                            prompt,
                            field,
                            foot,
                          ],
                        ),
              ),
            ),
          );
        },
      ),
    );
  }

  Widget _gateLegend(BuildContext context) {
    final theme = Theme.of(context);
    final style = theme.textTheme.titleSmall!.copyWith(
      fontSize: 16,
      height: 1.25,
    );
    const gap = 8.0;
    const padding = EdgeInsets.fromLTRB(6, 6, 10, 6);
    const badgeSize = 26.0;
    const labelGap = 8.0;
    return LayoutBuilder(
      builder: (context, constraints) {
        // Put all signs in one row only when each complete label fits.
        final measure = TextPainter(
          textScaler: MediaQuery.textScalerOf(context),
          textDirection: Directionality.of(context),
          locale: Localizations.localeOf(context),
        );
        var ideal = -gap;
        for (final choice in _choices) {
          measure.text = TextSpan(text: choice.text, style: style);
          measure.layout();
          ideal +=
              measure.maxIntrinsicWidth.ceilToDouble() +
              badgeSize +
              labelGap +
              padding.horizontal +
              gap;
        }
        measure.dispose();
        final inline =
            ideal <= constraints.maxWidth &&
            _choices.every((word) => !word.text.contains('\n'));
        return Wrap(
          spacing: gap,
          runSpacing: 6,
          children: [
            for (final (index, choice) in _choices.indexed)
              Container(
                width: inline ? null : constraints.maxWidth,
                padding: padding,
                decoration: BoxDecoration(
                  color: theme.colorScheme.surfaceContainerHigh,
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    MazeGateBadge(index: index),
                    const SizedBox(width: labelGap),
                    Flexible(
                      child: Text(
                        choice.text,
                        key: MazeKeys.gate(index),
                        style: style,
                      ),
                    ),
                  ],
                ),
              ),
          ],
        );
      },
    );
  }

  Widget _feedback(BuildContext context, Word target, Word choice) {
    final strings = context.strings;
    final theme = Theme.of(context);
    final correct = target.id == choice.id;
    final color = correct ? theme.colorScheme.primary : theme.colorScheme.error;
    return ArcadeAnswerFeedback(
      key: MazeKeys.feedback,
      correct: correct,
      child: ArcadePanel(
        accent: color,
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 9),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Semantics(
              liveRegion: true,
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Icon(
                    correct
                        ? Icons.check_circle_outline_rounded
                        : Icons.info_outline_rounded,
                    color: color,
                    size: 20,
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      strings.snakeAnswer(target, choice, correct: correct),
                      style: theme.textTheme.bodyMedium,
                    ),
                  ),
                ],
              ),
            ),
            Wrap(
              alignment: WrapAlignment.end,
              crossAxisAlignment: WrapCrossAlignment.center,
              spacing: 10,
              children: [
                if (_canContinueFromGate)
                  Text(
                    strings.mazeContinueSwipe,
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: theme.colorScheme.onSurfaceVariant,
                    ),
                  ),
                TextButton.icon(
                  key: MazeKeys.next,
                  onPressed: _next,
                  icon: const Icon(Icons.arrow_forward_rounded, size: 18),
                  label: Text(
                    widget.session.isFinished
                        ? strings.snakeResults
                        : strings.next,
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _overlay(BuildContext context) {
    final strings = context.strings;
    final theme = Theme.of(context);
    final caught = _stage == _Stage.caught;
    return ClipRRect(
      borderRadius: BorderRadius.circular(16),
      child: ColoredBox(
        color: theme.colorScheme.scrim.withValues(alpha: .64),
        child: Center(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: SingleChildScrollView(
              child: ArcadePanel(
                padding: const EdgeInsets.all(12),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      caught ? strings.mazeCaught : strings.snakePause,
                      textAlign: TextAlign.center,
                      style: theme.textTheme.titleMedium,
                    ),
                    const SizedBox(height: 8),
                    FilledButton.icon(
                      key: caught ? MazeKeys.respawn : MazeKeys.resume,
                      onPressed: caught ? _respawn : _resume,
                      icon: Icon(
                        caught
                            ? Icons.replay_rounded
                            : Icons.play_arrow_rounded,
                      ),
                      label: Text(
                        caught ? strings.mazeTryAgain : strings.snakeResume,
                      ),
                    ),
                    if (widget.continuous)
                      TextButton(
                        key: MazeKeys.finish,
                        onPressed: _finishRun,
                        child: Text(strings.finishRun),
                      ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
