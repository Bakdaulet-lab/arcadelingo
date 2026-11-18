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
  Widget build(BuildContext context) => Column(
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
