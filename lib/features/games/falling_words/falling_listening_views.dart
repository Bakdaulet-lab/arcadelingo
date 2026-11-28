part of 'falling_words_views.dart';

/// The sound marker takes the place of the written prompt. It never receives
/// the target text, including for accessibility announcements.
class ListeningField extends StatelessWidget {
  const ListeningField({
    required this.progress,
    required this.speaking,
    required this.onReplay,
    this.initialPlayback = false,
    super.key,
  });

  final double progress;
  final bool speaking;
  final bool initialPlayback;
  final VoidCallback? onReplay;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colors = theme.colorScheme;
    final strings = context.strings;
    if (initialPlayback) {
      return ArcadeStatusLayout(
        key: FallingWordsKeys.listeningMarker,
        icon: Icons.headphones_rounded,
        title: strings.listenToWord,
        body: Text(
          strings.listeningChoicesAfterAudio,
          textAlign: TextAlign.center,
          style: theme.textTheme.bodyLarge,
        ),
      );
    }
    final marker = DecoratedBox(
      key: FallingWordsKeys.listeningMarker,
      decoration: BoxDecoration(
        color: colors.primaryContainer,
        border: Border.all(color: colors.primary),
        borderRadius: BorderRadius.circular(24),
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 9),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.graphic_eq_rounded, color: colors.onPrimaryContainer),
            const SizedBox(width: 8),
            Text(
              speaking
                  ? strings.listenToWord
                  : strings.chooseListeningTranslation,
              style: withWeight(
                theme.textTheme.titleMedium!,
                FontWeight.bold,
              ).copyWith(color: colors.onPrimaryContainer),
            ),
          ],
        ),
      ),
    );
    return LayoutBuilder(
      builder: (context, constraints) {
        final compact =
            constraints.maxHeight < 112 || constraints.maxWidth < 320;
        final track = Align(
          alignment: Alignment(0, -1 + 2 * progress.clamp(0.0, 1.0)),
          child: FittedBox(fit: BoxFit.scaleDown, child: marker),
        );
        if (compact) {
          return Padding(
            padding: const EdgeInsets.symmetric(horizontal: 12),
            child: Row(
              children: [
                Expanded(child: track),
                const SizedBox(width: 6),
                Tooltip(
                  message: strings.replayWord,
                  excludeFromSemantics: true,
                  child: IconButton.outlined(
                    key: FallingWordsKeys.listeningReplay,
                    onPressed: onReplay,
                    icon: Icon(
                      Icons.replay_rounded,
                      semanticLabel: strings.replayWord,
                    ),
                  ),
                ),
              ],
            ),
          );
        }
        return Padding(
          padding: const EdgeInsets.fromLTRB(16, 2, 16, 8),
          child: Column(
            children: [
              Row(
                children: [
                  Icon(
                    Icons.headphones_rounded,
                    color: colors.primary,
                    size: 20,
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      strings.listeningMode,
                      style: theme.textTheme.titleMedium,
                    ),
                  ),
                  Flexible(
                    flex: 2,
                    child: TextButton.icon(
                      key: FallingWordsKeys.listeningReplay,
                      onPressed: onReplay,
                      icon: const Icon(Icons.replay_rounded),
                      label: Text(
                        strings.replayWord,
                        textAlign: TextAlign.center,
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              Expanded(child: track),
            ],
          ),
        );
      },
    );
  }
}

class ListeningAudioError extends StatelessWidget {
  const ListeningAudioError({
    required this.error,
    required this.studyLanguage,
    required this.onRetry,
    required this.onUseText,
    super.key,
  });

  final SpeechResult error;
  final String studyLanguage;
  final VoidCallback onRetry;
  final VoidCallback onUseText;

  @override
  Widget build(BuildContext context) {
    final strings = context.strings;
    return ArcadeStatusLayout(
      icon: Icons.headset_off_rounded,
      title: strings.listeningMode,
      body: Text(
        error == SpeechResult.unavailable
            ? strings.voiceUnavailable(studyLanguage)
            : strings.speechFailed,
        textAlign: TextAlign.center,
        style: Theme.of(context).textTheme.bodyLarge,
      ),
      actions: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          FilledButton.icon(
            key: FallingWordsKeys.listeningRetry,
            onPressed: onRetry,
            icon: const Icon(Icons.replay_rounded),
            label: Text(strings.retry),
          ),
          const SizedBox(height: 8),
          OutlinedButton(
            key: FallingWordsKeys.listeningText,
            onPressed: onUseText,
            child: Text(strings.useWrittenWords, textAlign: TextAlign.center),
          ),
        ],
      ),
    );
  }
}

class ListeningReveal extends StatelessWidget {
  const ListeningReveal({
    required this.word,
    required this.answer,
    required this.verdict,
    super.key,
  });

  final String word;
  final String answer;
  final Verdict verdict;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colors = theme.colorScheme;
    final strings = context.strings;
    final (icon, label, accent) = switch (verdict) {
      Verdict.correct => (
        Icons.check_circle_outline_rounded,
        strings.correct,
        colors.primary,
      ),
      Verdict.wrong => (Icons.cancel_outlined, strings.mistake, colors.error),
      Verdict.timeout => (
        Icons.timer_outlined,
        strings.timeUp,
        colors.tertiary,
      ),
    };
    return Center(
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: ArcadePanel(
          accent: accent,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Row(
                children: [
                  Icon(icon, color: accent),
                  const SizedBox(width: 8),
                  Flexible(
                    child: Text(
                      label,
                      style: theme.textTheme.labelLarge?.copyWith(
                        color: accent,
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 16),
              Text(
                word,
                key: FallingWordsKeys.word,
                style: withWeight(
                  theme.textTheme.headlineMedium!,
                  FontWeight.bold,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                answer,
                key: FallingWordsKeys.revealAnswer,
                style: theme.textTheme.titleLarge,
              ),
            ],
          ),
        ),
      ),
    );
  }
}
