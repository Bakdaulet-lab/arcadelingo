import 'package:arcadelingo/app/story_game.dart';
import 'package:arcadelingo/domain/review/review_contract.dart';
import 'package:arcadelingo/domain/review/study_course.dart';
import 'package:arcadelingo/domain/stories/situation_story.dart';
import 'package:arcadelingo/ui/app_strings.dart';
import 'package:arcadelingo/ui/arcade_page.dart';
import 'package:arcadelingo/ui/arcade_panel.dart';
import 'package:arcadelingo/ui/theme.dart';
import 'package:flutter/material.dart';

typedef PlayStoryStage = Future<bool> Function(SituationStory story, int stage);

IconData _iconFor(StorySituation situation) => switch (situation) {
  StorySituation.breakfast => Icons.local_cafe_outlined,
  StorySituation.hotel => Icons.hotel_outlined,
  StorySituation.station => Icons.train_outlined,
};

Color _colorFor(ColorScheme colors, StorySituation situation) =>
    switch (situation) {
      StorySituation.breakfast => colors.tertiary,
      StorySituation.hotel => colors.secondary,
      StorySituation.station => colors.primary,
    };

class SituationStoriesScreen extends StatelessWidget {
  const SituationStoriesScreen({
    required this.course,
    required this.level,
    required this.stories,
    required this.playStage,
    super.key,
  });

  final StudyCourse course;
  final CefrLevel level;
  final List<SituationStory> stories;
  final PlayStoryStage playStage;

