import 'package:arcadelingo/app/daily_word_board.dart';
import 'package:arcadelingo/domain/daily_word/daily_word.dart';
import 'package:arcadelingo/domain/ports/daily_word_store.dart';
import 'package:arcadelingo/ui/app_strings.dart';
import 'package:arcadelingo/ui/arcade_page.dart';
import 'package:arcadelingo/ui/arcade_panel.dart';
import 'package:flutter/material.dart';

class DailyWordScreen extends StatefulWidget {
  const DailyWordScreen({
    required this.puzzle,
    required this.store,
    required this.onShare,
    super.key,
  });

  final DailyWordPuzzle puzzle;
  final DailyWordStore store;
  final Future<void> Function(String text) onShare;

  @override
  State<DailyWordScreen> createState() => _DailyWordScreenState();
}

class _DailyWordScreenState extends State<DailyWordScreen> {
  final _input = TextEditingController();
  final _focus = FocusNode();
  late DailyWordRound _round;
  bool _unavailable = false;
  bool _saving = false;
  bool _sharing = false;
  DailyGuessError? _error;
  DailyWordSaveResult? _saveNotice;
  int _generation = 0;

  DateTime get _date {
    final day = widget.puzzle.day;
    return DateTime(day.year, day.month, day.day);
  }

  String get _courseLabel {
    final course = widget.puzzle.course;
    return '${course.translationLanguage.toUpperCase()} → ${course.studyLanguage.toUpperCase()}';
  }

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void didUpdateWidget(DailyWordScreen oldWidget) {
    super.didUpdateWidget(oldWidget);
    final old = oldWidget.puzzle;
    final puzzle = widget.puzzle;
    if (old.day != puzzle.day ||
        old.level != puzzle.level ||
        old.course.id != puzzle.course.id ||
        old.answer.id != puzzle.answer.id ||
        oldWidget.store != widget.store) {
      _generation++;
      _saving = false;
      _sharing = false;
      _error = null;
      _saveNotice = null;
      _input.clear();
      _load();
    }
  }

  void _load() {
    final puzzle = widget.puzzle;
    final record = widget.store.load(level: puzzle.level, day: _date);
    final sameTarget = record == null || record.targetId == puzzle.answer.id;
    _round = DailyWordRound(
      puzzle,
      guesses: sameTarget && record != null ? record.guesses : const [],
    );
    _unavailable =
        !sameTarget ||
        !_round.validHistory ||
        (record != null &&
            record.finished != (_round.status != DailyWordStatus.playing));
  }

  @override
  void dispose() {
    _input.dispose();
    _focus.dispose();
    super.dispose();
  }

  void _edited() {
    if (_error != null || _saveNotice != null) {
      setState(() {
        _error = null;
        _saveNotice = null;
      });
    }
  }

  void _insertAccent(String letter) {
    final value = _input.value;
    final selection =
        value.selection.isValid
            ? value.selection
            : TextSelection.collapsed(offset: value.text.length);
    _input.value = TextEditingValue(
      text: value.text.replaceRange(selection.start, selection.end, letter),
      selection: TextSelection.collapsed(
        offset: selection.start + letter.length,
      ),
    );
    _edited();
  }

  Future<void> _submit() async {
    if (_saving || _unavailable || _round.status != DailyWordStatus.playing) {
      return;
    }
    final puzzle = widget.puzzle;
    final previous = _round.guesses;
    final next = DailyWordRound(puzzle, guesses: previous);
    final error = next.submit(_input.text);
    if (error != null) {
      setState(() {
        _error = error;
        _saveNotice = null;
      });
      return;
    }
    setState(() {
      _saving = true;
      _error = null;
      _saveNotice = null;
    });
    final generation = _generation;
    final result = await widget.store.append(
      level: puzzle.level,
      day: _date,
      targetId: puzzle.answer.id,
      previousGuesses: previous,
      guess: next.guesses.last,
      finished: next.status != DailyWordStatus.playing,
    );
    if (!mounted || generation != _generation) return;
    setState(() {
      _saving = false;
      _saveNotice = result;
      switch (result) {
        case DailyWordSaveResult.saved:
          _round = next;
        case DailyWordSaveResult.conflict:
          _load();
        case DailyWordSaveResult.failed:
          return;
      }
      _input.clear();
      _focus.unfocus();
    });
  }

