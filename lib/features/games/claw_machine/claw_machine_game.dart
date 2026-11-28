import 'dart:async';
import 'dart:math';

import 'package:arcadelingo/domain/ports/sounds.dart';
import 'package:arcadelingo/domain/review/review_contract.dart';
import 'package:arcadelingo/ui/app_strings.dart';
import 'package:arcadelingo/ui/arcade_answer_feedback.dart';
import 'package:arcadelingo/ui/arcade_letter_wrap.dart';
import 'package:arcadelingo/ui/arcade_panel.dart';
import 'package:arcadelingo/ui/arcade_status_layout.dart';
import 'package:arcadelingo/ui/theme.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'claw_machine_field.dart';
import 'claw_machine_run.dart';

export 'claw_machine_field.dart' show ClawKeys;

class ClawMachineGame extends StatefulWidget {
  const ClawMachineGame({
    required this.session,
    required this.onExit,
    required this.onPlayAgain,
    this.onRoundOver,
    this.onChallengeComplete,
    this.summaryFooter,
    this.sounds = const NoopSounds(),
    this.mistakeCount,
    this.onReviewMistakes,
    this.studyLanguage = 'en',
    this.now,
    this.seed,
    super.key,
  });

  final ReviewSession session;
  final Sounds sounds;
  final VoidCallback onExit;
  final VoidCallback onPlayAgain;
  final VoidCallback? onRoundOver;
  final Widget Function(int score)? onChallengeComplete;
  final String Function()? summaryFooter;
  final int Function()? mistakeCount;
  final VoidCallback? onReviewMistakes;
  final String studyLanguage;
  final DateTime Function()? now;
  final int? seed;

  @override
  State<ClawMachineGame> createState() => _ClawMachineGameState();
}

