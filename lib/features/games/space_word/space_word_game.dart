import 'dart:async';
import 'dart:math';

import 'package:arcadelingo/domain/ports/sounds.dart';
import 'package:arcadelingo/domain/review/review_contract.dart';
import 'package:arcadelingo/domain/review/study_course.dart';
import 'package:arcadelingo/domain/review/word_choices.dart';
import 'package:arcadelingo/ui/app_strings.dart';
import 'package:arcadelingo/ui/arcade_round_summary.dart';
import 'package:arcadelingo/ui/arcade_status_layout.dart';
import 'package:arcadelingo/ui/theme.dart';
import 'package:flutter/material.dart';

import 'space_field.dart';
import 'space_flight.dart';

abstract final class SpaceWordKeys {
  static const start = Key('space_word.start');
  static const pause = Key('space_word.pause');
  static const prompt = Key('space_word.prompt');
  static const field = Key('space_word.field');
  static const fire = Key('space_word.fire');
  static const shield = Key('space_word.shield');
  static const summary = Key('space_word.summary');
  static const feedback = Key('space_word.feedback');
  static const score = Key('space_word.score');
  static const exit = Key('space_word.exit');
}

enum _Phase { ready, play, paused, finished }

enum _Feedback { controls, correct, wrong, collision }

class SpaceWordGame extends StatefulWidget {
  const SpaceWordGame({
    required this.session,
    required this.vocabulary,
    required this.onExit,
    required this.onPlayAgain,
    this.course,
    this.level,
    this.summaryFooter,
    this.onRoundOver,
    this.onRoundScore,
    this.mistakeCount,
    this.onReviewMistakes,
    this.sounds = const NoopSounds(),
    this.seed,
    super.key,
  });
  static const maxWaves = 5;
  final ReviewSession session;
  final Iterable<Word> vocabulary;
  final StudyCourse? course;
  final CefrLevel? level;
  final String Function()? summaryFooter;
  final VoidCallback onExit;
  final VoidCallback onPlayAgain;
  final VoidCallback? onRoundOver;
  final Widget Function(int)? onRoundScore;
  final int Function()? mistakeCount;
  final VoidCallback? onReviewMistakes;
  final Sounds sounds;
  final int? seed;
  @override
  State<SpaceWordGame> createState() => _SpaceWordGameState();
}

class _SpaceWordGameState extends State<SpaceWordGame> {
  final _field = GlobalKey<SpaceFieldState>();
  final _flight = SpaceFlight();
  final _reactionTime = Stopwatch();
  late final _random = Random(widget.seed);
  _Phase _phase = _Phase.ready;
  _Feedback _feedback = _Feedback.controls;
  ReviewItem? _item;
  List<Word> _choices = [];
  List<String> _labels = [];
  Word? _lastChoice;
  bool _reported = false;
  bool _intercepted = false;
  Timer? _transition;
  int _wave = 0,
      _shields = 3,
      _score = 0,
      _correct = 0,
      _combo = 0,
      _bestCombo = 0;
  int? _firePointer;
  Widget? _record;
  String? _footer;
  int get _limit => min(SpaceWordGame.maxWaves, widget.session.total);

  @override
  void initState() {
    super.initState();
    if (!_prepare()) _phase = _Phase.finished;
  }

  bool _prepare() {
    if (_wave >= _limit || widget.session.isFinished) return false;
    final item = widget.session.nextItem();
    if (item == null) return false;
    _item = item;
    _reported = _intercepted = false;
    _lastChoice = null;
    _feedback = _Feedback.controls;
    _wave++;
    _choices = [
      item.word,
      ...wordDistractors(item, widget.vocabulary, _random).take(2),
    ]..shuffle(_random);
    _labels = [for (final word in _choices) word.text];
    _flight.startWave(
      options: _labels,
      correctIndex: _choices.indexOf(item.word),
      wave: _wave,
    );
    _reactionTime.reset();
    if (_phase == _Phase.play) _reactionTime.start();
    return true;
  }

  void _report({Word? chosen}) {
    if (_item == null || _reported) return;
    _reported = true;
    _reactionTime.stop();
    final right = chosen?.id == _item!.word.id;
    widget.session.report(
      ReviewOutcome.untimed(
        correct: right,
        responseTime: _reactionTime.elapsed,
        selectedAnswer: chosen?.text,
      ),
    );
    if (right) {
      _correct++;
      _combo++;
      _bestCombo = max(_bestCombo, _combo);
    } else {
      _combo = 0;
    }
  }

