import 'package:arcadelingo/ui/theme.dart';
import 'package:flutter/material.dart';

/// Рама вспомогательных страниц с общей шириной и доступным возвратом.
class ArcadePage extends StatelessWidget {
  const ArcadePage({
    required this.title,
    required this.child,
    this.compactHeader = false,
    super.key,
  });

  final String title;
  final Widget child;
  final bool compactHeader;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scale =
        (MediaQuery.textScalerOf(context).scale(16) / 16)
            .clamp(1, double.infinity)
            .toDouble();
    return Scaffold(
      appBar: AppBar(
        title: Text(
          title,
          style: withWeight(theme.textTheme.titleLarge!, FontWeight.bold),
        ),
        toolbarHeight:
            compactHeader
                ? (20 * scale + 20).clamp(52.0, double.infinity)
                : 60 * scale,
        titleSpacing: compactHeader ? 4 : null,
        backgroundColor: theme.colorScheme.surface,
        foregroundColor: theme.colorScheme.onSurface,
        surfaceTintColor: Colors.transparent,
        scrolledUnderElevation: 0,
        centerTitle: false,
      ),
      body: SafeArea(
        top: false,
        child: Align(
          alignment: Alignment.topCenter,
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 640),
            child: SizedBox.expand(child: child),
          ),
        ),
      ),
    );
  }
}