  Future<void> _share() async {
    if (_sharing || _round.status == DailyWordStatus.playing) return;
    final generation = _generation;
    setState(() => _sharing = true);
    final score =
        _round.status == DailyWordStatus.won
            ? _round.guesses.length.toString()
            : 'X';
    final puzzle = widget.puzzle;
    try {
      await widget.onShare(
        'ArcadeLingo · ${AppStrings.of(context).dailyWord}\n'
        '${puzzle.day} · $_courseLabel · ${puzzle.level.name.toUpperCase()} · $score/${DailyWordRound.maxAttempts}\n'
        '${_round.shareGrid}',
      );
    } finally {
      if (mounted && generation == _generation) {
        setState(() => _sharing = false);
      }
    }
  }

  String? _notice(AppStrings s) {
    if (_saveNotice == DailyWordSaveResult.failed) return s.dailyWordSaveFailed;
    if (_saveNotice == DailyWordSaveResult.conflict) return s.dailyWordUpdated;
    return switch (_error) {
      DailyGuessError.wrongLength => s.dailyWordWrongLength(
        widget.puzzle.length,
      ),
      DailyGuessError.invalidLetters => s.dailyWordInvalidLetters,
      DailyGuessError.unknownWord => s.dailyWordUnknown,
      DailyGuessError.alreadyTried => s.dailyWordRepeated,
      DailyGuessError.finished || null => null,
    };
  }