class _ClawMachineGameState extends State<ClawMachineGame>
    with SingleTickerProviderStateMixin {
  late final ClawMachineRun _run;
  late final AnimationController _motion;
  late final AppLifecycleListener _lifecycle;
  int _column = ClawMachineRun.columnCount ~/ 2;
  int? _refillColumn;
  int _refillSerial = 0;
  int _boardNumber = 0;
  bool _capturing = false;
  bool _paused = false;
  bool _leaving = false;
  DateTime? _started;
  Duration _accumulated = Duration.zero;
  String? _footer;
  Widget? _challengeRecord;

  DateTime get _now => (widget.now ?? DateTime.now)();

  Duration get _elapsed {
    final start = _started;
    if (start == null) return _accumulated;
    final interval = _now.difference(start);
    return _accumulated + (interval.isNegative ? Duration.zero : interval);
  }

  bool get _reducedMotion => MediaQuery.disableAnimationsOf(context);

  bool get _canAim => !_leaving && !_paused && !_capturing && !_run.solved;

  @override
  void initState() {
    super.initState();
    _run = ClawMachineRun(
      widget.session,
      Random(widget.seed),
      hintLimit: widget.onChallengeComplete == null ? null : 1,
      studyLanguage: widget.studyLanguage,
    )..advance();
    _motion = AnimationController(
      vsync: this,
      animationBehavior: AnimationBehavior.preserve,
    )..addStatusListener(_grabFinished);
    _lifecycle = AppLifecycleListener(onStateChange: _onLifecycle);
    _paused = switch (WidgetsBinding.instance.lifecycleState) {
      null || AppLifecycleState.resumed => false,
      _ => true,
    };
    if (!_paused) _started = _now;
  }

  @override
  void dispose() {
    _abandon();
    _lifecycle.dispose();
    _motion.dispose();
    super.dispose();
  }

  void _abandon() {
    if (_leaving) return;
    _leaving = true;
    _capturing = false;
    _motion.stop();
    _run.abandon(_elapsed);
  }

  void _onLifecycle(AppLifecycleState state) {
    if (_leaving) return;
    final paused = state != AppLifecycleState.resumed;
    if (paused == _paused) return;
    if (paused) {
      _accumulated = _elapsed;
      _started = null;
      _motion.stop(canceled: false);
    } else {
      _started = _now;
    }
    setState(() => _paused = paused);
    if (!paused && _capturing) _motion.forward();
  }

  void _aim(int column) {
    if (!_canAim ||
        column == _column ||
        column < 0 ||
        column >= ClawMachineRun.columnCount) {
      return;
    }
    setState(() => _column = column);
    unawaited(HapticFeedback.selectionClick());
  }

  void _hint() {
    if (!_canAim) return;
    final column = _run.hint();
    if (column == null) return;
    setState(() => _column = column);
  }

  void _grab() {
    if (!_canAim) return;
    setState(() => _capturing = true);
    _motion.duration = Duration(milliseconds: _reducedMotion ? 80 : 570);
    _motion.forward(from: 0);
  }

  void _grabFinished(AnimationStatus status) {
    if (status != AnimationStatus.completed || !_capturing) return;
    final depth = _run.stacks[_column].length;
    setState(() {
      _capturing = false;
      _run.grab(_column, _elapsed);
      _refillColumn = _run.stacks[_column].length == depth ? _column : null;
      _refillSerial++;
    });
    if (_run.missedLetter != null) {
      widget.sounds.play(GameSound.clawMiss);
      return;
    }
    widget.sounds.play(_run.solved ? GameSound.clawWord : GameSound.clawCatch);
    unawaited(HapticFeedback.lightImpact());
  }

  void _next() {
    if (_leaving || !_run.solved || _run.item == null || _paused) return;
    setState(() {
      _run.advance();
      _refillColumn = null;
      _boardNumber++;
      _column = ClawMachineRun.columnCount ~/ 2;
      _accumulated = Duration.zero;
      _started = _now;
    });
    if (_run.item == null) {
      _footer = widget.summaryFooter?.call();
      _challengeRecord = widget.onChallengeComplete?.call(_run.correctCount);
      widget.sounds.play(GameSound.roundEnd);
      widget.onRoundOver?.call();
    }
  }

  @override
  Widget build(BuildContext context) => PopScope<void>(
    onPopInvokedWithResult: (didPop, _) {
      if (didPop) _abandon();
    },
    child: Scaffold(
      body: switch (_run.item?.word) {
        final Word word => _active(context, word),
        null => _end(context),
      },
    ),
  );

  Widget _active(BuildContext context, Word word) {
    final theme = Theme.of(context);
    final colors = theme.colorScheme;
    final missed = _run.missedLetter;
    final hints = _run.hintsRemaining;
    return SafeArea(
      child: Align(
        alignment: Alignment.topCenter,
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 482),
          child: SingleChildScrollView(
            padding: const EdgeInsets.fromLTRB(16, 6, 16, 20),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Row(
                  children: [
                    BackButton(onPressed: widget.onExit),
                    Expanded(
                      child: Text(
                        context.strings.clawMachine,
                        style: withWeight(
                          theme.textTheme.titleMedium!,
                          FontWeight.bold,
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    DecoratedBox(
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(8),
                        color: colors.primary,
                      ),
                      child: Padding(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 9,
                          vertical: 4,
                        ),
                        child: Text(
                          word.level.name.toUpperCase(),
                          style: withWeight(
                            theme.textTheme.labelLarge!,
                            FontWeight.bold,
                          ).copyWith(color: colors.onPrimary),
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                if (hints != null)
                  Text(
                    context.strings.wordNumber(
                      widget.session.answered + (_run.solved ? 0 : 1),
                      widget.session.total,
                    ),
                  ),
                Text(
                  word.translation,
                  key: ClawKeys.prompt,
                  textAlign: TextAlign.center,
                  style: withWeight(
                    theme.textTheme.headlineMedium!,
                    FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 14),
                _AnswerSlots(
                  key: ValueKey(_boardNumber),
                  slots: _run.slots,
                  separators: _run.separators,
                  collected: _run.collected,
                  reducedMotion: _reducedMotion,
                ),
                const SizedBox(height: 16),
                Stack(
                  alignment: Alignment.center,
                  children: [
                    CallbackShortcuts(
                      bindings: {
                        const SingleActivator(LogicalKeyboardKey.arrowLeft):
                            () => _aim(_column - 1),
                        const SingleActivator(LogicalKeyboardKey.arrowRight):
                            () => _aim(_column + 1),
                        const SingleActivator(
                              LogicalKeyboardKey.space,
                              includeRepeats: false,
                            ):
                            _grab,
                      },
                      child: Focus(
                        autofocus: true,
                        child: ClawMachineField(
                          stacks: _run.stacks,
                          column: _column,
                          hintedColumn: _run.hintedColumn,
                          motion: _motion,
                          capturing: _capturing,
                          reducedMotion: _reducedMotion,
                          refillColumn: _refillColumn,
                          refillSerial: _refillSerial,
                          onAim: _canAim ? _aim : null,
                        ),
                      ),
                    ),
                    if (_run.solved)
                      ArcadeAnswerFeedback(
                        correct: true,
                        child: Padding(
                          padding: const EdgeInsets.all(18),
                          child: ArcadePanel(
                            key: ClawKeys.result,
                            accent: colors.primary,
                            padding: const EdgeInsets.symmetric(
                              horizontal: 16,
                              vertical: 22,
                            ),
                            child: Column(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Icon(
                                  Icons.check_circle_outline_rounded,
                                  color: colors.primary,
                                  size: 32,
                                ),
                                const SizedBox(height: 12),
                                Text(
                                  _run.answer,
                                  textAlign: TextAlign.center,
                                  style: withWeight(
                                    theme.textTheme.titleLarge!,
                                    FontWeight.bold,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ),
                  ],
                ),
                const SizedBox(height: 12),
                if (_run.solved)
                  FilledButton(
                    key: ClawKeys.next,
                    onPressed: _paused ? null : _next,
                    child: Text(context.strings.next),
                  )
                else ...[
                  Row(
                    children: [
                      IconButton.filledTonal(
                        key: ClawKeys.left,
                        tooltip: context.strings.left,
                        onPressed:
                            _canAim && _column > 0
                                ? () => _aim(_column - 1)
                                : null,
                        icon: const Icon(Icons.arrow_back_rounded),
                      ),
                      const SizedBox(width: 6),
                      IconButton.filledTonal(
                        key: ClawKeys.right,
                        tooltip: context.strings.right,
                        onPressed:
                            _canAim && _column < ClawMachineRun.columnCount - 1
                                ? () => _aim(_column + 1)
                                : null,
                        icon: const Icon(Icons.arrow_forward_rounded),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: FilledButton(
                          key: ClawKeys.grab,
                          onPressed: _canAim ? _grab : null,
                          child: Text(
                            context.strings.grab,
                            textAlign: TextAlign.center,
                          ),
                        ),
                      ),
                    ],
                  ),
                  Center(
                    child: TextButton.icon(
                      key: ClawKeys.hint,
                      onPressed: _canAim && hints != 0 ? _hint : null,
                      icon: const Icon(Icons.lightbulb_outline_rounded),
                      label: Text(
                        hints == null
                            ? context.strings.hint
                            : context.strings.challengeHints(hints),
                      ),
                    ),
                  ),
                  if (missed != null)
                    Semantics(
                      liveRegion: true,
                      child: ArcadeAnswerFeedback(
                        key: ValueKey(_refillSerial),
                        correct: false,
                        child: Text(
                          context.strings.letterMiss(missed),
                          textAlign: TextAlign.center,
                          style: TextStyle(color: colors.error),
                        ),
                      ),
                    ),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _end(BuildContext context) {
    final answered = widget.session.answered;
    final mistakes = widget.mistakeCount?.call() ?? 0;
    return ArcadeStatusLayout(
      key: ClawKeys.summary,
      animateResultBadge: answered > 0,
      icon: answered == 0 ? Icons.nightlight_round : Icons.emoji_events_rounded,
      title:
          answered == 0
              ? context.strings.nothingToday
              : context.strings.roundComplete,
      body:
          answered == 0
              ? null
              : Column(
                children: [
                  Text(
                    context.strings.correctAnswers(_run.correctCount, answered),
                  ),
                  if (_challengeRecord case final record?) ...[
                    const SizedBox(height: 12),
                    record,
                  ],
                  if (_footer case final footer?) ...[
                    const SizedBox(height: 12),
                    Text(footer, textAlign: TextAlign.center),
                  ],
                ],
              ),
      actions: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          if (mistakes > 0 && widget.onReviewMistakes != null)
            OutlinedButton(
              key: const Key('game.review_mistakes'),
              onPressed: widget.onReviewMistakes,
              child: Text(context.strings.reviewMistakesCount(mistakes)),
            ),
          if (answered > 0)
            FilledButton(
              onPressed: widget.onPlayAgain,
              child: Text(context.strings.playAgain),
            ),
          TextButton(
            onPressed: widget.onExit,
            child: Text(context.strings.exit),
          ),
        ],
      ),
    );
  }
}

class _AnswerSlots extends StatelessWidget {
  const _AnswerSlots({
    required this.slots,
    required this.separators,
    required this.collected,
    required this.reducedMotion,
    super.key,
  });

  final List<String> slots;
  final Set<int> separators;
  final int collected;
  final bool reducedMotion;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colors = theme.colorScheme;
    final letterStyle = withWeight(
      theme.textTheme.titleLarge!,
      FontWeight.bold,
    );
    final painter = TextPainter(
      textDirection: Directionality.of(context),
      textScaler: MediaQuery.textScalerOf(context),
    );
    final slotWidths = <double>[];
    for (final slot in slots) {
      painter
        ..text = TextSpan(text: slot, style: letterStyle)
        ..layout();
      slotWidths.add(painter.width);
    }
    painter.dispose();
    return Semantics(
      label: context.strings.lettersCollected(
        collected - separators.where((i) => i < collected).length,
        slots.length - separators.length,
      ),
      liveRegion: true,
      child: ArcadeLetterWrap(
        key: ClawKeys.slots,
        spelling: slots,
        alignment: WrapAlignment.center,
        spacing: 5,
        runSpacing: 5,
        slot:
            (context, i) =>
                separators.contains(i)
                    ? Padding(
                      padding: const EdgeInsets.only(top: 5),
                      child: Text(slots[i], style: theme.textTheme.titleLarge),
                    )
                    : TweenAnimationBuilder<double>(
                      key: ValueKey((i, i < collected)),
                      tween: Tween(
                        begin: !reducedMotion && i == collected - 1 ? 0 : 1,
                        end: 1,
                      ),
                      duration:
                          reducedMotion
                              ? Duration.zero
                              : const Duration(milliseconds: 210),
                      builder: (context, t, child) {
                        final pulse = 1 - t;
                        return Transform.scale(
                          scale: 1 + .12 * sin(pi * t),
                          child: Container(
                            constraints: BoxConstraints(
                              minWidth: max(38, slotWidths[i] + 12),
                              minHeight: 40,
                            ),
                            padding: const EdgeInsets.symmetric(
                              horizontal: 6,
                              vertical: 3,
                            ),
                            decoration: BoxDecoration(
                              color:
                                  i < collected
                                      ? Color.lerp(
                                        colors.surfaceContainerHighest,
                                        colors.primary,
                                        .24 * pulse,
                                      )
                                      : colors.surface,
                              border: Border.all(
                                color:
                                    i == collected
                                        ? colors.primary
                                        : Color.lerp(
                                          colors.outline,
                                          colors.primary,
                                          pulse,
                                        )!,
                              ),
                              borderRadius: BorderRadius.circular(9),
                              boxShadow: [
                                if (pulse > 0)
                                  BoxShadow(
                                    color: colors.primary.withValues(
                                      alpha: .5 * pulse,
                                    ),
                                    blurRadius: 12 * pulse,
                                  ),
                              ],
                            ),
                            child: child,
                          ),
                        );
                      },
                      child: Text(
                        i < collected ? slots[i] : ' ',
                        textAlign: TextAlign.center,
                        style: letterStyle,
                      ),
                    ),
      ),
    );
  }
}
