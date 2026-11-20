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

import 'match_three_field.dart';
import 'match_three_run.dart';

export 'match_three_field.dart' show MatchThreeKeys;

class MatchThreeGame extends StatefulWidget {
  const MatchThreeGame({
    required this.session,
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

  final ReviewSession session;
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
  State<MatchThreeGame> createState() => _MatchThreeGameState();
}

class _MatchThreeGameState extends State<MatchThreeGame>
    with SingleTickerProviderStateMixin {
  late final MatchThreeRun _run;
  late final AnimationController _motion;
  late final AppLifecycleListener _lifecycle;
  final Stopwatch _reading = Stopwatch();
  int? _selected;
  bool _background = false;
  bool _leaving = false;
  String? _footer;
  Widget? _record;

  @override
  void initState() {
    super.initState();
    _run = MatchThreeRun(widget.session, Random(widget.seed));
    _motion = AnimationController(
      vsync: this,
      animationBehavior: AnimationBehavior.preserve,
    )..addStatusListener(_onMotion);
    final state = WidgetsBinding.instance.lifecycleState;
    _background = state != null && state != AppLifecycleState.resumed;
    _lifecycle = AppLifecycleListener(onStateChange: _onLifecycle);
  }

  @override
  void dispose() {
    _abandon();
    _motion.dispose();
    _lifecycle.dispose();
    super.dispose();
  }

  void _abandon() {
    if (_leaving) return;
    _leaving = true;
    _motion.stop();
    _reading.stop();
    _run.abandon(_reading.elapsed);
    unawaited(widget.speech.stop());
  }

  void _onLifecycle(AppLifecycleState state) {
    if (_leaving) return;
    _background = state != AppLifecycleState.resumed;
    if (_background) {
      _motion.stop(canceled: false);
      _reading.stop();
      unawaited(widget.speech.stop());
    } else if (_run.isAnimating) {
      _motion.forward();
    } else if (_run.phase == MatchThreePhase.question) {
      _reading.start();
    }
  }

  void _select(int index) {
    if (_background || _leaving || _run.phase != MatchThreePhase.ready) return;
    final selected = _selected;
    if (selected != null && MatchThreeRun.adjacent(selected, index)) {
      _swap(selected, index);
    } else {
      setState(() => _selected = selected == index ? null : index);
    }
  }

  void _swap(int from, int to) {
    if (_background || _leaving || _run.phase != MatchThreePhase.ready) return;
    final started = _run.swap(from, to);
    setState(() => _selected = started ? null : to);
    if (started) _animate();
  }

  void _answer(String value) {
    if (_background || _leaving || !_run.answer(value, _reading.elapsed)) {
      return;
    }
    _reading.stop();
    unawaited(widget.speech.stop());
    widget.sounds.play(
      _run.answerCorrect ? GameSound.clawWord : GameSound.miss,
    );
    _animate();
  }

  void _speak() {
    if (_run.item case final item?) {
      unawaited(widget.speech.speak(item.word.text));
    }
  }

  void _animate() {
    final duration = switch (_run.phase) {
      MatchThreePhase.swapping || MatchThreePhase.reverting => 145,
      MatchThreePhase.clearing => _run.rowCleared ? 250 : 150,
      MatchThreePhase.falling => 245,
      MatchThreePhase.feedback => 900,
      _ => 1,
    };
    final reduced = MediaQuery.disableAnimationsOf(context);
    _motion.duration = Duration(
      milliseconds:
          reduced && _run.phase != MatchThreePhase.feedback ? 1 : duration,
    );
    _motion.forward(from: 0);
    setState(() {});
  }

  void _onMotion(AnimationStatus status) {
    if (status != AnimationStatus.completed || _leaving || !_run.isAnimating) {
      return;
    }
    _run.advance();
    if (_run.isAnimating) {
      _animate();
      return;
    }
    if (_run.phase == MatchThreePhase.question) {
      _reading
        ..reset()
        ..start();
      unawaited(HapticFeedback.lightImpact());
      _speak();
    } else if (_run.phase == MatchThreePhase.finished) {
      _footer = widget.summaryFooter?.call();
      _record = widget.onRoundScore?.call(_run.score);
      widget.sounds.play(GameSound.roundEnd);
      widget.onRoundOver?.call();
    }
    setState(() {});
  }

  @override
  Widget build(BuildContext context) => PopScope<void>(
    onPopInvokedWithResult: (didPop, _) {
      if (didPop) _abandon();
    },
    child: Scaffold(
      appBar: AppBar(
        leading: BackButton(onPressed: widget.onExit),
        title: Text(context.strings.matchThree),
      ),
      body:
          _run.phase == MatchThreePhase.finished
              ? _summary(context)
              : _board(context),
    ),
  );

  Widget _board(BuildContext context) {
    final strings = context.strings;
    final theme = Theme.of(context);
    return SafeArea(
      child: Align(
        alignment: Alignment.topCenter,
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 440),
          child: SingleChildScrollView(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                if (widget.course case final course?)
                  Padding(
                    padding: const EdgeInsets.only(bottom: 10),
                    child: Text(
                      [
                        strings.courseName(course),
                        if (widget.level case final level?)
                          level.name.toUpperCase(),
                      ].join('  ·  '),
                      style: theme.textTheme.labelLarge?.copyWith(
                        color: theme.colorScheme.onSurfaceVariant,
                      ),
                    ),
                  ),
                Wrap(
                  alignment: WrapAlignment.spaceBetween,
                  spacing: 12,
                  runSpacing: 4,
                  children: [
                    Text(
                      strings.score(_run.score),
                      style: theme.textTheme.titleMedium,
                    ),
                    Text(
                      strings.matchMoves(_run.moves),
                      style: theme.textTheme.titleMedium,
                    ),
                  ],
                ),
                const SizedBox(height: 10),
                MatchThreeField(
                  key: MatchThreeKeys.field,
                  run: _run,
                  motion: _motion,
                  selected: _selected,
                  onTap: _select,
                  onSwap: _swap,
                ),
                const SizedBox(height: 12),
                if (_run.item case final item?)
                  _wordPanel(context, item.word)
                else
                  _status(context),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _status(BuildContext context) {
    final strings = context.strings;
    final colors = Theme.of(context).colorScheme;
    final text =
        _run.rowCleared
            ? strings.matchCleared
            : _run.invalidMove
            ? strings.matchInvalidMove
            : _run.showGuide
            ? strings.matchGuide
            : strings.matchHint;
    return ArcadePanel(
      padding: const EdgeInsets.all(12),
      child: Row(
        children: [
          Icon(Icons.auto_awesome_rounded, color: colors.tertiary),
          const SizedBox(width: 10),
          Expanded(child: Semantics(liveRegion: true, child: Text(text))),
        ],
      ),
    );
  }

  Widget _wordPanel(BuildContext context, Word word) {
    final strings = context.strings;
    final theme = Theme.of(context);
    final colors = theme.colorScheme;
    final feedback = _run.phase == MatchThreePhase.feedback;
    return ArcadePanel(
      accent: colors.tertiary,
      padding: const EdgeInsets.all(11),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              Icon(Icons.auto_awesome_rounded, color: colors.tertiary),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      strings.matchBonus,
                      style: theme.textTheme.labelMedium,
                    ),
                    Text(
                      word.text,
                      key: MatchThreeKeys.word,
                      style: withWeight(
                        theme.textTheme.headlineSmall!,
                        FontWeight.bold,
                      ),
                    ),
                  ],
                ),
              ),
              if (widget.speech is! NoopWordSpeech)
                IconButton(
                  tooltip: strings.listen,
                  onPressed: feedback ? null : _speak,
                  icon: const Icon(Icons.volume_up_outlined),
                ),
            ],
          ),
          const SizedBox(height: 8),
          LayoutBuilder(
            builder: (context, constraints) {
              final options = _run.choices;
              final row =
                  constraints.maxWidth >= 220 &&
                  MediaQuery.textScalerOf(context).scale(14) <= 16 &&
                  options.every((text) => text.characters.length <= 13);
              final buttons = [
                for (final choice in options)
                  OutlinedButton(
                    style: OutlinedButton.styleFrom(
                      minimumSize: const Size(0, 45),
                      padding: const EdgeInsets.symmetric(
                        horizontal: 6,
                        vertical: 7,
                      ),
                      side:
                          feedback && choice == _run.selectedAnswer
                              ? BorderSide(
                                color:
                                    _run.answerCorrect
                                        ? colors.primary
                                        : colors.error,
                              )
                              : null,
                    ),
                    onPressed: feedback ? null : () => _answer(choice),
                    child: Text(choice, textAlign: TextAlign.center),
                  ),
              ];
              return row
                  ? Row(
                    spacing: 5,
                    children: [
                      for (final button in buttons) Expanded(child: button),
                    ],
                  )
                  : Column(
                    spacing: 6,
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: buttons,
                  );
            },
          ),
          if (feedback) ...[
            const SizedBox(height: 7),
            Semantics(
              liveRegion: true,
              child: Text(
                _run.answerCorrect
                    ? strings.correct
                    : '${strings.correctTranslation} — ${word.translation}',
                style: TextStyle(
                  color: _run.answerCorrect ? colors.primary : colors.error,
                ),
              ),
            ),
          ],
        ],
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
        actions: FilledButton(
          onPressed: widget.onExit,
          child: Text(strings.exit),
        ),
      );
    }
    final mistakes = widget.mistakeCount?.call() ?? 0;
    return ArcadeRoundSummary(
      key: MatchThreeKeys.summary,
      score: _run.score,
      bestCombo: _run.bestCombo,
      correctCount: _run.correctCount,
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
          TextButton(onPressed: widget.onExit, child: Text(strings.exit)),
        ],
      ),
    );
  }
}
