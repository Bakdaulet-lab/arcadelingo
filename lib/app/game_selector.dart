import 'package:arcadelingo/app/games.dart';
import 'package:arcadelingo/ui/app_strings.dart';
import 'package:arcadelingo/ui/theme.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

/// Карточки строятся из реестра, включая игры, добавленные позднее.
class GameSelector extends StatelessWidget {
  const GameSelector({
    required this.games,
    required this.selectedId,
    required this.onSelected,
    super.key,
  });

  final List<GameEntry> games;
  final String selectedId;
  final ValueChanged<String> onSelected;

  @override
  Widget build(BuildContext context) {
    if (Theme.of(context).brightness == Brightness.light) {
      return LayoutBuilder(
        builder: (context, constraints) {
          final paired =
              constraints.maxWidth >= 300 &&
              MediaQuery.textScalerOf(context).scale(16) <= 22;
          return Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              for (final (index, game) in games.indexed)
                SizedBox(
                  width:
                      paired && index > 0
                          ? (constraints.maxWidth - 8) / 2
                          : constraints.maxWidth,
                  child: _PaperGameCard(
                    game: game,
                    selected: game.id == selectedId,
                    compact: paired && index > 0,
                    onPressed: () => onSelected(game.id),
                  ),
                ),
            ],
          );
        },
      );
    }
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        for (final (index, game) in games.indexed) ...[
          if (index > 0) const SizedBox(height: 12),
          _GameCard(
            game: game,
            selected: game.id == selectedId,
            onPressed: () => onSelected(game.id),
          ),
        ],
      ],
    );
  }
}

class _GameCard extends StatelessWidget {
  const _GameCard({
    required this.game,
    required this.selected,
    required this.onPressed,
  });

  final GameEntry game;
  final bool selected;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colors = theme.colorScheme;
    final artwork = game.artwork;
    final instruction = game.instructionFor(context.strings);
    final largeText = MediaQuery.textScalerOf(context).scale(16) > 22;
    final shape = RoundedRectangleBorder(
      borderRadius: BorderRadius.circular(22),
      side: BorderSide(
        color:
            selected ? colors.primary : colors.outline.withValues(alpha: .65),
        width: selected ? 2 : 1,
      ),
    );

    return Semantics(
      button: true,
      selected: selected,
      child: Material(
        color: colors.surfaceContainerHighest,
        shape: shape,
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          onTap: onPressed,
          customBorder: shape,
          child: Stack(
            children: [
              if (artwork != null)
                Positioned.fill(
                  child: ExcludeSemantics(
                    child: Image.asset(
                      artwork,
                      // Иллюстрации входят в пакет приложения. Подмена словаря
                      // через DefaultAssetBundle не меняет их источник.
                      bundle: rootBundle,
                      alignment: Alignment.centerRight,
                      fit: BoxFit.cover,
                      cacheWidth: 1200,
                    ),
                  ),
                ),
              Positioned.fill(
                child: DecoratedBox(
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      colors: [
                        const Color(0xFF171220),
                        const Color(
                          0xFF171220,
                        ).withValues(alpha: largeText ? .94 : .9),
                        const Color(
                          0xFF171220,
                        ).withValues(alpha: largeText ? .8 : .06),
                      ],
                      stops: const [0, .36, 1],
                    ),
                  ),
                ),
              ),
              Padding(
                padding: const EdgeInsets.all(14),
                child: ConstrainedBox(
                  constraints: const BoxConstraints(minHeight: 80),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Text(
                        game.titleFor(context.strings),
                        style: withWeight(
                          theme.textTheme.titleLarge!,
                          FontWeight.bold,
                        ).copyWith(color: colors.onSurface, fontSize: 20),
                      ),
                      if (instruction != null) ...[
                        const SizedBox(height: 6),
                        FractionallySizedBox(
                          widthFactor: largeText ? 1 : .64,
                          child: Text(
                            instruction,
                            style: theme.textTheme.bodySmall?.copyWith(
                              color: const Color(0xFFD5C8EC),
                              height: 1.35,
                            ),
                          ),
                        ),
                      ],
                      const SizedBox(height: 8),
                      ExcludeSemantics(
                        child: Container(
                          width: 20,
                          height: 20,
                          decoration: BoxDecoration(
                            color:
                                selected
                                    ? colors.primary
                                    : colors.surface.withValues(alpha: .65),
                            shape: BoxShape.circle,
                            border: Border.all(
                              color: selected ? colors.primary : colors.outline,
                            ),
                          ),
                          child: Icon(
                            selected ? Icons.check_rounded : Icons.play_arrow,
                            size: 16,
                            color:
                                selected ? colors.onPrimary : colors.onSurface,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _PaperGameCard extends StatelessWidget {
  const _PaperGameCard({
    required this.game,
    required this.selected,
    required this.compact,
    required this.onPressed,
  });

  final GameEntry game;
  final bool selected;
  final bool compact;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colors = theme.colorScheme;
    final artwork = game.artwork;
    final instruction = game.instructionFor(context.strings);
    final tint = switch (game.id) {
      'falling_words' => const Color(0xFFF8E3BB),
      'ninja_slash' => const Color(0xFFEBDEEE),
      'claw_machine' => const Color(0xFFE9EAD4),
      _ => colors.surfaceContainerHigh,
    };
    final shape = RoundedRectangleBorder(
      borderRadius: BorderRadius.circular(12),
      side: BorderSide(
        color: selected ? colors.primary : colors.outlineVariant,
        width: selected ? 2 : 1,
      ),
    );

    return Semantics(
      button: true,
      selected: selected,
      child: Material(
        color: tint,
        shape: shape,
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          onTap: onPressed,
          customBorder: shape,
          child: Stack(
            alignment: compact ? Alignment.bottomLeft : Alignment.centerLeft,
            children: [
              if (artwork != null)
                Positioned.fill(
                  child: FractionallySizedBox(
                    widthFactor: compact ? .87 : .52,
                    alignment: Alignment.centerRight,
                    child: ExcludeSemantics(
                      child: ShaderMask(
                        shaderCallback:
                            (rect) => LinearGradient(
                              begin:
                                  compact
                                      ? Alignment.bottomCenter
                                      : Alignment.centerLeft,
                              end:
                                  compact
                                      ? Alignment.topCenter
                                      : Alignment.centerRight,
                              colors: const [Colors.transparent, Colors.white],
                              stops:
                                  compact ? const [.14, .95] : const [0, .78],
                            ).createShader(rect),
                        blendMode: BlendMode.dstIn,
                        child: Image.asset(
                          artwork,
                          bundle: rootBundle,
                          alignment: Alignment.centerRight,
                          fit: BoxFit.cover,
                          cacheWidth: 1200,
                        ),
                      ),
                    ),
                  ),
                ),
              Padding(
                padding: const EdgeInsets.all(12),
                child: ConstrainedBox(
                  constraints: BoxConstraints(minHeight: compact ? 66 : 86),
                  child: FractionallySizedBox(
                    widthFactor: compact || artwork == null ? 1 : .66,
                    alignment: Alignment.centerLeft,
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisAlignment:
                          compact
                              ? MainAxisAlignment.end
                              : MainAxisAlignment.center,
                      children: [
                        Text(
                          game.titleFor(context.strings),
                          style: withWeight(
                            theme.textTheme.titleMedium!,
                            FontWeight.bold,
                          ),
                        ),
                        if (!compact && instruction != null) ...[
                          const SizedBox(height: 4),
                          Text(instruction, style: theme.textTheme.bodySmall),
                        ],
                      ],
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
