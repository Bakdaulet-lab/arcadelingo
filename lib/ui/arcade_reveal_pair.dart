import 'package:arcadelingo/ui/arcade_panel.dart';
import 'package:arcadelingo/ui/theme.dart';
import 'package:flutter/material.dart';

/// Полная учебная пара в доступном поле после промаха.
class ArcadeRevealPair extends StatelessWidget {
  const ArcadeRevealPair({
    required this.word,
    required this.answer,
    required this.wordKey,
    required this.answerKey,
    super.key,
  });

  final String word;
  final String answer;
  final Key wordKey;
  final Key answerKey;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colors = theme.colorScheme;
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: LayoutBuilder(
          builder:
              (context, constraints) => FittedBox(
                fit: BoxFit.scaleDown,
                child: SizedBox(
                  width: constraints.maxWidth,
                  child: ArcadePanel(
                    padding: const EdgeInsets.all(16),
                    accent: colors.primary,
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Row(
                          children: [
                            Icon(Icons.close, color: colors.error, size: 28),
                            const SizedBox(width: 8),
                            Expanded(
                              child: FittedBox(
                                fit: BoxFit.scaleDown,
                                child: Text(
                                  word,
                                  key: wordKey,
                                  softWrap: false,
                                  style: withWeight(
                                    theme.textTheme.displaySmall!,
                                    FontWeight.bold,
                                  ).copyWith(color: colors.error),
                                ),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 8),
                        Icon(
                          Icons.arrow_downward_rounded,
                          color: colors.onSurfaceVariant,
                          size: 24,
                        ),
                        const SizedBox(height: 8),
                        Text(
                          answer,
                          key: answerKey,
                          textAlign: TextAlign.center,
                          style: withWeight(
                            theme.textTheme.headlineSmall!,
                            FontWeight.bold,
                          ).copyWith(color: colors.primary, height: 1.3),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
        ),
      ),
    );
  }
}
