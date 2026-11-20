import 'dart:async';
import 'dart:math';

import 'package:arcadelingo/domain/ports/sounds.dart';
import 'package:arcadelingo/domain/ports/word_speech.dart';
import 'package:arcadelingo/domain/review/review_contract.dart';
import 'package:arcadelingo/ui/app_strings.dart';
import 'package:arcadelingo/ui/arcade_panel.dart';
import 'package:arcadelingo/ui/arcade_round_summary.dart';
import 'package:arcadelingo/ui/arcade_status_layout.dart';
import 'package:arcadelingo/ui/theme.dart';
import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart';
import 'package:flutter/services.dart';

import 'brick_breaker_field.dart';
import 'brick_breaker_run.dart';

abstract final class BrickBreakerKeys {
  static const launch = Key('brick_breaker.launch');
  static const field = Key('brick_breaker.field');
  static const word = Key('brick_breaker.word');
  static const summary = Key('brick_breaker.summary');
}

class BrickBreakerGame extends StatefulWidget {
  const BrickBreakerGame({
    required this.session,
    required this.onExit,
    required this.onPlayAgain,
    this.onRoundOver,
    this.summaryFooter,
    this.onRoundScore,
    this.mistakeCount,
    this.onReviewMistakes,
    this.sounds = const NoopSounds(),
    this.speech = const NoopWordSpeech(),
    this.seed,
    super.key,
  });

  final ReviewSession session;
  final VoidCallback onExit;
  final VoidCallback onPlayAgain;
  final VoidCallback? onRoundOver;
  final String Function()? summaryFooter;
  final Widget Function(int score)? onRoundScore;
  final int Function()? mistakeCount;
  final VoidCallback? onReviewMistakes;
  final Sounds sounds;
  final WordSpeech speech;
  final int? seed;

  @override
  State<BrickBreakerGame> createState() => _BrickBreakerGameState();
}

