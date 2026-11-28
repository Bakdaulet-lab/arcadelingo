import 'dart:math';

import 'package:arcadelingo/domain/review/review_contract.dart';
import 'package:arcadelingo/domain/review/study_course.dart';
import 'package:arcadelingo/ui/app_strings.dart';
import 'package:arcadelingo/ui/arcade_answer_feedback.dart';
import 'package:arcadelingo/ui/arcade_letter_wrap.dart';
import 'package:arcadelingo/ui/arcade_page.dart';
import 'package:arcadelingo/ui/arcade_panel.dart';
import 'package:arcadelingo/ui/theme.dart';
import 'package:flutter/material.dart';

import 'recall_exercise.dart';

enum _Phase { prompt, spelling, choices, feedback }

class RecallScreen extends StatefulWidget {
  const RecallScreen({
    required this.session,
    required this.vocabulary,
    required this.course,
    required this.level,
    required this.seed,
    required this.onComplete,
    required this.onExit,
    super.key,
  });

  final ReviewSession session;
  final List<Word> vocabulary;
  final StudyCourse course;
  final CefrLevel level;
  final int seed;
  final VoidCallback onComplete;
  final VoidCallback onExit;

  @override
  State<RecallScreen> createState() => _RecallScreenState();
}

class _RecallScreenState extends State<RecallScreen> {
  late final _random = Random(widget.seed);
  final _timeReading = Stopwatch();
  RecallExercise? _exercise;
  ReviewOutcome? _outcome;
  _Phase _phase = _Phase.prompt;
  int _unaided = 0;
  int _assisted = 0;
  int _misses = 0;

  @override
  void initState() {
    super.initState();
    _next();
  }

  void _next() {
    final item = widget.session.nextItem();
    _exercise =
        item == null
            ? null
            : RecallExercise(
              item: item,
              vocabulary: widget.vocabulary,
              random: _random,
            );
    _phase = _Phase.prompt;
    _outcome = null;
    _timeReading.reset();
    if (item != null) _timeReading.start();
  }

  void _submit(String answer, {required bool correct}) {
    if (_phase != _Phase.choices && _phase != _Phase.spelling) return;
    final assisted = _phase == _Phase.choices;
    _timeReading.stop();
    final outcome = ReviewOutcome.untimed(
      correct: correct,
      responseTime: _timeReading.elapsed,
      selectedAnswer: answer,
      hintsUsed: assisted ? 1 : 0,
    );
    widget.session.report(outcome);
    setState(() {
      _outcome = outcome;
      _phase = _Phase.feedback;
      if (!correct) {
        _misses++;
      } else if (assisted) {
        _assisted++;
      } else {
        _unaided++;
      }
    });
    if (widget.session.isFinished) widget.onComplete();
  }

  void _showChoices() => setState(() => _phase = _Phase.choices);

