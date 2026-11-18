import 'package:arcadelingo/ui/theme.dart';
import 'package:flutter/material.dart';

/// Выбор одного значения в общей палитре «Ночной аркады».
Future<T?> showArcadeChoice<T>(
  BuildContext context, {
  required String title,
  required Iterable<T> choices,
  required T selected,
  required String Function(T) label,
  required Key Function(T) optionKey,
}) => showDialog<T>(
  context: context,
  builder: (context) {
    final theme = Theme.of(context);
    final colors = theme.colorScheme;
    return SimpleDialog(
      title: Text(
        title,
        style: withWeight(theme.textTheme.titleLarge!, FontWeight.bold),
      ),
      titlePadding: const EdgeInsets.fromLTRB(20, 18, 20, 10),
      contentPadding: const EdgeInsets.fromLTRB(8, 0, 8, 8),
      backgroundColor: colors.surfaceContainerHighest,
      surfaceTintColor: Colors.transparent,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(24),
        side: BorderSide(color: colors.outline),
      ),
      children: [
        for (final choice in choices)
          SimpleDialogOption(
            key: optionKey(choice),
            onPressed: () => Navigator.pop(context, choice),
            padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 2),
            child: Semantics(
              selected: choice == selected,
              child: Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 12,
                  vertical: 8,
                ),
                constraints: const BoxConstraints(minHeight: 48),
                decoration: BoxDecoration(
                  color:
                      choice == selected
                          ? colors.primary.withValues(alpha: .10)
                          : Colors.transparent,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Row(
                  children: [
                    Icon(
                      choice == selected
                          ? Icons.check_circle_rounded
                          : Icons.radio_button_unchecked_rounded,
                      size: 20,
                      color:
                          choice == selected ? colors.primary : colors.outline,
                    ),
                    const SizedBox(width: 12),
                    Expanded(child: Text(label(choice))),
                  ],
                ),
              ),
            ),
          ),
      ],
    );
  },
);