  void _start() {
    if (_phase != _Phase.ready && _phase != _Phase.paused) return;
    setState(() => _phase = _Phase.play);
    if (!_reported) _reactionTime.start();
    if (_intercepted) _scheduleNext();
  }

  void _pause() {
    if (_phase != _Phase.play) return;
    _reactionTime.stop();
    _transition?.cancel();
    _firePointer = null;
    _field.currentState?.clearInput();
    setState(() => _phase = _Phase.paused);
  }

  void _scheduleNext() {
    _transition?.cancel();
    _transition = Timer(const Duration(milliseconds: 480), () {
      if (!mounted || _phase != _Phase.play) return;
      setState(() {
        if (!_prepare()) _finish();
      });
    });
  }

  void _contact(FlightEvent event) {
    if (_phase != _Phase.play || _intercepted) return;
    setState(() {
      final index = event.index;
      if (index == null) {
        _shields--;
        _feedback = _Feedback.collision;
        widget.sounds.play(GameSound.miss);
        if (_shields == 0) {
          _report();
          _finish();
        }
        return;
      }
      final choice = _choices[index];
      _lastChoice = choice;
      _report(chosen: choice);
      if (choice.id == _item!.word.id) {
        _intercepted = true;
        _score += 100;
        _feedback = _Feedback.correct;
        widget.sounds.play(GameSound.slice);
        _scheduleNext();
      } else {
        _score = max(0, _score - 25);
        _feedback = _Feedback.wrong;
        widget.sounds.play(GameSound.miss);
      }
    });
  }

  void _finish() {
    _phase = _Phase.finished;
    _reactionTime.stop();
    _transition?.cancel();
    _field.currentState?.clearInput();
    _footer = widget.summaryFooter?.call();
    _record = widget.onRoundScore?.call(_score);
    widget.sounds.play(GameSound.roundEnd);
    widget.onRoundOver?.call();
  }

  void _leave() {
    _transition?.cancel();
    _reactionTime.stop();
    if (_phase != _Phase.finished) _report();
  }

  void _exit() {
    _leave();
    widget.onExit();
  }