  @override
  Widget build(BuildContext context) {
    final strings = context.strings;
    final theme = Theme.of(context);
    final colors = theme.colorScheme;
    final exercise = _exercise;
    final total = widget.session.total;
    final number =
        widget.session.answered + (_phase == _Phase.feedback ? 0 : 1);
    return ArcadePage(
      title: strings.activeRecall,
      child: SingleChildScrollView(
        key: ValueKey((_phase, widget.session.answered)),
        padding: const EdgeInsets.fromLTRB(20, 12, 20, 28),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              '${strings.courseName(widget.course)} · ${widget.level.name.toUpperCase()}',
              style: theme.textTheme.labelLarge?.copyWith(
                color: colors.primary,
              ),
            ),
            const SizedBox(height: 18),
            if (exercise == null) ...[
              _RecallResult(
                unaided: _unaided,
                assisted: _assisted,
                misses: _misses,
              ),
              const SizedBox(height: 16),
              FilledButton(
                key: const Key('recall.exit'),
                onPressed: widget.onExit,
                child: Text(strings.done),
              ),
            ] else ...[
              Text(
                strings.wordNumber(number, total),
                style: theme.textTheme.labelLarge,
              ),
              const SizedBox(height: 8),
              ExcludeSemantics(
                child: LinearProgressIndicator(
                  value: number / total,
                  borderRadius: BorderRadius.circular(4),
                ),
              ),
              const SizedBox(height: 20),
              if (_phase == _Phase.feedback)
                _RecallFeedback(word: exercise.item.word, outcome: _outcome!)
              else
                ArcadePanel(
                  accent: colors.primary,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        strings.recallPrompt(widget.course.studyLanguage),
                        style: theme.textTheme.titleSmall?.copyWith(
                          color: colors.onSurfaceVariant,
                        ),
                      ),
                      const SizedBox(height: 12),
                      Semantics(
                        header: true,
                        child: Text(
                          exercise.item.word.translation,
                          style: withWeight(
                            theme.textTheme.headlineMedium!,
                            FontWeight.bold,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              const SizedBox(height: 18),
              if (_phase == _Phase.prompt && exercise.tiles.isNotEmpty)
                FilledButton.icon(
                  key: const Key('recall.spell'),
                  onPressed: () => setState(() => _phase = _Phase.spelling),
                  icon: const Icon(Icons.spellcheck_rounded),
                  label: Text(strings.recallSpell),
                ),
              if (_phase == _Phase.spelling) ...[
                _LetterBoard(
                  exercise: exercise,
                  textDirection:
                      widget.course.studyLanguage == 'ar'
                          ? TextDirection.rtl
                          : null,
                  onChange: () => setState(() {}),
                ),
                const SizedBox(height: 18),
                FilledButton.icon(
                  key: const Key('recall.check'),
                  onPressed:
                      exercise.complete
                          ? () => _submit(
                            exercise.slots.join(),
                            correct: exercise.correct,
                          )
                          : null,
                  icon: const Icon(Icons.check_rounded),
                  label: Text(strings.recallCheck),
                ),
              ],
              if (_phase == _Phase.spelling || _phase == _Phase.prompt) ...[
                const SizedBox(height: 8),
                OutlinedButton.icon(
                  key: const Key('recall.options'),
                  onPressed: _showChoices,
                  icon: const Icon(Icons.list_alt_rounded),
                  label: Text(strings.recallOptions),
                ),
              ],
              if (_phase == _Phase.choices) ...[
                Text(
                  strings.recallChoicesPrompt,
                  style: theme.textTheme.titleMedium,
                ),
                for (final (i, answer) in exercise.choices.indexed)
                  Padding(
                    padding: const EdgeInsets.only(top: 8),
                    child: OutlinedButton(
                      key: ValueKey('recall.choice.$i'),
                      onPressed:
                          () => _submit(
                            answer,
                            correct: exercise.isCorrectChoice(answer),
                          ),
                      style: OutlinedButton.styleFrom(
                        alignment: Alignment.centerLeft,
                        minimumSize: const Size(0, 50),
                      ),
                      child: Text(answer),
                    ),
                  ),
              ],
              if (_phase == _Phase.feedback)
                FilledButton(
                  key: const Key('recall.next'),
                  onPressed: () {
                    if (_phase == _Phase.feedback) setState(_next);
                  },
                  child: Text(
                    widget.session.isFinished
                        ? strings.recallResults
                        : strings.next,
                  ),
                ),
            ],
          ],
        ),
      ),
    );
  }
}

class _LetterBoard extends StatelessWidget {
  const _LetterBoard({
    required this.exercise,
    required this.onChange,
    required this.textDirection,
  });

  final RecallExercise exercise;
  final VoidCallback onChange;
  final TextDirection? textDirection;

