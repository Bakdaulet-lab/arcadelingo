import 'dart:async';

import 'package:arcadelingo/domain/ports/word_speech.dart';
import 'package:arcadelingo/domain/review/review_contract.dart';
import 'package:arcadelingo/ui/arcade_page.dart';
import 'package:arcadelingo/ui/arcade_panel.dart';
import 'package:arcadelingo/ui/theme.dart';
import 'package:flutter/material.dart';

/// Общие ключи знакомства и разбора. Одновременно открыт один набор карточек.
abstract final class LearningKeys {
  static const introduction = Key('learning.introduction');
  static const mistakes = Key('learning.mistakes');
  static const word = Key('learning.word');
  static const translation = Key('learning.translation');
  static const speak = Key('learning.speak');
  static const speechMessage = Key('learning.speech_message');
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
    super.key,
  }) : words = _validatedWords(words, level, allowEmpty: true);

  final List<Word> words;
  final CefrLevel level;
  final WordSpeech speech;

  @override
  Widget build(BuildContext context) =>
      _LearningDeck(words: words, level: level, speech: speech);
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
  });

  final List<Word> words;
  final CefrLevel level;
  final WordSpeech speech;
  final VoidCallback? onStart;

  @override
  State<_LearningDeck> createState() => _LearningDeckState();
}

class _LearningDeckState extends State<_LearningDeck>
    with WidgetsBindingObserver {
  int _index = 0;
  int _speechRequest = 0;
  bool _speaking = false;
  bool _changingWord = false;
  bool _leaving = false;
  String? _speechMessage;
  final _scroll = ScrollController();

  bool get _review => widget.onStart == null;
  bool get _last => _index == widget.words.length - 1;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) return;
    _speechRequest++;
    unawaited(widget.speech.stop());
    if (_speaking) setState(() => _speaking = false);
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _speechRequest++;
    unawaited(widget.speech.stop());
    _scroll.dispose();
    super.dispose();
  }

  Future<void> _speak() async {
    if (_leaving || _changingWord) return;
    final request = ++_speechRequest;
    final text = widget.words[_index].text;
    setState(() {
      _speaking = true;
      _speechMessage = null;
    });
    await widget.speech.stop();
    if (!mounted || request != _speechRequest || _leaving) return;
    final result = await widget.speech.speak(text);
    if (!mounted || request != _speechRequest || _leaving) return;
    setState(() {
      _speaking = false;
      _speechMessage = switch (result) {
        SpeechResult.completed || SpeechResult.cancelled => null,
        SpeechResult.unavailable =>
          'Английский голос недоступен. Проверь настройки синтеза речи '
              'на устройстве и установи английский голос.',
        SpeechResult.failed => 'Не удалось произнести слово. Попробуй ещё раз.',
      };
    });
  }

  Future<void> _move(int next) async {
    if (_leaving || _changingWord) return;
    _speechRequest++;
    setState(() => _changingWord = true);
    await widget.speech.stop();
    if (!mounted || _leaving) return;
    setState(() {
      _index = next;
      _changingWord = false;
      _speaking = false;
      _speechMessage = null;
    });
    if (_scroll.hasClients) _scroll.jumpTo(0);
  }

  Future<void> _finish() async {
    if (_leaving) return;
    _speechRequest++;
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
    return PopScope<Object?>(
      onPopInvokedWithResult: (didPop, result) {
        if (!didPop) return;
        _speechRequest++;
        unawaited(widget.speech.stop());
      },
      child: ArcadePage(
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
                _WordPanel(word: words[_index]),
                const SizedBox(height: 16),
                Semantics(
                  label: 'Произнести ${words[_index].text}',
                  child: OutlinedButton(
                    key: LearningKeys.speak,
                    onPressed: enabled ? _speak : null,
                    child: ExcludeSemantics(
                      child: Padding(
                        padding: const EdgeInsets.symmetric(vertical: 10),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(
                              _speaking
                                  ? Icons.graphic_eq_rounded
                                  : Icons.volume_up_rounded,
                            ),
                            const SizedBox(width: 10),
                            Flexible(
                              child: Text(
                                _speaking ? 'Ещё раз' : 'Послушать',
                                textAlign: TextAlign.center,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                ),
                if (_speechMessage case final message?) ...[
                  const SizedBox(height: 12),
                  Semantics(
                    liveRegion: true,
                    child: Text(
                      message,
                      key: LearningKeys.speechMessage,
                      style: theme.textTheme.bodyMedium?.copyWith(
                        color: colors.onSurfaceVariant,
                        height: 1.4,
                      ),
                    ),
                  ),
                ],
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
      ),
    );
  }
}

class _WordPanel extends StatelessWidget {
  const _WordPanel({required this.word});

  final Word word;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colors = theme.colorScheme;
    final partOfSpeech = word.partOfSpeech;
    final example = word.example;
    return ArcadePanel(
      accent: colors.primary,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          if (partOfSpeech != null && partOfSpeech.isNotEmpty) ...[
            FittedBox(
              fit: BoxFit.scaleDown,
              alignment: Alignment.centerLeft,
              child: Text(
                _partOfSpeechLabel(partOfSpeech),
                softWrap: false,
                style: theme.textTheme.bodyMedium?.copyWith(
                  color: colors.onSurfaceVariant,
                ),
              ),
            ),
            const SizedBox(height: 10),
          ],
          FittedBox(
            fit: BoxFit.scaleDown,
            alignment: Alignment.centerLeft,
            child: Text(
              word.text,
              key: LearningKeys.word,
              softWrap: false,
              style: withWeight(theme.textTheme.displaySmall!, FontWeight.bold),
            ),
          ),
          const SizedBox(height: 16),
          Text(
            word.translation,
            key: LearningKeys.translation,
            style: withWeight(
              theme.textTheme.titleLarge!,
              FontWeight.w600,
            ).copyWith(color: colors.primary, fontSize: 20, height: 1.4),
          ),
          if (example != null && example.trim().isNotEmpty) ...[
            const SizedBox(height: 20),
            Divider(color: colors.outline.withValues(alpha: .45)),
            const SizedBox(height: 12),
            Text(
              example,
              style: theme.textTheme.bodyLarge?.copyWith(height: 1.5),
            ),
          ],
        ],
      ),
    );
  }
}

String _partOfSpeechLabel(String partOfSpeech) => switch (partOfSpeech) {
  'noun' => 'Существительное',
  'verb' => 'Глагол',
  'adjective' || 'adj' => 'Прилагательное',
  'adverb' || 'adv' => 'Наречие',
  'pronoun' => 'Местоимение',
  'preposition' => 'Предлог',
  'conjunction' => 'Союз',
  'interjection' => 'Междометие',
  'determiner' => 'Определитель',
  _ => partOfSpeech,
};
