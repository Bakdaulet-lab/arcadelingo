import 'package:arcadelingo/domain/ports/word_speech.dart';
import 'package:arcadelingo/domain/review/review_contract.dart';
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
    super.key,
  }) : words = _validatedWords(words, level, allowEmpty: false);

  final List<Word> words;
  final CefrLevel level;
  final WordSpeech speech;
  final VoidCallback onStart;

  @override
  Widget build(BuildContext context) => _LearningDeck(
    words: words,
    level: level,
    speech: speech,
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
    super.key,
  }) : words = _validatedWords(words, level, allowEmpty: true),
       outcomes = Map.unmodifiable(outcomes);

  final List<Word> words;
  final CefrLevel level;
  final WordSpeech speech;

  @override
  Widget build(BuildContext context) => _LearningDeck(
    words: words,
    level: level,
    speech: speech,
    outcomes: outcomes,
  );

  final Map<String, ReviewOutcome> outcomes;
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
    this.onStart,
    this.outcomes = const {},
  });

  final List<Word> words;
  final CefrLevel level;
  final WordSpeech speech;
  final VoidCallback? onStart;
  final Map<String, ReviewOutcome> outcomes;

  @override
  State<_LearningDeck> createState() => _LearningDeckState();
}

class _LearningDeckState extends State<_LearningDeck> {
  int _index = 0;
  bool _changingWord = false;
  bool _leaving = false;
  final _scroll = ScrollController();

  bool get _review => widget.onStart == null;
  bool get _last => _index == widget.words.length - 1;

  @override
  void dispose() {
    _scroll.dispose();
    super.dispose();
  }

  Future<void> _move(int next) async {
    if (_leaving || _changingWord) return;
    setState(() => _changingWord = true);
    await widget.speech.stop();
    if (!mounted || _leaving) return;
    setState(() {
      _index = next;
      _changingWord = false;
    });
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

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colors = theme.colorScheme;
    final words = widget.words;
    final enabled = !_leaving && !_changingWord;
    final word = words.isEmpty ? null : words[_index];
    final outcome = word == null ? null : widget.outcomes[word.id];
    return ArcadePage(
      title: _review ? 'Разбор ошибок' : 'Знакомство',
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
                      'Слово ${_index + 1} из ${words.length}',
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
                'В этом раунде нет ошибок',
                style: withWeight(
                  theme.textTheme.headlineSmall!,
                  FontWeight.bold,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                'Можно вернуться к итогам.',
                style: theme.textTheme.bodyLarge?.copyWith(
                  color: colors.onSurfaceVariant,
                  height: 1.5,
                ),
              ),
            ],
            if (words.isNotEmpty) ...[
              const SizedBox(height: 24),
              WordPanel(word: word!, labelCorrectTranslation: outcome != null),
              if (outcome?.selectedAnswer case final answer?) ...[
                const SizedBox(height: 12),
                ArcadePanel(
                  accent: colors.error,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('Твой ответ', style: theme.textTheme.labelLarge),
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
                  'Время вышло',
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
                enabled: enabled,
              ),
              const SizedBox(height: 16),
              Text(
                _review
                    ? 'Повтори слова без таймера.'
                    : 'Прочитай перевод и послушай слово перед игрой.',
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
                child: const Padding(
                  padding: EdgeInsets.symmetric(vertical: 10),
                  child: Text('Дальше', textAlign: TextAlign.center),
                ),
              ),
            if (!_review && _last)
              FilledButton(
                key: LearningKeys.start,
                onPressed: enabled ? _finish : null,
                child: const Padding(
                  padding: EdgeInsets.symmetric(vertical: 10),
                  child: Text('Начать игру', textAlign: TextAlign.center),
                ),
              ),
            if (_index > 0) ...[
              const SizedBox(height: 12),
              OutlinedButton(
                key: LearningKeys.previous,
                onPressed: enabled ? () => _move(_index - 1) : null,
                child: const Padding(
                  padding: EdgeInsets.symmetric(vertical: 10),
                  child: Text('Назад', textAlign: TextAlign.center),
                ),
              ),
            ],
            if (_review) ...[
              if (words.isNotEmpty) const SizedBox(height: 12),
              FilledButton.tonal(
                key: LearningKeys.done,
                onPressed: enabled ? _finish : null,
                child: const Padding(
                  padding: EdgeInsets.symmetric(vertical: 10),
                  child: Text('Готово', textAlign: TextAlign.center),
                ),
              ),
            ] else ...[
              const SizedBox(height: 8),
              TextButton(
                key: LearningKeys.skip,
                onPressed: enabled ? _finish : null,
                child: const Padding(
                  padding: EdgeInsets.symmetric(vertical: 10),
                  child: Text('Сразу в игру', textAlign: TextAlign.center),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}
