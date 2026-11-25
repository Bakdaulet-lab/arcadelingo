import 'package:arcadelingo/domain/ports/word_sets_store.dart';
import 'package:arcadelingo/domain/review/review_contract.dart';
import 'package:arcadelingo/domain/review/study_course.dart';
import 'package:arcadelingo/ui/app_strings.dart';
import 'package:arcadelingo/ui/arcade_page.dart';
import 'package:flutter/material.dart';

class WordSetEditor extends StatefulWidget {
  const WordSetEditor({
    required this.store,
    required this.course,
    required this.level,
    required this.words,
    this.initial,
    super.key,
  });

  final WordSetsStore store;
  final StudyCourse course;
  final CefrLevel level;
  final Iterable<Word> words;
  final WordSet? initial;

  @override
  State<WordSetEditor> createState() => _WordSetEditorState();
}

class _WordSetEditorState extends State<WordSetEditor> {
  late final _name = TextEditingController(text: widget.initial?.name);
  late final _words =
      widget.words.toList()
        ..sort((a, b) => a.text.toLowerCase().compareTo(b.text.toLowerCase()));
  late final _selected = {
    for (final word in _words)
      if (widget.initial?.wordIds.contains(word.id) == true) word.id,
  };
  String _query = '';
  bool _onlySelected = false;
  bool _saving = false;
  WordSetSaveResult? _error;

  @override
  void dispose() {
    _name.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    if (_saving) return;
    if (_name.text.trim().isEmpty) {
      setState(() => _error = WordSetSaveResult.invalid);
      return;
    }
    setState(() {
      _saving = true;
      _error = null;
    });
    final result = await widget.store.save(
      id: widget.initial?.id,
      level: widget.level,
      name: _name.text.trim(),
      wordIds: _selected,
    );
    if (!mounted) return;
    if (result == WordSetSaveResult.saved) {
      Navigator.of(context).pop(true);
    } else {
      setState(() {
        _saving = false;
        _error = result;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final strings = context.strings;
    final theme = Theme.of(context);
    final filtered =
        _words
            .where(
              (word) =>
                  (!_onlySelected || _selected.contains(word.id)) &&
                  (_query.isEmpty ||
                      word.text.toLowerCase().contains(_query) ||
                      word.translation.toLowerCase().contains(_query)),
            )
            .toList();
    final error = switch (_error) {
      WordSetSaveResult.duplicate => strings.duplicateWordSet,
      WordSetSaveResult.invalid => strings.wordSetNeedsName,
      WordSetSaveResult.missing => strings.missingWordSet,
      WordSetSaveResult.failed => strings.wordSetWriteFailed,
      _ => null,
    };
    return PopScope<bool>(
      canPop: !_saving,
      child: ArcadePage(
        title:
            widget.initial == null
                ? strings.createWordSet
                : strings.editWordSet,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Expanded(
              child: CustomScrollView(
                keyboardDismissBehavior:
                    ScrollViewKeyboardDismissBehavior.onDrag,
                slivers: [
                  SliverPadding(
                    padding: const EdgeInsets.fromLTRB(20, 14, 20, 4),
                    sliver: SliverToBoxAdapter(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            '${strings.courseName(widget.course)} · ${widget.level.name.toUpperCase()}',
                            style: theme.textTheme.labelLarge?.copyWith(
                              color: theme.colorScheme.primary,
                            ),
                          ),
                          const SizedBox(height: 16),
                          TextField(
                            key: const ValueKey('wordSets.name'),
                            controller: _name,
                            readOnly: _saving,
                            textInputAction: TextInputAction.next,
                            decoration: InputDecoration(
                              labelText: strings.wordSetName,
                              border: const OutlineInputBorder(),
                            ),
                            onChanged: (_) {
                              if (_error != null) setState(() => _error = null);
                            },
                          ),
                          const SizedBox(height: 12),
                          TextField(
                            key: const ValueKey('wordSets.search'),
                            readOnly: _saving,
                            textInputAction: TextInputAction.search,
                            decoration: InputDecoration(
                              labelText: strings.wordSetSearch,
                              prefixIcon: const Icon(Icons.search_rounded),
                              border: const OutlineInputBorder(),
                            ),
                            onChanged:
                                (text) => setState(
                                  () => _query = text.trim().toLowerCase(),
                                ),
                          ),
                          const SizedBox(height: 8),
                          FilterChip(
                            key: const ValueKey('wordSets.selected'),
                            label: Text(
                              strings.selectedWordSetCount(_selected.length),
                            ),
                            selected: _onlySelected,
                            onSelected:
                                _saving
                                    ? null
                                    : (value) =>
                                        setState(() => _onlySelected = value),
                          ),
                        ],
                      ),
                    ),
                  ),
                  if (filtered.isEmpty)
                    SliverPadding(
                      padding: const EdgeInsets.all(20),
                      sliver: SliverToBoxAdapter(
                        child: Text(
                          strings.wordSetNoMatches,
                          style: theme.textTheme.bodyLarge,
                        ),
                      ),
                    ),
                  SliverList.builder(
                    itemCount: filtered.length,
                    itemBuilder: (context, index) {
                      final word = filtered[index];
                      return CheckboxListTile(
                        key: ValueKey('wordSets.word.${word.id}'),
                        contentPadding: const EdgeInsets.symmetric(
                          horizontal: 20,
                        ),
                        title: Text(word.text),
                        subtitle: Text(word.translation),
                        value: _selected.contains(word.id),
                        onChanged:
                            _saving
                                ? null
                                : (value) => setState(() {
                                  if (value == true) {
                                    _selected.add(word.id);
                                  } else {
                                    _selected.remove(word.id);
                                  }
                                }),
                      );
                    },
                  ),
                ],
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 8, 20, 12),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  if (error != null)
                    Semantics(
                      liveRegion: true,
                      child: Padding(
                        padding: const EdgeInsets.only(bottom: 6),
                        child: Text(
                          error,
                          style: TextStyle(color: theme.colorScheme.error),
                        ),
                      ),
                    ),
                  FilledButton.icon(
                    key: const ValueKey('wordSets.save'),
                    onPressed: _saving ? null : _save,
                    icon: const Icon(Icons.check_rounded),
                    label: Text(strings.save),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
