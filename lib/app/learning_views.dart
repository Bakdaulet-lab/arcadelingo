import 'dart:async';

import 'package:arcadelingo/domain/learning/confused_words.dart';
import 'package:arcadelingo/domain/ports/word_speech.dart';
import 'package:arcadelingo/domain/review/review_contract.dart';
import 'package:arcadelingo/ui/app_strings.dart';
import 'package:arcadelingo/ui/arcade_page.dart';
import 'package:arcadelingo/ui/arcade_panel.dart';
import 'package:arcadelingo/ui/theme.dart';
import 'package:arcadelingo/ui/word_panel.dart';
import 'package:arcadelingo/ui/word_pronunciation.dart';
import 'package:flutter/material.dart';

/// Общие ключи знакомства и разбора. Одновременно открыт один набор карточек.
abstract final class LearningKeys {
  static const introduction = Key('learning.introduction');
  static const mistakes = Key('learning.mistakes');
  static const word = WordPanel.wordKey;
  static const translation = WordPanel.translationKey;
  static const speak = WordPronunciation.buttonKey;
  static const speechMessage = WordPronunciation.messageKey;
  static const next = Key('learning.next');
  static const previous = Key('learning.previous');
  static const start = Key('learning.start');
  static const skip = Key('learning.skip');
  static const done = Key('learning.done');
}

/// Новые слова выбранной партии. Просмотр ничего не записывает в прогресс.
class WordIntroductionScreen extends StatelessWidget {
  WordIntroductionScreen({
    required List<Word> words,
    required this.level,
    required this.speech,
    required this.onStart,
    this.studyLanguage = 'en',
    super.key,
  }) : words = _validatedWords(words, level, allowEmpty: false);

  final List<Word> words;
  final CefrLevel level;
  final WordSpeech speech;
  final String studyLanguage;
  final VoidCallback onStart;

  @override
  Widget build(BuildContext context) => _LearningDeck(
    words: words,
    level: level,
    speech: speech,
    studyLanguage: studyLanguage,
    onStart: onStart,
  );
}

/// Спокойный разбор именно ошибок законченной партии, без таймера и оценок.
class MistakesReviewScreen extends StatelessWidget {
  MistakesReviewScreen({
    required List<Word> words,
    required this.level,
    required this.speech,
    Map<String, ReviewOutcome> outcomes = const {},
    this.onConfusions,
    this.confusionPairs,
    this.onPractisePair,
    this.studyLanguage = 'en',
    super.key,
  }) : words = _validatedWords(words, level, allowEmpty: true),
       outcomes = Map.unmodifiable(outcomes);

  final List<Word> words;
  final CefrLevel level;
  final WordSpeech speech;
  final String studyLanguage;

  @override
  Widget build(BuildContext context) => _LearningDeck(
    words: words,
    level: level,
    speech: speech,
    studyLanguage: studyLanguage,
    outcomes: outcomes,
    onConfusions: onConfusions,
    confusionPairs: confusionPairs,
    onPractisePair: onPractisePair,
  );

  final Map<String, ReviewOutcome> outcomes;
  final Future<void> Function()? onConfusions;
  final Future<List<ConfusedWordPair>>? confusionPairs;
  final Future<void> Function(ConfusedWordPair)? onPractisePair;
}

List<Word> _validatedWords(
  List<Word> words,
  CefrLevel level, {
  required bool allowEmpty,
}) {
  if (!allowEmpty && words.isEmpty) {
    throw ArgumentError.value(words, 'words', 'нет слов для знакомства');
  }
  if (words.any((word) => word.level != level)) {
    throw ArgumentError.value(level, 'level', 'слова другого уровня');
  }
  return List<Word>.unmodifiable(words);
}

class _LearningDeck extends StatefulWidget {
  const _LearningDeck({
    required this.words,
    required this.level,
    required this.speech,
    required this.studyLanguage,
    this.onStart,
    this.outcomes = const {},
    this.onConfusions,
    this.confusionPairs,
    this.onPractisePair,
  });

  final List<Word> words;
  final CefrLevel level;
  final WordSpeech speech;
  final String studyLanguage;
  final VoidCallback? onStart;
  final Future<void> Function()? onConfusions;
  final Future<List<ConfusedWordPair>>? confusionPairs;
  final Future<void> Function(ConfusedWordPair)? onPractisePair;
  final Map<String, ReviewOutcome> outcomes;

  @override
  State<_LearningDeck> createState() => _LearningDeckState();
}

