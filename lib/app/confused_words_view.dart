import 'dart:math';

import 'package:arcadelingo/domain/learning/confused_words.dart';
import 'package:arcadelingo/domain/learning/confusion_practice.dart';
import 'package:arcadelingo/domain/ports/answer_log.dart';
import 'package:arcadelingo/domain/review/review_contract.dart';
import 'package:arcadelingo/domain/review/study_course.dart';
import 'package:arcadelingo/ui/app_strings.dart';
import 'package:arcadelingo/ui/arcade_page.dart';
import 'package:arcadelingo/ui/arcade_panel.dart';
import 'package:flutter/material.dart';

Future<List<ConfusedWordPair>> loadConfusedWordPairs({
  required AnswerLog answers,
  required Iterable<Word> vocabulary,
  required CefrLevel level,
}) async => findConfusedWords(
  answers: await answers.all(),
  vocabulary: vocabulary,
  level: level,
);

Future<void> openConfusionPractice(
  BuildContext context,
  ConfusedWordPair pair, {
  required StudyCourse course,
  required String returnLabel,
}) async {
  final questions = buildConfusionPractice(
    first: pair.first,
    second: pair.second,
    course: course,
    random: Random(),
  );
  if (questions.isEmpty) return;
  await Navigator.of(context).push(
    MaterialPageRoute<void>(
      builder:
          (_) => _PairPracticeScreen(
            questions: questions,
            returnLabel: returnLabel,
          ),
    ),
  );
}

class ConfusedWordsScreen extends StatefulWidget {
  const ConfusedWordsScreen({
    required this.course,
    required this.level,
    required this.answers,
    required this.vocabulary,
    this.initialPairs,
    super.key,
  });

  final StudyCourse course;
  final CefrLevel level;
  final AnswerLog answers;
  final List<Word> vocabulary;
  final Future<List<ConfusedWordPair>>? initialPairs;

  @override
  State<ConfusedWordsScreen> createState() => _ConfusedWordsScreenState();
}

class _ConfusedWordsScreenState extends State<ConfusedWordsScreen> {
  late Future<List<ConfusedWordPair>> _pairs = widget.initialPairs ?? _load();

  Future<List<ConfusedWordPair>> _load() => loadConfusedWordPairs(
    answers: widget.answers,
    vocabulary: widget.vocabulary,
    level: widget.level,
  );

  @override
  Widget build(BuildContext context) {
    final strings = context.strings;
    final theme = Theme.of(context);
    return ArcadePage(
      title: strings.confusedWords,
      child: FutureBuilder<List<ConfusedWordPair>>(
        future: _pairs,
        builder: (context, snapshot) {
          if (snapshot.hasError) {
            return Center(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(strings.wordListLoadFailed),
                  TextButton(
                    onPressed: () => setState(() => _pairs = _load()),
                    child: Text(strings.retry),
                  ),
                ],
              ),
            );
          }
          final pairs = snapshot.data;
          if (pairs == null) {
            return Center(
              child: CircularProgressIndicator(
                semanticsLabel: strings.loadingWordList,
              ),
            );
          }
          return ListView.separated(
            padding: const EdgeInsets.all(20),
            itemCount: 1 + pairs.length,
            separatorBuilder: (_, _) => const SizedBox(height: 14),
            itemBuilder: (context, index) {
              if (index == 0) {
                return Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      '${strings.courseName(widget.course)} · ${widget.level.name.toUpperCase()}',
                      style: theme.textTheme.titleSmall?.copyWith(
                        color: theme.colorScheme.primary,
                      ),
                    ),
                    if (pairs.isEmpty) ...[
                      const SizedBox(height: 20),
                      Text(
                        strings.noConfusedPairs,
                        style: theme.textTheme.headlineSmall,
                      ),
                      const SizedBox(height: 8),
                      Text(
                        strings.confusionThreshold,
                        style: theme.textTheme.bodyLarge,
                      ),
                    ],
                  ],
                );
              }
              final pair = pairs[index - 1];
              return ArcadePanel(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    _WordMeaning(word: pair.first),
                    const Divider(height: 24),
                    _WordMeaning(word: pair.second),
                    const SizedBox(height: 16),
                    Text(
                      strings.confusionCount(pair.mistakes),
                      style: theme.textTheme.labelLarge,
                    ),
                    const SizedBox(height: 10),
                    FilledButton.tonalIcon(
                      onPressed:
                          () => openConfusionPractice(
                            context,
                            pair,
                            course: widget.course,
                            returnLabel: strings.backToPairs,
                          ),
                      icon: const Icon(Icons.swap_horiz_rounded),
                      label: Text(strings.practisePair),
                    ),
                  ],
                ),
              );
            },
          );
        },
      ),
    );
  }
}

