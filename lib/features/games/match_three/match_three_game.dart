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
import 'package:flutter/services.dart';

import 'match_three_field.dart';
import 'match_three_hud.dart';
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
  final _scroll = ScrollController();
  final _questionAnchor = GlobalKey();
  final _feedbackAnchor = GlobalKey();
  double _boardOffset = 0;
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
    _scroll.dispose();
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
    if (!_run.answerCorrect) _reveal(_feedbackAnchor, MatchThreePhase.feedback);
  }

  void _speak() {
    if (_run.item case final item?) {
      unawaited(widget.speech.speak(item.word.text));
    }
  }

  void _reveal(GlobalKey target, MatchThreePhase phase) {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final anchor = target.currentContext;
      if (!mounted ||
          _leaving ||
          _run.phase != phase ||
          !_scroll.hasClients ||
          anchor == null) {
        return;
      }
      // Reveal the choices together. With very large type, reveal the word
      // first and let the player scroll through the translations at will.
      final fits =
          (anchor.size?.height ?? 0) <= _scroll.position.viewportDimension;
      unawaited(
        Scrollable.ensureVisible(
          anchor,
          alignment: fits ? 1 : 0,
          alignmentPolicy:
              fits
                  ? ScrollPositionAlignmentPolicy.keepVisibleAtEnd
                  : ScrollPositionAlignmentPolicy.explicit,
          duration:
              MediaQuery.disableAnimationsOf(context)
                  ? Duration.zero
                  : const Duration(milliseconds: 200),
          curve: Curves.easeOutCubic,
        ),
      );
    });
  }

  void _animate() {
    final int duration = switch (_run.phase) {
      MatchThreePhase.swapping => 155,
      MatchThreePhase.reverting => 150,
      MatchThreePhase.clearing => _run.blastOrigin == null ? 195 : 315,
      MatchThreePhase.falling =>
        182 +
            27 *
                _run.travel.values.fold<int>(
                  0,
                  (rows, travel) => max(rows, travel.rows.abs()),
                ),
      MatchThreePhase.feedback =>
        _run.answerCorrect
            ? 740
            : 1600 +
                min(
                  3600,
                  (_run.item?.word.translation.characters.length ?? 0) * 38,
                ),
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
    final previous = _run.phase;
    _run.advance();
    if (previous == MatchThreePhase.feedback) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted || _leaving || !_scroll.hasClients) return;
        final offset = min(_boardOffset, _scroll.position.maxScrollExtent);
        if (MediaQuery.disableAnimationsOf(context)) {
          _scroll.jumpTo(offset);
        } else {
          unawaited(
            _scroll.animateTo(
              offset,
              duration: const Duration(milliseconds: 200),
              curve: Curves.easeOutCubic,
            ),
          );
        }
      });
    }
    if (_run.phase == MatchThreePhase.clearing &&
        _run.blastOrigin == null &&
        previous != MatchThreePhase.feedback) {
      widget.sounds.play(
        _run.cascadeDepth > 1 ? GameSound.sliceHot : GameSound.clawCatch,
      );
    }
    if (_run.isAnimating) {
      _animate();
      return;
    }
    if (_run.phase == MatchThreePhase.question) {
      _boardOffset = _scroll.hasClients ? _scroll.offset : 0;
      _reading
        ..reset()
        ..start();
      unawaited(HapticFeedback.lightImpact());
      _speak();
      _reveal(_questionAnchor, MatchThreePhase.question);
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
        actions: [
          if (_run.phase != MatchThreePhase.finished)
            IconButton(
              tooltip: context.strings.matchHowTo,
              onPressed: _run.phase == MatchThreePhase.ready ? _rules : null,
              icon: const Icon(Icons.help_outline_rounded),
            ),
        ],
      ),
      body:
          _run.phase == MatchThreePhase.finished
              ? _summary(context)
              : _board(context),
    ),
  );

  Future<void> _rules() => showDialog<void>(
    context: context,
    builder: (context) {
      final strings = context.strings;
      return AlertDialog(
        title: Text(strings.matchHowTo),
        scrollable: true,
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          spacing: 12,
          children: [
            for (final (icon, line) in [
              (Icons.swap_horiz_rounded, strings.matchSwapRule),
              (
                Icons.diamond_outlined,
                '${strings.matchHint} ${strings.matchBonus}.',
              ),
              (Icons.add_rounded, strings.matchCrossRule),
            ])
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Icon(icon, color: Theme.of(context).colorScheme.tertiary),
                  const SizedBox(width: 10),
                  Expanded(child: Text(line)),
                ],
              ),
          ],
        ),
        actions: [
          FilledButton(
            onPressed: () => Navigator.pop(context),
            child: Text(strings.play),
          ),
        ],
      );
    },
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
            controller: _scroll,
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
                MatchThreeHud(run: _run),
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
                  KeyedSubtree(
                    key: _questionAnchor,
                    child: _wordPanel(context, item.word),
                  )
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
    final blast = _run.blastOrigin != null;
    final cascade =
        _run.cascadeDepth > 1 &&
        (_run.phase == MatchThreePhase.clearing ||
            _run.phase == MatchThreePhase.falling);
    final text =
        blast
            ? (_run.chargeKind == MatchChargeKind.cross
                ? strings.matchCrossBurst
                : strings.matchRowBurst)
            : _run.invalidMove
            ? strings.matchInvalidMove
            : cascade
            ? strings.matchCascade(_run.cascadeMultiplier)
            : _run.showGuide
            ? strings.matchGuide
            : _run.chargeProgress == MatchThreeRun.chargeGoal - 1
            ? strings.matchLastCharge
            : strings.matchHint;
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 6),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(
            cascade || blast
                ? Icons.auto_awesome_rounded
                : _run.invalidMove
                ? Icons.undo_rounded
                : _run.showGuide
                ? Icons.south_rounded
                : Icons.diamond_outlined,
            color: cascade || blast ? colors.tertiary : colors.onSurfaceVariant,
            size: 20,
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Semantics(
              liveRegion: _run.invalidMove,
              child: Text(
                text,
                style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                  color:
                      cascade || blast
                          ? colors.tertiary
                          : colors.onSurfaceVariant,
                ),
              ),
            ),
          ),
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
              DecoratedBox(
                decoration: BoxDecoration(
                  color: colors.tertiary.withValues(alpha: .12),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Padding(
                  padding: const EdgeInsets.all(8),
                  child: Icon(
                    _run.chargeKind == MatchChargeKind.cross
                        ? Icons.add_rounded
                        : Icons.swap_horiz_rounded,
                    color: colors.tertiary,
                  ),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      _run.chargeKind == MatchChargeKind.cross
                          ? strings.matchCrossBonus
                          : strings.matchBonus,
                      style: theme.textTheme.labelMedium?.copyWith(
                        color: colors.tertiary,
                      ),
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
              const gap = 5.0;
              const horizontalPadding = 9.0;
              final labelStyle = theme.textTheme.labelLarge!;
              final available =
                  (constraints.maxWidth - gap * (options.length - 1)) /
                      options.length -
                  2 * horizontalPadding;
              final label = TextPainter(
                textDirection: Directionality.of(context),
                textScaler: MediaQuery.textScalerOf(context),
                locale: Localizations.maybeLocaleOf(context),
              );
              final row =
                  constraints.maxWidth >= 220 &&
                  options.every((text) {
                    label.text = TextSpan(text: text, style: labelStyle);
                    label.layout();
                    return label.width <= available;
                  });
              label.dispose();
              final buttons = [
                for (final choice in options)
                  OutlinedButton(
                    style: OutlinedButton.styleFrom(
                      minimumSize: const Size(0, 48),
                      textStyle: labelStyle,
                      foregroundColor: colors.onSurface,
                      backgroundColor:
                          feedback && choice == word.translation
                              ? colors.primaryContainer
                              : feedback && choice == _run.selectedAnswer
                              ? colors.errorContainer
                              : colors.surface,
                      disabledForegroundColor:
                          choice == word.translation
                              ? colors.onPrimaryContainer
                              : choice == _run.selectedAnswer
                              ? colors.onErrorContainer
                              : colors.onSurfaceVariant,
                      padding: const EdgeInsets.symmetric(
                        horizontal: horizontalPadding,
                        vertical: 7,
                      ),
                      side:
                          feedback &&
                                  (choice == word.translation ||
                                      choice == _run.selectedAnswer)
                              ? BorderSide(
                                color:
                                    choice == word.translation
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
                    spacing: gap,
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
            ArcadeAnswerFeedback(
              key: _feedbackAnchor,
              correct: _run.answerCorrect,
              child: Semantics(
                liveRegion: true,
                child: Row(
                  children: [
                    Icon(
                      _run.answerCorrect
                          ? Icons.check_circle_outline_rounded
                          : Icons.info_outline_rounded,
                      size: 18,
                      color: _run.answerCorrect ? colors.primary : colors.error,
                    ),
                    const SizedBox(width: 7),
                    Expanded(
                      child: Text(
                        _run.answerCorrect
                            ? strings.correct
                            : '${strings.correctTranslation} — ${word.translation}',
                        style: TextStyle(
                          color:
                              _run.answerCorrect
                                  ? colors.primary
                                  : colors.error,
                        ),
                      ),
                    ),
                  ],
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
