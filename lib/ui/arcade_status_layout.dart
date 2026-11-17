import 'package:arcadelingo/ui/theme.dart';
import 'package:flutter/material.dart';

/// Пустой результат, завершённая партия или ошибка с одним главным действием.
class ArcadeStatusLayout extends StatelessWidget {
  const ArcadeStatusLayout({
    required this.icon,
    required this.title,
    this.body,
    this.actions,
    this.accent,
    super.key,
  });

  final IconData icon;
  final String title;
  final Widget? body;
  final Widget? actions;
  final Color? accent;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final color = accent ?? theme.colorScheme.primary;
    return SafeArea(
      child: LayoutBuilder(
        builder:
            (context, constraints) => SingleChildScrollView(
              padding: const EdgeInsets.all(20),
              child: ConstrainedBox(
                constraints: BoxConstraints(
                  minHeight: (constraints.maxHeight - 40).clamp(
                    0,
                    double.infinity,
                  ),
                ),
                child: Center(
                  child: ConstrainedBox(
                    constraints: const BoxConstraints(maxWidth: 520),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        Center(
                          child: Container(
                            width: 64,
                            height: 64,
                            decoration: BoxDecoration(
                              color: color.withValues(alpha: .12),
                              borderRadius: BorderRadius.circular(22),
                              border: Border.all(
                                color: color.withValues(alpha: .4),
                              ),
                            ),
                            child: Icon(icon, size: 34, color: color),
                          ),
                        ),
                        const SizedBox(height: 14),
                        Text(
                          title,
                          textAlign: TextAlign.center,
                          style: withWeight(
                            theme.textTheme.headlineSmall!,
                            FontWeight.bold,
                          ),
                        ),
                        if (body != null) ...[
                          const SizedBox(height: 20),
                          body!,
                        ],
                        if (actions != null) ...[
                          const SizedBox(height: 24),
                          actions!,
                        ],
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