class _WordMeaning extends StatelessWidget {
  const _WordMeaning({required this.word});
  final Word word;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(word.text, style: theme.textTheme.titleLarge),
        Text(
          word.translation,
          style: theme.textTheme.bodyLarge?.copyWith(
            color: theme.colorScheme.onSurfaceVariant,
          ),
        ),
      ],
    );
  }
}

class _PairPracticeScreen extends StatefulWidget {
  const _PairPracticeScreen({
    required this.questions,
    required this.returnLabel,
  });
  final List<ConfusionQuestion> questions;
  final String returnLabel;

  @override
  State<_PairPracticeScreen> createState() => _PairPracticeScreenState();
}

class _PairPracticeScreenState extends State<_PairPracticeScreen> {
  int _index = 0;
  int _firstTry = 0;
  Word? _wrongChoice;
  bool _correct = false;

  void _choose(ConfusionQuestion question, Word word) {
    if (_correct) return;
    setState(() {
      _correct = word.id == question.target.id;
      if (!_correct) {
        _wrongChoice = word;
      } else if (_wrongChoice == null) {
        _firstTry++;
      }
    });
  }

  void _advance() {
    if (!_correct) return;
    setState(() {
      _index++;
      _wrongChoice = null;
      _correct = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    final strings = context.strings;
    final theme = Theme.of(context);
    final total = widget.questions.length;
    final finished = _index == total;
    final question = finished ? null : widget.questions[_index];
    return ArcadePage(
      title: strings.practisePair,
      child: SingleChildScrollView(
        key: ValueKey(_index),
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            if (question == null) ...[
              ArcadePanel(
                accent: theme.colorScheme.primary,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Icon(
                      Icons.check_circle_outline_rounded,
                      color: theme.colorScheme.primary,
                      size: 32,
                    ),
                    const SizedBox(height: 12),
                    Text(
                      strings.pairComplete,
                      style: theme.textTheme.headlineSmall,
                    ),
                    const SizedBox(height: 8),
                    Text(
                      strings.confusionScore(_firstTry, total),
                      style: theme.textTheme.bodyLarge,
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 16),
              FilledButton(
                onPressed: () => Navigator.of(context).pop(),
                child: Text(widget.returnLabel),
              ),
            ] else ...[
              Text(
                strings.wordNumber(_index + 1, total),
                style: theme.textTheme.labelLarge?.copyWith(
                  color: theme.colorScheme.primary,
                ),
              ),
              const SizedBox(height: 8),
              LinearProgressIndicator(value: (_index + 1) / total),
              const SizedBox(height: 20),
              ArcadePanel(
                key: ValueKey('confusions.prompt.${question.target.id}'),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      question.kind == ConfusionPromptKind.sentence
                          ? strings.completeSentence
                          : strings.pickByMeaning,
                      style: theme.textTheme.labelLarge?.copyWith(
                        color: theme.colorScheme.primary,
                      ),
                    ),
                    const SizedBox(height: 12),
                    Text(
                      _correct
                          ? (question.completedSentence ?? question.prompt)
                          : question.prompt,
                      style: theme.textTheme.headlineSmall,
                    ),
                    if (question.cue case final cue?) ...[
                      const SizedBox(height: 8),
                      Text(cue, style: theme.textTheme.bodyLarge),
                    ],
                  ],
                ),
              ),
              const SizedBox(height: 16),
              for (final word in question.choices)
                Padding(
                  padding: const EdgeInsets.only(bottom: 8),
                  child: OutlinedButton(
                    onPressed:
                        _correct || _wrongChoice?.id == word.id
                            ? null
                            : () => _choose(question, word),
                    child: Text(word.text, textAlign: TextAlign.center),
                  ),
                ),
              if (_correct || _wrongChoice != null)
                Semantics(
                  liveRegion: true,
                  child: ArcadePanel(
                    accent:
                        _correct
                            ? theme.colorScheme.primary
                            : theme.colorScheme.tertiary,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          _correct ? strings.correct : strings.tryOtherWord,
                          style: theme.textTheme.titleMedium,
                        ),
                        const SizedBox(height: 4),
                        Text(
                          _correct
                              ? '${question.target.text} — ${question.target.translation}'
                              : '${_wrongChoice!.text} — ${_wrongChoice!.translation}',
                        ),
                      ],
                    ),
                  ),
                ),
              if (_correct) ...[
                const SizedBox(height: 14),
                FilledButton(
                  key: const ValueKey('confusions.next'),
                  onPressed: _advance,
                  child: Text(
                    _index + 1 == total ? strings.done : strings.next,
                  ),
                ),
              ],
            ],
          ],
        ),
      ),
    );
  }
}
