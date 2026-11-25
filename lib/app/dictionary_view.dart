import 'dart:async';

import 'package:arcadelingo/domain/learning/personal_dictionary.dart';
import 'package:arcadelingo/domain/ports/answer_log.dart';
import 'package:arcadelingo/domain/ports/custom_words_store.dart';
import 'package:arcadelingo/domain/ports/favorites_store.dart';
import 'package:arcadelingo/domain/ports/word_speech.dart';
import 'package:arcadelingo/domain/review/review_contract.dart';
import 'package:arcadelingo/domain/review/study_course.dart';
import 'package:arcadelingo/domain/settings/app_settings.dart';
import 'package:arcadelingo/ui/app_strings.dart';
import 'package:arcadelingo/ui/arcade_page.dart';
import 'package:arcadelingo/ui/arcade_panel.dart';
import 'package:arcadelingo/ui/theme.dart';
import 'package:arcadelingo/ui/word_panel.dart';
import 'package:arcadelingo/ui/word_pronunciation.dart';
import 'package:flutter/material.dart';

import 'custom_word_form.dart';

enum _WordFilter {
  recent,
  difficult,
  favorites,
  personal;

  String label(AppStrings strings) => switch (this) {
    recent => strings.recentWords,
    difficult => strings.oftenMissed,
    favorites => strings.favorites,
    personal => strings.customWords,
  };

  String emptyMessage(AppStrings strings) => switch (this) {
    recent => strings.noRecentWords,
    difficult => strings.noDifficultWords,
    favorites => strings.noFavorites,
    personal => strings.noCustomWords,
  };
}

class DictionaryScreen extends StatefulWidget {
  const DictionaryScreen({
    required this.items,
    required this.level,
    required this.answers,
    required this.favorites,
    required this.speech,
    required this.gameTitles,
    this.course = StudyCourse.englishFromRussian,
    this.studyLanguage,
    this.customWords,
    this.onCustomWordsChanged,
    this.onPlayCustom,
    this.onConfusions,
    super.key,
  });

  final List<ReviewItem> items;
  final CefrLevel level;
  final AnswerLog answers;
  final FavoritesStore favorites;
  final WordSpeech speech;
  final String? studyLanguage;
  final StudyCourse course;
  final CustomWordsStore? customWords;
  final VoidCallback? onCustomWordsChanged;
  final FutureOr<void> Function()? onPlayCustom;
  final VoidCallback? onConfusions;
  final Map<String, String> gameTitles;

  @override
  State<DictionaryScreen> createState() => _DictionaryScreenState();
}

class _DictionaryScreenState extends State<DictionaryScreen> {
  late Future<List<DictionaryEntry>> _entries = _load();
  Set<String> _favorites = {};
  Set<String> _customIds = {};
  _WordFilter _filter = _WordFilter.recent;
  bool _saving = false;

  Future<List<DictionaryEntry>> _load() async {
    _favorites = widget.favorites.load();
    final personal = widget.customWords?.load(widget.level) ?? const <Word>[];
    _customIds = {for (final word in personal) word.id};
    return buildPersonalDictionary(
      items: widget.items,
      level: widget.level,
      customWords: personal,
      answers: await widget.answers.all(),
    );
  }

  Future<void> _addWord() async {
    final store = widget.customWords;
    if (store == null) return;
    final saved = await Navigator.of(context).push<bool>(
      MaterialPageRoute<bool>(
        builder:
            (_) => CustomWordForm(
              store: store,
              course: widget.course,
              level: widget.level,
            ),
      ),
    );
    if (!mounted || saved != true) return;
    widget.onCustomWordsChanged?.call();
    setState(() {
      _filter = _WordFilter.personal;
      _entries = _load();
    });
  }

  Future<void> _playCustom() async {
    await widget.onPlayCustom?.call();
    if (mounted) _refresh();
  }