  @override
  Widget build(BuildContext context) {
    final strings = context.strings;
    final theme = Theme.of(context);
    final colors = theme.colorScheme;
    return ArcadePage(
      title: strings.situationStories,
      child: ListView(
        padding: const EdgeInsets.fromLTRB(20, 12, 20, 28),
        children: [
          Text(
            '${strings.courseName(course)} · ${level.name.toUpperCase()}',
            style: theme.textTheme.labelLarge?.copyWith(color: colors.primary),
          ),
          const SizedBox(height: 20),
          Semantics(
            header: true,
            child: Text(
              strings.chooseSituation,
              style: withWeight(
                theme.textTheme.headlineSmall!,
                FontWeight.bold,
              ),
            ),
          ),
          const SizedBox(height: 6),
          Text(
            strings.storyHomeHint,
            style: theme.textTheme.bodyMedium?.copyWith(
              color: colors.onSurfaceVariant,
            ),
          ),
          const SizedBox(height: 20),
          for (final story in stories)
            Padding(
              padding: const EdgeInsets.only(bottom: 12),
              child: Material(
                color: colors.surfaceContainerLow,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(
                    colors.brightness == Brightness.light ? 12 : 20,
                  ),
                  side: BorderSide(color: colors.outlineVariant),
                ),
                clipBehavior: Clip.antiAlias,
                child: InkWell(
                  key: ValueKey('story.${story.situation.name}'),
                  onTap:
                      () => Navigator.of(context).push<void>(
                        MaterialPageRoute<void>(
                          builder:
                              (_) => _StoryPage(
                                story: story,
                                playStage: playStage,
                              ),
                        ),
                      ),
                  child: Padding(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 14,
                      vertical: 18,
                    ),
                    child: Row(
                      children: [
                        DecoratedBox(
                          decoration: BoxDecoration(
                            color: _colorFor(
                              colors,
                              story.situation,
                            ).withValues(alpha: .12),
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: Padding(
                            padding: const EdgeInsets.all(10),
                            child: Icon(
                              _iconFor(story.situation),
                              color: _colorFor(colors, story.situation),
                            ),
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                strings.storyTitle(story.situation),
                                style: withWeight(
                                  theme.textTheme.titleMedium!,
                                  FontWeight.bold,
                                ),
                              ),
                              const SizedBox(height: 4),
                              Text(
                                story.firstRound
                                    .take(2)
                                    .map((item) => item.word.text)
                                    .join(' · '),
                                style: theme.textTheme.bodyMedium?.copyWith(
                                  color: colors.onSurfaceVariant,
                                ),
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(width: 4),
                        Icon(
                          Icons.chevron_right_rounded,
                          color: colors.onSurfaceVariant,
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }
}

class _StoryPage extends StatefulWidget {
  const _StoryPage({required this.story, required this.playStage});

  final SituationStory story;
  final PlayStoryStage playStage;

  @override
  State<_StoryPage> createState() => _StoryPageState();
}

class _StoryPageState extends State<_StoryPage> {
  int _stage = 0;
  bool _launching = false;
  bool _interrupted = false;
  bool _solved = false;
  final _misses = <int>{};

  Future<void> _playRound() async {
    if (_launching) return;
    setState(() => _launching = true);
    try {
      final complete = await widget.playStage(widget.story, _stage);
      if (!mounted) return;
      setState(() {
        _interrupted = !complete;
        if (complete) _stage++;
      });
    } finally {
      if (mounted) setState(() => _launching = false);
    }
  }

  void _answer(int index) {
    setState(() {
      if (index == widget.story.correctIndex) {
        _solved = true;
      } else {
        _misses.add(index);
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final strings = context.strings;
    final theme = Theme.of(context);
    final colors = theme.colorScheme;
    final story = widget.story;
    final accent = _colorFor(colors, story.situation);
    final playing = _stage < 2;
    final progress =
        playing ? strings.storyRound(_stage + 1) : strings.storyFinal;
    final titleStyle = withWeight(
      theme.textTheme.headlineSmall!,
      FontWeight.bold,
    );
    return ArcadePage(
      title: strings.storyTitle(story.situation),
      child: SingleChildScrollView(
        key: ValueKey((_stage, _solved)),
        padding: const EdgeInsets.fromLTRB(20, 12, 20, 28),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            if (!_solved) ...[
              Semantics(
                header: true,
                child: Text(
                  progress,
                  style: theme.textTheme.labelLarge?.copyWith(color: accent),
                ),
              ),
              const SizedBox(height: 8),
              Row(
                children: [
                  for (int i = 0; i < 3; i++) ...[
                    if (i > 0) const SizedBox(width: 6),
                    Expanded(
                      child: DecoratedBox(
                        decoration: BoxDecoration(
                          color:
                              i <= _stage
                                  ? accent
                                  : colors.surfaceContainerHighest,
                          borderRadius: BorderRadius.circular(3),
                        ),
                        child: const SizedBox(height: 4),
                      ),
                    ),
                  ],
                ],
              ),
              const SizedBox(height: 24),
            ],
            if (playing) ...[
              ArcadePanel(
                accent: accent,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Icon(
                      _stage == 0
                          ? Icons.view_module_outlined
                          : Icons.south_rounded,
                      color: accent,
                      size: 30,
                    ),
                    const SizedBox(height: 12),
                    Text(
                      storyStageGames[_stage].titleFor(strings),
                      style: titleStyle,
                    ),
                    if (storyStageGames[_stage].instructionFor(strings)
                        case final String instruction) ...[
                      const SizedBox(height: 4),
                      Text(instruction, style: theme.textTheme.bodyMedium),
                    ],
                    const Divider(height: 28),
                    for (final item
                        in _stage == 0 ? story.firstRound : story.secondRound)
                      Padding(
                        padding: const EdgeInsets.symmetric(vertical: 4),
                        child: Text.rich(
                          TextSpan(
                            children: [
                              TextSpan(
                                text: item.word.text,
                                style: const TextStyle(
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                              TextSpan(
                                text: '  ·  ${item.word.translation}',
                                style: TextStyle(
                                  color: colors.onSurfaceVariant,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                  ],
                ),
              ),
              if (_interrupted) ...[
                const SizedBox(height: 12),
                Semantics(
                  liveRegion: true,
                  child: Text(strings.storyRoundInterrupted),
                ),
              ],
              const SizedBox(height: 16),
              FilledButton.icon(
                key: const Key('story.play'),
                onPressed: _launching ? null : _playRound,
                icon: const Icon(Icons.play_arrow_rounded),
                label: Text(strings.startStoryRound),
              ),
            ] else if (!_solved) ...[
              ArcadePanel(
                key: const Key('story.final'),
                accent: accent,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Icon(_iconFor(story.situation), color: accent, size: 32),
                    const SizedBox(height: 12),
                    Text(story.clue, style: titleStyle),
                  ],
                ),
              ),
              const SizedBox(height: 20),
              Semantics(
                header: true,
                child: Text(
                  story.question,
                  style: withWeight(
                    theme.textTheme.titleMedium!,
                    FontWeight.bold,
                  ),
                ),
              ),
              const SizedBox(height: 8),
              if (_misses.isNotEmpty) ...[
                Semantics(
                  liveRegion: true,
                  child: Text(strings.tryStoryAnswerAgain),
                ),
                const SizedBox(height: 6),
              ],
              for (final (i, answer) in story.choices.indexed)
                Padding(
                  padding: const EdgeInsets.only(top: 8),
                  child: OutlinedButton(
                    key: ValueKey('story.answer.$i'),
                    onPressed: _misses.contains(i) ? null : () => _answer(i),
                    style: OutlinedButton.styleFrom(
                      alignment: Alignment.centerLeft,
                      minimumSize: const Size(0, 48),
                      padding: const EdgeInsets.symmetric(
                        horizontal: 16,
                        vertical: 12,
                      ),
                    ),
                    child: Row(
                      children: [
                        Expanded(child: Text(answer)),
                        Icon(
                          _misses.contains(i)
                              ? Icons.close_rounded
                              : Icons.chevron_right_rounded,
                          size: 20,
                        ),
                      ],
                    ),
                  ),
                ),
            ] else ...[
              ArcadePanel(
                key: const Key('story.complete'),
                accent: colors.primary,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Icon(
                      Icons.check_circle_rounded,
                      color: colors.primary,
                      size: 40,
                    ),
                    const SizedBox(height: 14),
                    Semantics(
                      header: true,
                      liveRegion: true,
                      child: Text(strings.storyComplete, style: titleStyle),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      story.choices[story.correctIndex],
                      style: theme.textTheme.titleMedium?.copyWith(
                        color: colors.primary,
                      ),
                    ),
                    const Divider(height: 28),
                    Text(story.clue, style: theme.textTheme.bodyLarge),
                    const SizedBox(height: 6),
                    Text(
                      story.explanation,
                      style: theme.textTheme.bodyMedium?.copyWith(
                        color: colors.onSurfaceVariant,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 16),
              FilledButton(
                key: const Key('story.done'),
                onPressed: () => Navigator.of(context).pop(),
                child: Text(strings.backToSituations),
              ),
            ],
          ],
        ),
      ),
    );
  }
}