class _BrickBreakerGameState extends State<BrickBreakerGame>
    with SingleTickerProviderStateMixin {
  late final BrickBreakerRun _run;
  late final Ticker _ticker;
  late final AppLifecycleListener _lifecycle;
  Duration _previous = Duration.zero;
  bool _paused = false;
  bool _inBackground = false;
  bool _leaving = false;
  String? _footer;
  Widget? _record;

  @override
  void initState() {
    super.initState();
    _run = BrickBreakerRun(widget.session, Random(widget.seed));
    _ticker = createTicker(_tick);
    _lifecycle = AppLifecycleListener(onStateChange: _onLifecycle);
    final state = WidgetsBinding.instance.lifecycleState;
    _inBackground = state != null && state != AppLifecycleState.resumed;
  }

  @override
  void dispose() {
    _abandon();
    _lifecycle.dispose();
    _ticker.dispose();
    super.dispose();
  }

  void _abandon() {
    if (_leaving) return;
    _leaving = true;
    _ticker.stop();
    unawaited(widget.speech.stop());
    _run.abandon();
  }

  void _onLifecycle(AppLifecycleState state) {
    _inBackground = state != AppLifecycleState.resumed;
    if (_inBackground) {
      _ticker.stop();
      unawaited(widget.speech.stop());
      if (_run.phase != BrickPhase.serve && _run.phase != BrickPhase.finished) {
        setState(() => _paused = true);
      }
    }
  }

  void _tick(Duration elapsed) {
    final previousPhase = _run.phase;
    final delta = elapsed - _previous;
    _previous = elapsed;
    setState(() {
      _run.advance(
        delta > const Duration(milliseconds: 40)
            ? const Duration(milliseconds: 40)
            : delta,
      );
      if (_run.phase == BrickPhase.finished) {
        _footer = widget.summaryFooter?.call();
        _record = widget.onRoundScore?.call(_run.score);
      }
    });
    if (previousPhase == _run.phase) return;
    switch (_run.phase) {
      case BrickPhase.bonus:
        _speak();
      case BrickPhase.feedback:
        unawaited(widget.speech.stop());
        widget.sounds.play(
          _run.caughtCorrect ? GameSound.clawWord : GameSound.miss,
        );
      case BrickPhase.serve:
        unawaited(widget.speech.stop());
        _ticker.stop();
      case BrickPhase.finished:
        _ticker.stop();
        widget.sounds.play(GameSound.roundEnd);
        widget.onRoundOver?.call();
      case BrickPhase.flying:
        break;
    }
  }

  void _speak() {
    if (_run.item case final item?) {
      unawaited(widget.speech.speak(item.word.text));
    }
  }

  void _action() {
    if (_inBackground || _leaving) return;
    if (_ticker.isActive) {
      _ticker.stop();
      unawaited(widget.speech.stop());
      setState(() => _paused = true);
      return;
    }
    setState(() {
      _paused = false;
      _run.launch();
    });
    _previous = Duration.zero;
    _ticker.start();
  }

  void _move(double position) {
    if (_paused || _leaving || _inBackground) return;
    setState(() => _run.movePaddle(position));
  }

  KeyEventResult _onKey(FocusNode node, KeyEvent event) {
    if (event is KeyUpEvent) return KeyEventResult.ignored;
    if (event.logicalKey == LogicalKeyboardKey.arrowLeft) {
      _move(_run.paddle - 18);
    } else if (event.logicalKey == LogicalKeyboardKey.arrowRight) {
      _move(_run.paddle + 18);
    } else {
      return KeyEventResult.ignored;
    }
    return KeyEventResult.handled;
  }

  @override
  Widget build(BuildContext context) => PopScope<void>(
    onPopInvokedWithResult: (didPop, _) {
      if (didPop) _abandon();
    },
    child: Scaffold(
      appBar: AppBar(
        leading: BackButton(onPressed: widget.onExit),
        title: Text(context.strings.brickBreaker),
      ),
      body:
          _run.phase == BrickPhase.finished ? _end(context) : _active(context),
    ),
  );

  Widget _active(BuildContext context) {
    final strings = context.strings;
    final theme = Theme.of(context);
    final colors = theme.colorScheme;
    final bonus = _run.phase == BrickPhase.bonus;
    final feedback = _run.phase == BrickPhase.feedback;
    final word = _run.item?.word;
    final caption = switch (_run.phase) {
      BrickPhase.bonus => strings.brickCatch,
      BrickPhase.feedback =>
        _run.caughtCorrect
            ? strings.brickMultiball
            : '${word!.text} · ${word.translation}',
      BrickPhase.serve when _run.missedDrop => strings.brickMissed,
      BrickPhase.serve when _run.balls.length > 1 => strings.brickMultiball,
      _ => strings.brickGold,
    };
    return SafeArea(
      child: Focus(
        autofocus: true,
        onKeyEvent: _onKey,
        child: Align(
          alignment: Alignment.topCenter,
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 430),
            child: SingleChildScrollView(
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Wrap(
                    alignment: WrapAlignment.spaceBetween,
                    crossAxisAlignment: WrapCrossAlignment.center,
                    spacing: 12,
                    runSpacing: 4,
                    children: [
                      Text(
                        strings.score(_run.score),
                        style: theme.textTheme.titleMedium,
                      ),
                      Text(
                        strings.lives(
                          _run.lives,
                          BrickBreakerRun.startingLives,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 10),
                  ArcadePanel(
                    padding: const EdgeInsets.all(8),
                    accent: bonus ? colors.tertiary : colors.primary,
                    child: Column(
                      children: [
                        SizedBox(
                          height: 52,
                          child: Stack(
                            alignment: Alignment.center,
                            children: [
                              if (bonus && word != null)
                                Padding(
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 48,
                                  ),
                                  child: FittedBox(
                                    fit: BoxFit.scaleDown,
                                    child: Text(
                                      word.text,
                                      key: BrickBreakerKeys.word,
                                      style: withWeight(
                                        theme.textTheme.headlineSmall!,
                                        FontWeight.bold,
                                      ),
                                    ),
                                  ),
                                )
                              else
                                Text(
                                  strings.brickField(_run.field),
                                  style: theme.textTheme.titleMedium,
                                ),
                              if (bonus && widget.speech is! NoopWordSpeech)
                                Align(
                                  alignment: AlignmentDirectional.centerEnd,
                                  child: IconButton(
                                    onPressed: _paused ? null : _speak,
                                    tooltip: strings.listen,
                                    icon: const Icon(Icons.volume_up_outlined),
                                  ),
                                ),
                            ],
                          ),
                        ),
                        Stack(
                          fit: StackFit.passthrough,
                          alignment: Alignment.center,
                          children: [
                            BrickBreakerField(
                              key: BrickBreakerKeys.field,
                              run: _run,
                              onMove: _move,
                            ),
                            if (_paused || feedback)
                              ArcadePanel(
                                accent:
                                    feedback && !_run.caughtCorrect
                                        ? colors.error
                                        : colors.primary,
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 18,
                                  vertical: 14,
                                ),
                                child: Text(
                                  _paused
                                      ? strings.brickPaused
                                      : _run.caughtCorrect
                                      ? strings.correct
                                      : strings.mistake,
                                  style: theme.textTheme.titleLarge,
                                ),
                              ),
                          ],
                        ),
                        Padding(
                          padding: const EdgeInsets.all(8),
                          child: Semantics(
                            liveRegion: true,
                            child: Text(
                              caption,
                              textAlign: TextAlign.center,
                              style: TextStyle(color: colors.onSurfaceVariant),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 12),
                  Text(
                    strings.brickMove,
                    textAlign: TextAlign.center,
                    style: theme.textTheme.bodySmall,
                  ),
                  const SizedBox(height: 8),
                  FilledButton(
                    key: BrickBreakerKeys.launch,
                    onPressed: _action,
                    child: Text(
                      _paused
                          ? strings.brickResume
                          : _run.phase == BrickPhase.serve
                          ? strings.brickLaunch
                          : strings.brickPause,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _end(BuildContext context) {
    final strings = context.strings;
    if (widget.session.total == 0) {
      return ArcadeStatusLayout(
        icon: Icons.nightlight_round,
        title: strings.nothingToday,
        body: Text(strings.comeBackTomorrow, textAlign: TextAlign.center),
        actions: FilledButton(
          onPressed: widget.onExit,
          child: Text(strings.exit),
        ),
      );
    }
    final mistakes = widget.mistakeCount?.call() ?? 0;
    return ArcadeRoundSummary(
      key: BrickBreakerKeys.summary,
      score: _run.score,
      bestCombo: _run.bestCombo,
      correctCount: _run.correctCount,
      answeredCount: widget.session.answered,
      outOfLives: _run.lives == 0,
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
          TextButton(onPressed: widget.onExit, child: Text(strings.exit)),
        ],
      ),
    );
  }
}
