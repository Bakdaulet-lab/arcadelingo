import 'package:arcadelingo/domain/learning/personal_dictionary.dart';
import 'package:arcadelingo/domain/ports/answer_log.dart';
import 'package:arcadelingo/domain/ports/favorites_store.dart';
import 'package:arcadelingo/domain/ports/word_speech.dart';
import 'package:arcadelingo/domain/review/review_contract.dart';
import 'package:arcadelingo/ui/arcade_page.dart';
import 'package:arcadelingo/ui/arcade_panel.dart';
import 'package:arcadelingo/ui/theme.dart';
import 'package:arcadelingo/ui/word_panel.dart';
import 'package:arcadelingo/ui/word_pronunciation.dart';
import 'package:flutter/material.dart';

enum _WordFilter {
  recent('Недавно встретил', 'Пока нет встреченных слов'),
  difficult('Часто ошибаюсь', 'Пока нет слов с частыми ошибками'),
  favorites('Избранное', 'В избранном пока пусто');

  const _WordFilter(this.label, this.emptyMessage);
  final String label;
  final String emptyMessage;
}

class DictionaryScreen extends StatefulWidget {
  const DictionaryScreen({
    required this.items,
    required this.level,
    required this.answers,
    required this.favorites,
    required this.speech,
    required this.gameTitles,
    super.key,
  });

  final List<ReviewItem> items;
  final CefrLevel level;
  final AnswerLog answers;
  final FavoritesStore favorites;
  final WordSpeech speech;
  final Map<String, String> gameTitles;

  @override
  State<DictionaryScreen> createState() => _DictionaryScreenState();
}

class _DictionaryScreenState extends State<DictionaryScreen> {
  late Future<List<DictionaryEntry>> _entries = _load();
  Set<String> _favorites = {};
  _WordFilter _filter = _WordFilter.recent;
  bool _saving = false;

  Future<List<DictionaryEntry>> _load() async {
    _favorites = widget.favorites.load();
    return buildPersonalDictionary(
      items: widget.items,
      level: widget.level,
      answers: await widget.answers.all(),
    );
  }

  Future<bool> _setFavorite(String id, bool favorite) async {
    if (_saving) return false;
    _saving = true;
    final updated = _favorites.toSet();
    if (favorite) {
      updated.add(id);
    } else {
      updated.remove(id);
    }
    try {
      final saved = await widget.favorites.save(updated);
      if (saved && mounted) setState(() => _favorites = updated);
      return saved;
    } finally {
      _saving = false;
    }
  }

  Future<void> _openWord(DictionaryEntry entry) => Navigator.of(context).push(
    MaterialPageRoute<void>(
      builder:
          (context) => _DictionaryWordScreen(
            entry: entry,
            speech: widget.speech,
            gameTitles: widget.gameTitles,
            favorite: _favorites.contains(entry.word.id),
            setFavorite: (favorite) => _setFavorite(entry.word.id, favorite),
          ),
    ),
  );

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colors = theme.colorScheme;
    return ArcadePage(
      title: 'Личный словарь',
      child: FutureBuilder<List<DictionaryEntry>>(
        future: _entries,
        builder: (context, snapshot) {
          final entries = snapshot.data;
          final visible =
              entries
                  ?.where(
                    (entry) => switch (_filter) {
                      _WordFilter.recent => true,
                      _WordFilter.difficult => entry.isDifficult,
                      _WordFilter.favorites => _favorites.contains(
                        entry.word.id,
                      ),
                    },
                  )
                  .toList();
          return CustomScrollView(
            slivers: [
              SliverPadding(
                padding: const EdgeInsets.fromLTRB(20, 12, 20, 20),
                sliver: SliverToBoxAdapter(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Уровень ${widget.level.name.toUpperCase()}',
                        style: withWeight(
                          theme.textTheme.titleMedium!,
                          FontWeight.bold,
                        ).copyWith(color: colors.primary),
                      ),
                      const SizedBox(height: 12),
                      Wrap(
                        spacing: 8,
                        runSpacing: 4,
                        children: [
                          for (final filter in _WordFilter.values)
                            ChoiceChip(
                              label: Text(filter.label),
                              selected: _filter == filter,
                              onSelected:
                                  (_) => setState(() => _filter = filter),
                              materialTapTargetSize:
                                  MaterialTapTargetSize.padded,
                            ),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
              if (snapshot.hasError)
                SliverPadding(
                  padding: const EdgeInsets.symmetric(horizontal: 20),
                  sliver: SliverToBoxAdapter(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text('Словарь не загрузился'),
                        TextButton(
                          onPressed: () => setState(() => _entries = _load()),
                          child: const Text('Попробовать ещё раз'),
                        ),
                      ],
                    ),
                  ),
                )
              else if (visible == null)
                const SliverToBoxAdapter(
                  child: Center(
                    child: CircularProgressIndicator(
                      semanticsLabel: 'Загрузка словаря',
                    ),
                  ),
                )
              else if (visible.isEmpty)
                SliverPadding(
                  padding: const EdgeInsets.symmetric(horizontal: 20),
                  sliver: SliverToBoxAdapter(
                    child: ArcadePanel(
                      child: Text(
                        _filter.emptyMessage,
                        style: theme.textTheme.titleMedium,
                      ),
                    ),
                  ),
                )
              else
                SliverPadding(
                  padding: const EdgeInsets.fromLTRB(20, 0, 20, 24),
                  sliver: SliverList.separated(
                    itemCount: visible.length,
                    separatorBuilder:
                        (context, index) => const SizedBox(height: 10),
                    itemBuilder: (context, index) {
                      final entry = visible[index];
                      return Material(
                        color: colors.surfaceContainer,
                        borderRadius: BorderRadius.circular(16),
                        clipBehavior: Clip.antiAlias,
                        child: ListTile(
                          key: ValueKey(entry.word.id),
                          contentPadding: const EdgeInsets.symmetric(
                            horizontal: 16,
                            vertical: 8,
                          ),
                          title: Text(
                            entry.word.text,
                            style: withWeight(
                              theme.textTheme.titleMedium!,
                              FontWeight.bold,
                            ),
                          ),
                          subtitle: Text(entry.word.translation),
                          trailing: Icon(
                            _favorites.contains(entry.word.id)
                                ? Icons.bookmark_rounded
                                : Icons.chevron_right_rounded,
                            color: colors.primary,
                          ),
                          onTap: () => _openWord(entry),
                        ),
                      );
                    },
                  ),
                ),
            ],
          );
        },
      ),
    );
  }
}