  @override
  void dispose() {
    _leave();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final s = context.strings,
        theme = Theme.of(context),
        colors = theme.colorScheme;
    final course = widget.course;
    final level =
        (widget.level ?? _item?.word.level ?? CefrLevel.a1).name.toUpperCase();
    return PopScope<void>(
      onPopInvokedWithResult: (didPop, _) {
        if (didPop) _leave();
      },
      child: Scaffold(
        appBar: AppBar(
          leading: BackButton(key: SpaceWordKeys.exit, onPressed: _exit),
          titleSpacing: 0,
          title: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              FittedBox(
                fit: BoxFit.scaleDown,
                alignment: AlignmentDirectional.centerStart,
                child: Text.rich(
                  TextSpan(
                    children: [
                      const TextSpan(text: 'Space '),
                      TextSpan(
                        text: 'Word',
                        style: TextStyle(color: colors.primary),
                      ),
                    ],
                  ),
                  style: theme.textTheme.titleLarge?.copyWith(
                    fontWeight: FontWeight.w800,
                    fontStyle: FontStyle.italic,
                    letterSpacing: -1,
                  ),
                ),
              ),
              if (course != null &&
                  MediaQuery.textScalerOf(context).scale(12) < 18)
                Semantics(
                  label: '${s.courseName(course)} · $level',
                  excludeSemantics: true,
                  child: FittedBox(
                    fit: BoxFit.scaleDown,
                    alignment: AlignmentDirectional.centerStart,
                    child: DefaultTextStyle(
                      style: theme.textTheme.labelSmall!,
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Text(s.languageName(course.translationLanguage)),
                          const Padding(
                            padding: EdgeInsets.symmetric(horizontal: 4),
                            child: Icon(Icons.arrow_forward_rounded, size: 12),
                          ),
                          Text(
                            '${s.languageName(course.studyLanguage)} · $level',
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
            ],
          ),
          actions:
              _phase == _Phase.finished
                  ? null
                  : [
                    Padding(
                      padding: const EdgeInsetsDirectional.only(end: 4),
                      child: Semantics(
                        label: s.score(_score),
                        excludeSemantics: true,
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          crossAxisAlignment: CrossAxisAlignment.end,
                          children: [
                            if (MediaQuery.textScalerOf(context).scale(12) < 18)
                              Text(
                                s.spacePoints.toUpperCase(),
                                style: theme.textTheme.labelSmall,
                              ),
                            Text(
                              _score.toString().padLeft(4, '0'),
                              key: SpaceWordKeys.score,
                              style: theme.textTheme.titleMedium?.copyWith(
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                    IconButton(
                      key: SpaceWordKeys.pause,
                      tooltip: s.snakePause,
                      onPressed: _phase == _Phase.play ? _pause : null,
                      icon: const Icon(Icons.pause_rounded),
                    ),
                  ],
        ),
        body: SafeArea(
          top: false,
          child: _phase == _Phase.finished ? _summary(s) : _body(context),
        ),
      ),
    );
  }

  Widget _summary(AppStrings s) {
    if (_item == null) {
      return ArcadeStatusLayout(
        key: SpaceWordKeys.summary,
        icon: Icons.nightlight_round,
        title: s.nothingToday,
        body: Text(s.comeBackTomorrow, textAlign: TextAlign.center),
        actions: FilledButton(onPressed: _exit, child: Text(s.exit)),
      );
    }
    final mistakes = widget.mistakeCount?.call() ?? 0;
    return ArcadeRoundSummary(
      key: SpaceWordKeys.summary,
      score: _score,
      bestCombo: _bestCombo,
      correctCount: _correct,
      answeredCount: widget.session.answered,
      outOfLives: _shields == 0,
      footer: _footer,
      challengeRecord: _record,
      actions: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          if (mistakes > 0 && widget.onReviewMistakes != null)
            OutlinedButton(
              key: const Key('game.review_mistakes'),
              onPressed: widget.onReviewMistakes,
              child: Text(s.reviewMistakesCount(mistakes)),
            ),
          FilledButton(onPressed: widget.onPlayAgain, child: Text(s.playAgain)),
          TextButton(onPressed: _exit, child: Text(s.exit)),
        ],
      ),
    );
  }

  Widget _body(BuildContext context) {
    final s = context.strings,
        theme = Theme.of(context),
        colors = theme.colorScheme;
    final reduced =
        MediaQuery.disableAnimationsOf(context) ||
        MediaQuery.accessibleNavigationOf(context);
    final goal = _item!.word;
    final playing = _phase == _Phase.play;
    final paused = _phase == _Phase.paused;
    final text = switch (_feedback) {
      _Feedback.correct => '${goal.text} — ${goal.translation} · +100',
      _Feedback.wrong => s.spaceWrong(_lastChoice!, goal.translation),
      _Feedback.collision => s.spaceDamage(_shields),
      _Feedback.controls => switch (theme.platform) {
        TargetPlatform.iOS || TargetPlatform.android => s.spaceDrag,
        _ => s.spaceKeys,
      },
    };
    final accent = switch (_feedback) {
      _Feedback.correct => colors.primary,
      _Feedback.wrong || _Feedback.collision => colors.error,
      _Feedback.controls => colors.onSurfaceVariant,
    };
    final heading = Padding(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 9),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  s.spaceFind.toUpperCase(),
                  style: theme.textTheme.labelSmall,
                ),
                Text(
                  goal.translation,
                  key: SpaceWordKeys.prompt,
                  style: theme.textTheme.headlineSmall?.copyWith(
                    fontFamily: warmPaperFont,
                    height: 1.15,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 8),
          Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Text(
                s.spaceWave.toUpperCase(),
                style: theme.textTheme.labelSmall,
              ),
              Text(
                '${_wave.toString().padLeft(2, '0')} / ${_limit.toString().padLeft(2, '0')}',
                style: theme.textTheme.labelLarge,
              ),
            ],
          ),
        ],
      ),
    );
    final battlefield = Stack(
      alignment: Alignment.center,
      children: [
        KeyedSubtree(
          key: SpaceWordKeys.field,
          child: AspectRatio(
            aspectRatio: 360 / 420,
            child: SpaceField(
              key: _field,
              flight: _flight,
              labels: _labels,
              playing: playing,
              reducedMotion: reduced,
              onEvent: _contact,
              onPause: _pause,
              semanticsLabel:
                  '${s.spaceWordInstruction}. ${_labels.join(', ')}.',
            ),
          ),
        ),
        if (paused)
          Positioned.fill(
            child: ColoredBox(
              color: colors.scrim.withValues(alpha: .64),
              child: Center(
                child: DecoratedBox(
                  decoration: BoxDecoration(
                    color: colors.surface,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Padding(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 22,
                      vertical: 12,
                    ),
                    child: Text(
                      s.snakePause,
                      style: theme.textTheme.titleLarge,
                    ),
                  ),
                ),
              ),
            ),
          ),
      ],
    );
    final deck = Padding(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      child: Wrap(
        alignment: WrapAlignment.spaceBetween,
        crossAxisAlignment: WrapCrossAlignment.center,
        runSpacing: 4,
        spacing: 12,
        children: [
          Semantics(
            key: SpaceWordKeys.shield,
            label: '${s.spaceShield}: $_shields / 3',
            excludeSemantics: true,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  s.spaceShield.toUpperCase(),
                  style: theme.textTheme.labelSmall,
                ),
                Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    for (var i = 0; i < 3; i++)
                      Container(
                        width: 12,
                        height: 6,
                        margin: const EdgeInsetsDirectional.only(
                          end: 3,
                          top: 3,
                          bottom: 3,
                        ),
                        decoration: BoxDecoration(
                          color:
                              i < _shields
                                  ? colors.primary
                                  : colors.outlineVariant,
                          borderRadius: BorderRadius.circular(2),
                        ),
                      ),
                  ],
                ),
              ],
            ),
          ),
          if (playing)
            Listener(
              onPointerDown: (e) {
                if (_firePointer != null) return;
                _firePointer = e.pointer;
                _field.currentState?.fire(true);
              },
              onPointerUp: (e) {
                if (_firePointer != e.pointer) return;
                _firePointer = null;
                _field.currentState?.fire(false);
              },
              onPointerCancel: (e) {
                if (_firePointer != e.pointer) return;
                _firePointer = null;
                _field.currentState?.fire(false);
              },
              child: OutlinedButton.icon(
                key: SpaceWordKeys.fire,
                icon: const Icon(Icons.gps_fixed, size: 17),
                label: Text(s.spaceFire),
                onPressed: () {
                  if (_firePointer != null) return;
                  _field.currentState?.fire(true);
                  _field.currentState?.fire(false);
                },
              ),
            )
          else
            FilledButton.icon(
              key: SpaceWordKeys.start,
              onPressed: _start,
              icon: const Icon(Icons.play_arrow_rounded, size: 18),
              label: Text(paused ? s.snakeResume : s.spaceLaunch),
            ),
        ],
      ),
    );
    final hint = Padding(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      child: Semantics(
        liveRegion: _feedback != _Feedback.controls,
        child: Text(
          text,
          key: SpaceWordKeys.feedback,
          textAlign: TextAlign.center,
          style: theme.textTheme.bodySmall?.copyWith(color: accent),
        ),
      ),
    );
    return LayoutBuilder(
      builder: (context, bounds) {
        final landscape =
            bounds.maxWidth > 550 && bounds.maxWidth > bounds.maxHeight * 1.45;
        if (landscape) {
          return Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 850),
              child: Row(
                children: [
                  Expanded(flex: 3, child: Center(child: battlefield)),
                  Expanded(
                    flex: 2,
                    child: SingleChildScrollView(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [heading, deck, hint],
                      ),
                    ),
                  ),
                ],
              ),
            ),
          );
        }
        final width = min(
          min(bounds.maxWidth - 20, 470.0),
          max(220.0, (bounds.maxHeight - 155) * 360 / 420),
        );
        return Align(
          alignment: Alignment.topCenter,
          child: SingleChildScrollView(
            padding: const EdgeInsets.symmetric(vertical: 4),
            child: SizedBox(
              width: width,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Container(
                    clipBehavior: Clip.antiAlias,
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(15),
                      border: Border.all(color: colors.outlineVariant),
                      color: colors.surfaceContainer,
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [heading, battlefield, deck],
                    ),
                  ),
                  hint,
                ],
              ),
            ),
          ),
        );
      },
    );
  }
}