class _LearningDeckState extends State<_LearningDeck>
    with SingleTickerProviderStateMixin {
  int _index = 0;
  bool _changingWord = false;
  bool _leaving = false;
  final _scroll = ScrollController();
  late final AnimationController _cardEntry;
  double _entryOffset = 0;

  bool get _review => widget.onStart == null;
  bool get _last => _index == widget.words.length - 1;

  @override
  void initState() {
    super.initState();
    _cardEntry = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 180),
      value: 1,
    );
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (MediaQuery.disableAnimationsOf(context) && _cardEntry.isAnimating) {
      _cardEntry.value = 1;
    }
  }

  @override
  void dispose() {
    _cardEntry.dispose();
    _scroll.dispose();
    super.dispose();
  }

  Future<void> _move(int next) async {
    if (_leaving || _changingWord) return;
    setState(() => _changingWord = true);
    await widget.speech.stop();
    if (!mounted || _leaving) return;
    setState(() {
      _entryOffset = next > _index ? 14 : -14;
      _index = next;
      _changingWord = false;
    });
    if (!MediaQuery.disableAnimationsOf(context)) {
      unawaited(_cardEntry.forward(from: 0));
    }
    if (_scroll.hasClients) _scroll.jumpTo(0);
  }

  Future<void> _finish() async {
    if (_leaving) return;
    setState(() => _leaving = true);
    await widget.speech.stop();
    if (!mounted || ModalRoute.of(context)?.isCurrent != true) return;
    final start = widget.onStart;
    if (start == null) {
      Navigator.of(context).pop();
    } else {
      start();
    }
  }

  Future<void> _openFromReview(Future<void> Function() open) async {
    if (_leaving || _changingWord) return;
    setState(() => _leaving = true);
    try {
      await widget.speech.stop();
      if (mounted && ModalRoute.of(context)?.isCurrent == true) await open();
    } finally {
      if (mounted) setState(() => _leaving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colors = theme.colorScheme;
    final words = widget.words;
    final enabled = !_leaving && !_changingWord;
    final word = words.isEmpty ? null : words[_index];
    final outcome = word == null ? null : widget.outcomes[word.id];
    return ArcadePage(
      title:
          _review
              ? context.strings.reviewMistakes
              : context.strings.wordPreview,
      child: SingleChildScrollView(
        key: _review ? LearningKeys.mistakes : LearningKeys.introduction,
        controller: _scroll,
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Wrap(
              spacing: 12,
              runSpacing: 8,
              crossAxisAlignment: WrapCrossAlignment.center,
              alignment: WrapAlignment.spaceBetween,
              children: [
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 14,
                    vertical: 8,
                  ),
                  decoration: BoxDecoration(
                    color: colors.primary.withValues(alpha: .12),
                    borderRadius: BorderRadius.circular(14),
                  ),
                  child: Text(
                    widget.level.name.toUpperCase(),
                    style: withWeight(
                      theme.textTheme.titleMedium!,
                      FontWeight.bold,
                    ).copyWith(color: colors.primary),
                  ),
                ),
                if (words.isNotEmpty)
                  Semantics(
                    liveRegion: true,
                    child: Text(
                      context.strings.wordNumber(_index + 1, words.length),
                      style: theme.textTheme.bodyLarge?.copyWith(
                        color: colors.onSurfaceVariant,
                      ),
                    ),
                  ),
              ],
            ),
            if (words.isEmpty) ...[
              const SizedBox(height: 20),
              Text(
                context.strings.noMistakes,
                style: withWeight(
                  theme.textTheme.headlineSmall!,
                  FontWeight.bold,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                context.strings.backToResults,
                style: theme.textTheme.bodyLarge?.copyWith(
                  color: colors.onSurfaceVariant,
                  height: 1.5,
                ),
              ),
            ],
            if (words.isNotEmpty) ...[
              const SizedBox(height: 24),
              AnimatedBuilder(
                animation: _cardEntry,
                builder: (context, child) {
                  final remaining =
                      1 - Curves.easeOutCubic.transform(_cardEntry.value);
                  return Transform.translate(
                    offset: Offset(_entryOffset * remaining, 0),
                    child: child,
                  );
                },
                child: WordPanel(
                  word: word!,
                  labelCorrectTranslation: outcome != null,
                ),
              ),
              if (outcome?.selectedAnswer case final answer?) ...[
                const SizedBox(height: 12),
                ArcadePanel(
                  accent: colors.error,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        context.strings.yourAnswer,
                        style: theme.textTheme.labelLarge,
                      ),
                      const SizedBox(height: 6),
                      Text(
                        answer,
                        style: theme.textTheme.bodyLarge?.copyWith(
                          color: colors.error,
                        ),
                      ),
                    ],
                  ),
                ),
              ] else if (outcome?.timedOut == true) ...[
                const SizedBox(height: 12),
                Text(
                  context.strings.timeUp,
                  style: theme.textTheme.bodyLarge?.copyWith(
                    color: colors.error,
                  ),
                ),
              ],
              const SizedBox(height: 16),
              WordPronunciation(
                key: ValueKey(word.id),
                text: word.text,
                speech: widget.speech,
                studyLanguage: widget.studyLanguage,
                enabled: enabled,
              ),
              if (widget.confusionPairs != null &&
                  widget.onPractisePair != null)
                FutureBuilder<List<ConfusedWordPair>>(
                  future: widget.confusionPairs,
                  builder: (context, snapshot) {
                    final pair =
                        snapshot.data
                            ?.where(
                              (p) =>
                                  p.first.id == word.id ||
                                  p.second.id == word.id,
                            )
                            .firstOrNull;
                    if (pair == null) return const SizedBox.shrink();
                    final other =
                        pair.first.id == word.id ? pair.second : pair.first;
                    return Padding(
                      padding: const EdgeInsets.only(top: 12),
                      child: FilledButton.tonalIcon(
                        icon: const Icon(Icons.swap_horiz_rounded),
                        label: Text(
                          '${context.strings.practisePair}\n${word.text} · ${other.text}',
                          textAlign: TextAlign.center,
                        ),
                        onPressed:
                            enabled
                                ? () => _openFromReview(
                                  () => widget.onPractisePair!(pair),
                                )
                                : null,
                      ),
                    );
                  },
                ),
              const SizedBox(height: 16),
              Text(
                _review
                    ? context.strings.reviewWithoutTimer
                    : context.strings.readAndListen,
                style: theme.textTheme.bodyMedium?.copyWith(
                  color: colors.onSurfaceVariant,
                  height: 1.4,
                ),
              ),
            ],
            const SizedBox(height: 28),
            if (words.isNotEmpty && !_last)
              FilledButton(
                key: LearningKeys.next,
                onPressed: enabled ? () => _move(_index + 1) : null,
                child: Padding(
                  padding: const EdgeInsets.symmetric(vertical: 10),
                  child: Text(
                    context.strings.next,
                    textAlign: TextAlign.center,
                  ),
                ),
              ),
            if (!_review && _last)
              FilledButton(
                key: LearningKeys.start,
                onPressed: enabled ? _finish : null,
                child: Padding(
                  padding: const EdgeInsets.symmetric(vertical: 10),
                  child: Text(
                    context.strings.startGame,
                    textAlign: TextAlign.center,
                  ),
                ),
              ),
            if (_index > 0) ...[
              const SizedBox(height: 12),
              OutlinedButton(
                key: LearningKeys.previous,
                onPressed: enabled ? () => _move(_index - 1) : null,
                child: Padding(
                  padding: const EdgeInsets.symmetric(vertical: 10),
                  child: Text(
                    context.strings.back,
                    textAlign: TextAlign.center,
                  ),
                ),
              ),
            ],
            if (_review) ...[
              if (words.isNotEmpty) const SizedBox(height: 12),
              FilledButton.tonal(
                key: LearningKeys.done,
                onPressed: enabled ? _finish : null,
                child: Padding(
                  padding: const EdgeInsets.symmetric(vertical: 10),
                  child: Text(
                    context.strings.done,
                    textAlign: TextAlign.center,
                  ),
                ),
              ),
              if (widget.onConfusions != null && words.isNotEmpty)
                TextButton.icon(
                  icon: const Icon(Icons.swap_horiz_rounded),
                  label: Text(context.strings.confusedWords),
                  onPressed:
                      enabled
                          ? () => _openFromReview(widget.onConfusions!)
                          : null,
                ),
            ] else ...[
              const SizedBox(height: 8),
              TextButton(
                key: LearningKeys.skip,
                onPressed: enabled ? _finish : null,
                child: Padding(
                  padding: const EdgeInsets.symmetric(vertical: 10),
                  child: Text(
                    context.strings.skipPreview,
                    textAlign: TextAlign.center,
                  ),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}