class _DictionaryWordScreen extends StatefulWidget {
  const _DictionaryWordScreen({
    required this.entry,
    required this.speech,
    required this.gameTitles,
    required this.favorite,
    required this.setFavorite,
  });

  final DictionaryEntry entry;
  final WordSpeech speech;
  final Map<String, String> gameTitles;
  final bool favorite;
  final Future<bool> Function(bool value) setFavorite;

  @override
  State<_DictionaryWordScreen> createState() => _DictionaryWordScreenState();
}

class _DictionaryWordScreenState extends State<_DictionaryWordScreen> {
  late bool _favorite = widget.favorite;
  bool _saving = false;
  bool _saveError = false;

  Future<void> _toggleFavorite() async {
    if (_saving) return;
    final favorite = !_favorite;
    setState(() {
      _saving = true;
      _saveError = false;
    });
    var saved = false;
    try {
      saved = await widget.setFavorite(favorite);
    } catch (_) {
      // Отказ записи виден на карточке, а отметка остаётся прежней.
    }
    if (!mounted) return;
    setState(() {
      _saving = false;
      _saveError = !saved;
      if (saved) _favorite = favorite;
    });
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colors = theme.colorScheme;
    final entry = widget.entry;
    final word = entry.word;
    return ArcadePage(
      title: 'Карточка слова',
      child: CustomScrollView(
        slivers: [
          SliverPadding(
            padding: const EdgeInsets.fromLTRB(20, 12, 20, 12),
            sliver: SliverToBoxAdapter(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Text(
                    'Уровень ${word.level.name.toUpperCase()}',
                    style: theme.textTheme.labelLarge?.copyWith(
                      color: colors.primary,
                    ),
                  ),
                  const SizedBox(height: 12),
                  WordPanel(word: word),
                  const SizedBox(height: 12),
                  WordPronunciation(text: word.text, speech: widget.speech),
                  const SizedBox(height: 8),
                  FilledButton.tonalIcon(
                    onPressed: _saving ? null : _toggleFavorite,
                    icon: Icon(
                      _favorite
                          ? Icons.bookmark_rounded
                          : Icons.bookmark_add_outlined,
                    ),
                    label: Text(
                      _favorite ? 'Убрать из избранного' : 'В избранное',
                      textAlign: TextAlign.center,
                    ),
                    style: FilledButton.styleFrom(
                      minimumSize: const Size.fromHeight(48),
                    ),
                  ),
                  if (_saveError)
                    Semantics(
                      liveRegion: true,
                      child: Text(
                        'Не удалось сохранить избранное. Попробуй ещё раз.',
                        style: TextStyle(color: colors.error),
                      ),
                    ),
                  const SizedBox(height: 24),
                  Text(
                    'История ответов',
                    style: withWeight(
                      theme.textTheme.titleLarge!,
                      FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    'Попыток: ${entry.attempts.length} · Ошибок: ${entry.mistakes}',
                    style: theme.textTheme.bodyMedium?.copyWith(
                      color: colors.onSurfaceVariant,
                    ),
                  ),
                ],
              ),
            ),
          ),
          SliverPadding(
            padding: const EdgeInsets.fromLTRB(20, 0, 20, 24),
            sliver: SliverList.builder(
              itemCount: entry.attempts.length,
              itemBuilder: (context, index) {
                final attempt = entry.attempts[index];
                final day = attempt.localDay;
                final date =
                    '${day.day.toString().padLeft(2, '0')}.'
                    '${day.month.toString().padLeft(2, '0')}.${day.year}';
                final game = widget.gameTitles[attempt.gameId];
                final accent = attempt.correct ? colors.primary : colors.error;
                return Padding(
                  padding: const EdgeInsets.only(bottom: 8),
                  child: ArcadePanel(
                    child: Row(
                      children: [
                        Icon(
                          attempt.correct
                              ? Icons.check_circle_outline
                              : Icons.cancel_outlined,
                          color: accent,
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                attempt.correct ? 'Верно' : 'Ошибка',
                                style: theme.textTheme.titleSmall?.copyWith(
                                  color: accent,
                                ),
                              ),
                              Text([date, if (game != null) game].join(' · ')),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}
