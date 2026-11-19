import 'package:flutter/material.dart';

/// Общая поверхность карточек, оформленная выбранной темой приложения.
class ArcadePanel extends StatelessWidget {
  const ArcadePanel({
    required this.child,
    this.padding = const EdgeInsets.all(20),
    this.accent,
    super.key,
  });

  final Widget child;
  final EdgeInsetsGeometry padding;
  final Color? accent;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    final paper = colors.brightness == Brightness.light;
    return Container(
      padding: padding,
      decoration: BoxDecoration(
        color: paper ? colors.surfaceContainerLow : null,
        gradient:
            paper
                ? null
                : LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: [
                    colors.surfaceContainerHighest,
                    Color.lerp(
                      colors.surfaceContainerHighest,
                      colors.surface,
                      .4,
                    )!,
                  ],
                ),
        borderRadius: BorderRadius.circular(paper ? 12 : 24),
        border: Border.all(
          color:
              paper
                  ? accent ?? colors.outlineVariant
                  : (accent ?? colors.outline).withValues(alpha: .6),
        ),
      ),
      child: child,
    );
  }
}