  @override
  Widget build(BuildContext context) {
    final s = AppStrings.of(context);
    final theme = Theme.of(context);
    final colors = theme.colorScheme;
    final puzzle = widget.puzzle;
    final extraLetters = switch (puzzle.course.studyLanguage) {
      'es' => const ['á', 'é', 'í', 'ó', 'ú', 'ü', 'ñ'],
      'de' => const ['ä', 'ö', 'ü', 'ß'],
      'ru' => const ['ё'],
      _ => const <String>[],
    };
    final playing = _round.status == DailyWordStatus.playing;
    final won = _round.status == DailyWordStatus.won;
    final notice = _notice(s);
    return ArcadePage(
      title: s.dailyWord,
      compactHeader: true,
      child: SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(18, 8, 18, 24),
        child:
            _unavailable
                ? Text(s.dailyWordUnavailable)
                : Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Wrap(
                      alignment: WrapAlignment.spaceBetween,
                      spacing: 12,
                      runSpacing: 4,
                      children: [
                        Text(
                          MaterialLocalizations.of(
                            context,
                          ).formatMediumDate(_date),
                          style: theme.textTheme.labelLarge?.copyWith(
                            color: colors.onSurfaceVariant,
                          ),
                        ),
                        Semantics(
                          label:
                              '${s.courseName(puzzle.course)} · ${puzzle.level.name.toUpperCase()}',
                          excludeSemantics: true,
                          child: DefaultTextStyle(
                            style: theme.textTheme.labelLarge!.copyWith(
                              color: colors.onSurfaceVariant,
                            ),
                            child: Wrap(
                              crossAxisAlignment: WrapCrossAlignment.center,
                              spacing: 4,
                              children: [
                                Text(
                                  puzzle.course.translationLanguage
                                      .toUpperCase(),
                                ),
                                Icon(
                                  Icons.arrow_forward_rounded,
                                  size: 15,
                                  color: colors.onSurfaceVariant,
                                ),
                                Text(
                                  '${puzzle.course.studyLanguage.toUpperCase()}  ·  ${puzzle.level.name.toUpperCase()}',
                                ),
                              ],
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 10),
                    ArcadePanel(
                      padding: const EdgeInsets.fromLTRB(16, 12, 16, 14),
                      accent: colors.primary,
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Icon(
                                playing
                                    ? Icons.translate_rounded
                                    : won
                                    ? Icons.check_circle_rounded
                                    : Icons.key_rounded,
                                size: 18,
                                color: colors.primary,
                              ),
                              const SizedBox(width: 7),
                              Expanded(
                                child: Text(
                                  playing
                                      ? s.dailyWordClue
                                      : won
                                      ? s.dailyWordWon
                                      : s.dailyWordLost,
                                  style: theme.textTheme.labelLarge?.copyWith(
                                    color: colors.primary,
                                  ),
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 3),
                          Text(
                            playing
                                ? puzzle.answer.translation
                                : puzzle.answer.headword,
                            style: theme.textTheme.headlineMedium?.copyWith(
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                          if (!playing)
                            Text(
                              puzzle.answer.translation,
                              style: theme.textTheme.bodyLarge,
                            ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 16),
                    if (playing) ...[
                      Text(
                        s.dailyWordAttempt(
                          _round.guesses.length + 1,
                          DailyWordRound.maxAttempts,
                        ),
                        textAlign: TextAlign.center,
                        style: theme.textTheme.labelLarge,
                      ),
                      const SizedBox(height: 8),
                    ],
                    ValueListenableBuilder<TextEditingValue>(
                      valueListenable: _input,
                      builder:
                          (_, value, _) => DailyWordBoard(
                            length: puzzle.length,
                            round: _round,
                            draft: value.text,
                          ),
                    ),
                    const SizedBox(height: 12),
                    const DailyWordLegend(),
                    if (notice != null)
                      Padding(
                        padding: const EdgeInsets.only(top: 12),
                        child: Semantics(
                          liveRegion: true,
                          child: Text(
                            notice,
                            style: theme.textTheme.bodyMedium?.copyWith(
                              color:
                                  _saveNotice == DailyWordSaveResult.conflict
                                      ? colors.onSurface
                                      : colors.error,
                            ),
                          ),
                        ),
                      ),
                    const SizedBox(height: 18),
                    if (playing) ...[
                      TextField(
                        key: const Key('dailyWord.input'),
                        controller: _input,
                        focusNode: _focus,
                        readOnly: _saving,
                        autocorrect: false,
                        enableSuggestions: false,
                        textCapitalization: TextCapitalization.none,
                        textInputAction: TextInputAction.done,
                        decoration: InputDecoration(
                          labelText: s.dailyWordEntry(puzzle.length),
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                        ),
                        onChanged: (_) => _edited(),
                        onSubmitted: (_) => _submit(),
                      ),
                      if (extraLetters.isNotEmpty)
                        TextFieldTapRegion(
                          child: LayoutBuilder(
                            builder:
                                (context, constraints) => Wrap(
                                  alignment: WrapAlignment.center,
                                  children: [
                                    for (final letter in extraLetters)
                                      SizedBox(
                                        width:
                                            extraLetters.length == 1
                                                ? 44
                                                : constraints.maxWidth /
                                                        extraLetters.length >=
                                                    44
                                                ? constraints.maxWidth /
                                                    extraLetters.length
                                                : constraints.maxWidth / 4,
                                        child: TextButton(
                                          key: ValueKey(
                                            'dailyWord.accent.$letter',
                                          ),
                                          onPressed:
                                              _saving
                                                  ? null
                                                  : () => _insertAccent(letter),
                                          style: TextButton.styleFrom(
                                            minimumSize: const Size(44, 44),
                                            padding: const EdgeInsets.symmetric(
                                              horizontal: 9,
                                            ),
                                          ),
                                          child: Text(letter),
                                        ),
                                      ),
                                  ],
                                ),
                          ),
                        ),
                      const SizedBox(height: 8),
                      FilledButton.icon(
                        key: const Key('dailyWord.submit'),
                        onPressed: _saving ? null : _submit,
                        icon: const Icon(Icons.check_rounded),
                        label: Text(s.recallCheck),
                      ),
                    ] else
                      FilledButton.icon(
                        key: const Key('dailyWord.share'),
                        onPressed: _sharing ? null : _share,
                        icon: const Icon(Icons.share_outlined),
                        label: Text(s.dailyWordShare),
                      ),
                  ],
                ),
      ),
    );
  }
}
