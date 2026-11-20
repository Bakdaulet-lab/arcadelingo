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
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'word_mahjong_board.dart';
import 'word_mahjong_field.dart';

export 'word_mahjong_field.dart' show WordMahjongKeys;

class WordMahjongGame extends StatefulWidget {
  const WordMahjongGame({
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

  final BoardReviewSession session;
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
  State<WordMahjongGame> createState() => _WordMahjongGameState();
}

class _WordMahjongGameState extends State<WordMahjongGame> {
  late final _random = Random(widget.seed);
  final _reading = Stopwatch();
  final _scroll = ScrollController();
  final _firstMistakes = <ReviewItem, String>{};
  final _hints = <ReviewItem>{};

  WordMahjongBoard? _board;
  MahjongTile? _selected;
  MahjongTile? _mismatch;
  Word? _matched;
  int _pickCount = 0;
  MahjongPair? _highlight;
  Timer? _advance;
  var _score = 0;
  var _correct = 0;
  var _combo = 0;
  var _bestCombo = 0;
  String? _footer;
  Widget? _record;

  @override
  void initState() {
    super.initState();
    _deal();
  }

  void _deal() {
    final items = widget.session.remainingItems;
    _board = items.isEmpty ? null : WordMahjongBoard.deal(items, _random);
    _selected = null;
    _mismatch = null;
    _matched = null;
    _highlight = null;
    _reading.reset();
    if (_board != null) _reading.start();
    if (_scroll.hasClients) _scroll.jumpTo(0);
  }

  @override
  void dispose() {
    _advance?.cancel();
    _reading.stop();
    _scroll.dispose();
    unawaited(widget.speech.stop());
    super.dispose();
  }

  void _pick(MahjongTile tile) {
    final board = _board;
    if (board == null || !board.isFree(tile)) return;
    final selected = _selected;
    if (!tile.isTranslation && selected != tile) {
      unawaited(widget.speech.speak(tile.label));
    }
    setState(() {
      _pickCount++;
      _mismatch = null;
      _matched = null;
      if (tile != _highlight?.word && tile != _highlight?.translation) {
        _highlight = null;
      }
      if (tile == selected) {
        _selected = null;
      } else if (selected == null ||
          selected.isTranslation == tile.isTranslation) {
        _selected = tile;
      } else if (board.match(selected, tile)) {
        _selected = null;
        _highlight = null;
        _report(tile.item);
        _matched = tile.item.word;
        widget.sounds.play(GameSound.clawCatch);
        unawaited(HapticFeedback.selectionClick());
      } else {
        final word = tile.isTranslation ? selected : tile;
        final translation = tile.isTranslation ? tile : selected;
        _firstMistakes.putIfAbsent(word.item, () => translation.label);
        _selected = word;
        _mismatch = translation;
        widget.sounds.play(GameSound.miss);
      }
    });
    if (!board.isCleared) return;
    if (widget.session.isFinished) {
      _footer = widget.summaryFooter?.call();
      _record = widget.onRoundScore?.call(_score);
      widget.sounds.play(GameSound.roundEnd);
      widget.onRoundOver?.call();
    }
    if (MediaQuery.disableAnimationsOf(context)) {
      setState(_deal);
    } else {
      _advance = Timer(
        const Duration(milliseconds: 210),
        () => setState(_deal),
      );
    }
  }

  void _report(ReviewItem item) {
    final wrong = _firstMistakes.remove(item);
    final hinted = _hints.remove(item);
    final correct = wrong == null;
    _score += correct ? (hinted ? 75 : 100) : 50;
    if (correct) {
      _correct++;
      _combo++;
      _bestCombo = max(_bestCombo, _combo);
    } else {
      _combo = 0;
    }
    widget.session.reportPair(
      item,
      ReviewOutcome.untimed(
        correct: correct,
        responseTime: _reading.elapsed,
        hintsUsed: hinted ? 1 : 0,
        selectedAnswer: wrong ?? item.word.translation,
      ),
    );
  }

  void _showHint() {
    final hint = _board?.hint;
    if (hint == null) return;
    setState(() {
      _hints.add(hint.word.item);
      _matched = null;
      _selected = null;
      _mismatch = null;
      _highlight = hint;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        leading: BackButton(onPressed: widget.onExit),
        title: Text(context.strings.wordMahjong),
      ),
      body: switch (_board) {
        final board? => _playfield(context, board),
        null => _summary(context),
      },
    );
  }

  Widget _playfield(BuildContext context, WordMahjongBoard board) {
    final strings = context.strings;
    final style = Theme.of(context).textTheme;
    final colors = Theme.of(context).colorScheme;
    final course = widget.course;
    final answered = widget.session.answered;
    final total = widget.session.total;
    return SafeArea(
      child: Align(
        alignment: Alignment.topCenter,
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 450),
          child: ListView(
            controller: _scroll,
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 18),
            children: [
              if (course != null) ...[
                Text(
                  [
                    strings.courseName(course),
                    if (widget.level case final level?)
                      level.name.toUpperCase(),
                  ].join('  ·  '),
                  style: style.labelLarge?.copyWith(
                    color: colors.onSurfaceVariant,
                  ),
                ),
                const SizedBox(height: 12),
              ],
              Wrap(
                alignment: WrapAlignment.spaceBetween,
                spacing: 12,
                runSpacing: 4,
                children: [
                  Text(
                    strings.mahjongPairs(answered, total),
                    style: style.titleMedium,
                  ),
                  Text(strings.score(_score), style: style.titleMedium),
                ],
              ),
              const SizedBox(height: 8),
              LinearProgressIndicator(
                value: answered / total,
                minHeight: 5,
                borderRadius: BorderRadius.circular(4),
                semanticsLabel: strings.mahjongPairs(answered, total),
              ),
              const SizedBox(height: 14),
              WordMahjongField(
                key: WordMahjongKeys.field,
                board: board,
                enabled: !board.isCleared,
                wordLanguage: course?.studyLanguage,
                translationLanguage: course?.translationLanguage,
                selected: _selected,
                mismatch: _mismatch,
                highlight: _highlight,
                onTap: _pick,
              ),
              const SizedBox(height: 14),
              ArcadePanel(
                padding: const EdgeInsets.all(12),
                accent: _mismatch != null ? colors.error : null,
                child: Semantics(liveRegion: true, child: _status(context)),
              ),
              const SizedBox(height: 12),
              Align(
                alignment: Alignment.center,
                child: OutlinedButton.icon(
                  key: WordMahjongKeys.hint,
                  onPressed: board.isCleared ? null : _showHint,
                  icon: const Icon(Icons.lightbulb_outline_rounded),
                  label: Text(strings.hint),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _status(BuildContext context) {
    final strings = context.strings;
    final style = Theme.of(context).textTheme.bodyMedium;
    final matched = _matched;
    if (_mismatch == null && matched == null) {
      return Text(
        _highlight != null ? strings.mahjongHintShown : strings.mahjongRules,
        style: style,
      );
    }
    final colors = Theme.of(context).colorScheme;
    return ArcadeAnswerFeedback(
      key: ValueKey(_pickCount),
      correct: matched != null,
      child: Row(
        children: [
          Icon(
            matched != null
                ? Icons.check_circle_outline_rounded
                : Icons.info_outline_rounded,
            size: 18,
            color: matched != null ? colors.primary : colors.error,
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              matched != null
                  ? '${matched.text} — ${matched.translation}'
                  : strings.mahjongMismatch,
              style: style,
            ),
          ),
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
      key: WordMahjongKeys.summary,
      score: _score,
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
          TextButton(onPressed: widget.onExit, child: Text(strings.exit)),
        ],
      ),
    );
  }
}