  @override
  Widget build(BuildContext context) {
    final strings = context.strings;
    final theme = Theme.of(context);
    final colors = theme.colorScheme;
    final slots = exercise.slots;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(strings.yourAnswer, style: theme.textTheme.labelLarge),
        const SizedBox(height: 8),
        ArcadePanel(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
          child: Semantics(
            liveRegion: true,
            label: strings.lettersCollected(
              exercise.selected.length,
              exercise.tiles.length,
            ),
            value: slots.whereType<String>().join(),
            excludeSemantics: true,
            child: ArcadeLetterWrap(
              spelling: exercise.item.word.text.characters.toList(),
              textDirection: textDirection,
              spacing: 4,
              runSpacing: 8,
              slot:
                  (context, index) => Container(
                    constraints: const BoxConstraints(minWidth: 22),
                    decoration: BoxDecoration(
                      border: Border(
                        bottom: BorderSide(
                          color: colors.outlineVariant,
                          width: 2,
                        ),
                      ),
                    ),
                    child: Text(
                      slots[index] ?? ' ',
                      textAlign: TextAlign.center,
                      style: theme.textTheme.headlineSmall?.copyWith(
                        color: colors.primary,
                      ),
                    ),
                  ),
            ),
          ),
        ),
        Align(
          alignment: Alignment.centerRight,
          child: IconButton(
            key: const Key('recall.undo'),
            tooltip: strings.recallUndo,
            onPressed:
                exercise.selected.isEmpty
                    ? null
                    : () {
                      exercise.undo();
                      onChange();
                    },
            icon: const Icon(Icons.backspace_outlined),
          ),
        ),
        Wrap(
          key: const Key('recall.tiles'),
          spacing: 6,
          runSpacing: 6,
          children: [
            for (final (i, tile) in exercise.tiles.indexed)
              OutlinedButton(
                key: ValueKey('recall.tile.$i'),
                style: OutlinedButton.styleFrom(
                  minimumSize: const Size(48, 48),
                  padding: const EdgeInsets.symmetric(horizontal: 8),
                  foregroundColor: colors.onSurface,
                  backgroundColor: colors.surfaceContainerHighest,
                  textStyle: theme.textTheme.titleLarge,
                ),
                onPressed:
                    exercise.selected.contains(i)
                        ? null
                        : () {
                          exercise.selectTile(i);
                          onChange();
                        },
                child: Text(tile),
              ),
          ],
        ),
      ],
    );
  }
}

class _RecallFeedback extends StatelessWidget {
  const _RecallFeedback({required this.word, required this.outcome});

  final Word word;
  final ReviewOutcome outcome;

  @override
  Widget build(BuildContext context) {
    final strings = context.strings;
    final theme = Theme.of(context);
    final colors = theme.colorScheme;
    final accent = outcome.correct ? colors.primary : colors.error;
    return Semantics(
      liveRegion: true,
      child: ArcadeAnswerFeedback(
        correct: outcome.correct,
        child: ArcadePanel(
          accent: accent,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Icon(
                outcome.correct
                    ? Icons.check_circle_outline_rounded
                    : Icons.replay_rounded,
                color: accent,
              ),
              const SizedBox(height: 8),
              Text(
                outcome.correct ? strings.correct : strings.recallRightWord,
                style: theme.textTheme.titleSmall?.copyWith(color: accent),
              ),
              const SizedBox(height: 12),
              Text(
                word.text,
                style: withWeight(
                  theme.textTheme.headlineMedium!,
                  FontWeight.bold,
                ),
              ),
              const SizedBox(height: 4),
              Text(word.translation, style: theme.textTheme.titleMedium),
              if (!outcome.correct) ...[
                const Divider(height: 24),
                Text(strings.yourAnswer, style: theme.textTheme.labelMedium),
                Text(outcome.selectedAnswer!, style: theme.textTheme.bodyLarge),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

class _RecallResult extends StatelessWidget {
  const _RecallResult({
    required this.unaided,
    required this.assisted,
    required this.misses,
  });

  final int unaided;
  final int assisted;
  final int misses;

  @override
  Widget build(BuildContext context) {
    final strings = context.strings;
    final theme = Theme.of(context);
    return ArcadePanel(
      key: const Key('recall.summary'),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            unaided + assisted + misses == 0
                ? strings.nothingToday
                : strings.roundComplete,
            style: withWeight(theme.textTheme.headlineSmall!, FontWeight.bold),
          ),
          for (final (label, count) in [
            (strings.recallIndependent, unaided),
            (strings.recallWithHelp, assisted),
            (strings.recallMistakes, misses),
          ]) ...[
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(child: Text(label)),
                const SizedBox(width: 8),
                Text('$count', style: theme.textTheme.titleLarge),
              ],
            ),
          ],
        ],
      ),
    );
  }
}