  void _refresh() {
    setState(() {
      _entries = _load();
    });
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
            studyLanguage: widget.studyLanguage ?? widget.course.studyLanguage,
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
      title: context.strings.personalDictionary,
      child: FutureBuilder<List<DictionaryEntry>>(
        future: _entries,
        builder: (context, snapshot) {
          final entries = snapshot.data;
          final visible =
              entries
                  ?.where(
                    (entry) => switch (_filter) {
                      _WordFilter.recent => entry.attempts.isNotEmpty,
                      _WordFilter.difficult => entry.isDifficult,
                      _WordFilter.favorites => _favorites.contains(
                        entry.word.id,
                      ),
                      _WordFilter.personal => _customIds.contains(
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
                        widget.customWords == null
                            ? context.strings.level(
                              widget.level.name.toUpperCase(),
                            )
                            : '${context.strings.courseName(widget.course)} · ${widget.level.name.toUpperCase()}',
                        style: withWeight(
                          theme.textTheme.titleMedium!,
                          FontWeight.bold,
                        ).copyWith(color: colors.primary),
                      ),
                      if (widget.customWords != null) ...[
                        const SizedBox(height: 8),
                        FilledButton.tonalIcon(
                          key: const ValueKey('dictionary.add-word'),
                          onPressed: _addWord,
                          icon: const Icon(Icons.add_rounded),
                          label: Text(context.strings.addWord),
                        ),
                      ],
                      const SizedBox(height: 12),
                      Wrap(
                        spacing: 8,
                        runSpacing: 4,
                        children: [
                          for (final filter in _WordFilter.values.where(
                            (filter) =>
                                filter != _WordFilter.personal ||
                                widget.customWords != null,
                          ))
                            ChoiceChip(
                              label: Text(filter.label(context.strings)),
                              selected: _filter == filter,
                              onSelected:
                                  (_) => setState(() => _filter = filter),
                              materialTapTargetSize:
                                  MaterialTapTargetSize.padded,
                            ),
                        ],
                      ),
                      if (_filter == _WordFilter.personal &&
                          _customIds.isNotEmpty &&
                          widget.onPlayCustom != null) ...[
                        const SizedBox(height: 12),
                        FilledButton.icon(
                          key: const ValueKey('dictionary.play-custom'),
                          onPressed: _playCustom,
                          icon: const Icon(Icons.play_arrow_rounded),
                          label: Text(context.strings.playCustomWords),
                        ),
                      ],
                      if (widget.onConfusions != null) ...[
                        const SizedBox(height: 8),
                        TextButton.icon(
                          icon: const Icon(Icons.swap_horiz_rounded),
                          label: Text(context.strings.confusedWords),
                          onPressed: widget.onConfusions,
                        ),
                      ],
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
                        Text(context.strings.wordListLoadFailed),
                        TextButton(
                          onPressed: _refresh,
                          child: Text(context.strings.retry),
                        ),
                      ],
                    ),
                  ),
                )
              else if (visible == null)
                SliverToBoxAdapter(
                  child: Center(
                    child: CircularProgressIndicator(
                      semanticsLabel: context.strings.loadingWordList,
                    ),
                  ),
                )
              else if (visible.isEmpty)
                SliverPadding(
                  padding: const EdgeInsets.symmetric(horizontal: 20),
                  sliver: SliverToBoxAdapter(
                    child: ArcadePanel(
                      child: Text(
                        _filter.emptyMessage(context.strings),
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
    required this.studyLanguage,
    required this.setFavorite,
  });

  final DictionaryEntry entry;
  final WordSpeech speech;
  final String studyLanguage;
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
      title: context.strings.wordDetails,
      child: CustomScrollView(
        slivers: [
          SliverPadding(
            padding: const EdgeInsets.fromLTRB(20, 12, 20, 12),
            sliver: SliverToBoxAdapter(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Text(
                    context.strings.level(word.level.name.toUpperCase()),
                    style: theme.textTheme.labelLarge?.copyWith(
                      color: colors.primary,
                    ),
                  ),
                  const SizedBox(height: 12),
                  WordPanel(word: word),
                  const SizedBox(height: 12),
                  WordPronunciation(
                    text: word.text,
                    speech: widget.speech,
                    studyLanguage: widget.studyLanguage,
                  ),
                  const SizedBox(height: 8),
                  FilledButton.tonalIcon(
                    onPressed: _saving ? null : _toggleFavorite,
                    icon: Icon(
                      _favorite
                          ? Icons.bookmark_rounded
                          : Icons.bookmark_add_outlined,
                    ),
                    label: Text(
                      _favorite
                          ? context.strings.removeFavorite
                          : context.strings.addFavorite,
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
                        context.strings.favoriteSaveFailed,
                        style: TextStyle(color: colors.error),
                      ),
                    ),
                  const SizedBox(height: 24),
                  Text(
                    context.strings.answerHistory,
                    style: withWeight(
                      theme.textTheme.titleLarge!,
                      FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    context.strings.attemptCounts(
                      entry.attempts.length,
                      entry.mistakes,
                    ),
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
                    context.strings.language == InterfaceLanguage.spanish
                        ? MaterialLocalizations.of(context).formatCompactDate(
                          DateTime(day.year, day.month, day.day),
                        )
                        : '${day.day.toString().padLeft(2, '0')}.'
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
                                attempt.correct
                                    ? context.strings.correct
                                    : context.strings.mistake,
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
