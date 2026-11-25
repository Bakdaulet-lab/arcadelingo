import 'package:arcadelingo/domain/ports/word_sets_store.dart';
import 'package:arcadelingo/domain/review/review_contract.dart';
import 'package:arcadelingo/domain/review/study_course.dart';
import 'package:arcadelingo/ui/app_strings.dart';
import 'package:arcadelingo/ui/arcade_page.dart';
import 'package:arcadelingo/ui/arcade_panel.dart';
import 'package:flutter/material.dart';

import 'word_set_editor.dart';

class WordSetsScreen extends StatefulWidget {
  const WordSetsScreen({
    required this.store,
    required this.course,
    required this.level,
    required this.vocabulary,
    required this.onPlay,
    super.key,
  });

  final WordSetsStore store;
  final StudyCourse course;
  final CefrLevel level;
  final List<Word> vocabulary;
  final Future<void> Function(WordSet set) onPlay;

  @override
  State<WordSetsScreen> createState() => _WordSetsScreenState();
}

class _WordSetsScreenState extends State<WordSetsScreen> {
  late List<WordSet> _sets = widget.store.load(widget.level);
  late final Map<String, Word> _words = {
    for (final word in widget.vocabulary)
      if (word.level == widget.level) word.id: word,
  };
  bool _busy = false;

  Future<void> _edit([WordSet? set]) async {
    final saved = await Navigator.of(context).push<bool>(
      MaterialPageRoute<bool>(
        builder:
            (_) => WordSetEditor(
              store: widget.store,
              course: widget.course,
              level: widget.level,
              words: _words.values,
              initial: set,
            ),
      ),
    );
    if (mounted && saved == true) {
      setState(() => _sets = widget.store.load(widget.level));
    }
  }

  Future<void> _remove(WordSet set) async {
    final strings = context.strings;
    final confirm = await showDialog<bool>(
      context: context,
      builder:
          (context) => AlertDialog(
            title: Text(strings.deleteWordSet(set.name)),
            content: Text(strings.deletingSetKeepsWords),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context, false),
                child: Text(strings.cancel),
              ),
              TextButton(
                key: const ValueKey('wordSets.confirmDelete'),
                onPressed: () => Navigator.pop(context, true),
                child: Text(strings.delete),
              ),
            ],
          ),
    );
    if (!mounted || confirm != true || _busy) return;
    setState(() => _busy = true);
    final deleted = await widget.store.remove(level: widget.level, id: set.id);
    if (!mounted) return;
    setState(() {
      _sets = widget.store.load(widget.level);
      _busy = false;
    });
    if (!deleted) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(strings.wordSetWriteFailed)));
    }
  }

  Future<void> _play(WordSet set) async {
    if (_busy) return;
    setState(() => _busy = true);
    try {
      await widget.onPlay(set);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final strings = context.strings;
    final theme = Theme.of(context);
    return ArcadePage(
      title: strings.wordSets,
      child: ListView.separated(
        padding: const EdgeInsets.fromLTRB(20, 14, 20, 24),
        itemCount: _sets.length + 1,
        separatorBuilder: (_, _) => const SizedBox(height: 14),
        itemBuilder: (context, index) {
          if (index == 0) {
            return Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  '${strings.courseName(widget.course)} · ${widget.level.name.toUpperCase()}',
                  style: theme.textTheme.labelLarge?.copyWith(
                    color: theme.colorScheme.primary,
                  ),
                ),
                const SizedBox(height: 14),
                if (_sets.isEmpty) ...[
                  Text(strings.emptyWordSets, style: theme.textTheme.bodyLarge),
                  const SizedBox(height: 16),
                ],
                FilledButton.icon(
                  key: const ValueKey('wordSets.create'),
                  onPressed: _busy ? null : _edit,
                  icon: const Icon(Icons.add_rounded),
                  label: Text(strings.createWordSet),
                ),
              ],
            );
          }
          final set = _sets[index - 1];
          final available =
              set.wordIds.map((id) => _words[id]).whereType<Word>().toList();
          return ArcadePanel(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(set.name, style: theme.textTheme.titleLarge),
                          const SizedBox(height: 4),
                          Text(
                            strings.wordSetCount(available.length),
                            style: theme.textTheme.labelLarge?.copyWith(
                              color: theme.colorScheme.primary,
                            ),
                          ),
                        ],
                      ),
                    ),
                    PopupMenuButton<_SetAction>(
                      key: ValueKey('wordSets.menu.${set.id}'),
                      enabled: !_busy,
                      icon: const Icon(Icons.more_horiz_rounded),
                      onSelected: (action) async {
                        switch (action) {
                          case _SetAction.edit:
                            await _edit(set);
                          case _SetAction.delete:
                            await _remove(set);
                        }
                      },
                      itemBuilder:
                          (_) => [
                            PopupMenuItem(
                              value: _SetAction.edit,
                              child: Text(strings.edit),
                            ),
                            PopupMenuItem(
                              value: _SetAction.delete,
                              child: Text(strings.delete),
                            ),
                          ],
                    ),
                  ],
                ),
                if (available.isNotEmpty) ...[
                  const SizedBox(height: 8),
                  Text(
                    available.take(4).map((word) => word.text).join(' · '),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: theme.textTheme.bodyMedium?.copyWith(
                      color: theme.colorScheme.onSurfaceVariant,
                    ),
                  ),
                ] else
                  Align(
                    alignment: AlignmentDirectional.centerStart,
                    child: TextButton(
                      onPressed: _busy ? null : () => _edit(set),
                      child: Text(strings.addWordsToSet),
                    ),
                  ),
                const SizedBox(height: 12),
                FilledButton.tonalIcon(
                  key: ValueKey('wordSets.play.${set.id}'),
                  onPressed:
                      _busy || available.isEmpty ? null : () => _play(set),
                  icon: const Icon(Icons.play_arrow_rounded),
                  label: Text(strings.play),
                ),
              ],
            ),
          );
        },
      ),
    );
  }
}

enum _SetAction { edit, delete }
