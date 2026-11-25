import 'dart:math';

import 'package:arcadelingo/ui/theme.dart';
import 'package:flutter/material.dart';

import 'ninja_trajectory.dart';

const _gap = 10.0;
const _frame = 12.0;
const _diameter = objectRadius * 2;

TextStyle ninjaLabelStyle(BuildContext context) => withWeight(
  Theme.of(context).textTheme.bodyMedium!,
  FontWeight.bold,
).copyWith(height: 1.15);

/// Prepared once per question and display configuration. Painting and slicing
/// read the same measurements and trajectories.
class NinjaWordLayout {
  NinjaWordLayout({
    required BuildContext context,
    required this.field,
    required String prompt,
    required List<String> labels,
  }) {
    final theme = Theme.of(context);
    final painter = TextPainter(
      textDirection: Directionality.of(context),
      textScaler: MediaQuery.textScalerOf(context),
      locale: Localizations.maybeLocaleOf(context),
    );
    try {
      final promptWidth = max(1.0, field.width - 32);
      final title = withWeight(theme.textTheme.displaySmall!, FontWeight.bold);
      painter.text = TextSpan(text: prompt, style: title);
      painter.layout();
      promptStyle =
          painter.width <= promptWidth
              ? title
              : withWeight(theme.textTheme.headlineSmall!, FontWeight.bold);
      painter.text = TextSpan(text: prompt, style: promptStyle);
      painter.layout(maxWidth: promptWidth);
      promptHeight = painter.height;

      final style = ninjaLabelStyle(context);
      final size = style.fontSize!;
      final maxWidth = max(1.0, field.width - _frame * 2);
      final compact =
          painter.textScaler.scale(size) <= size &&
          promptHeight + 24 <= field.height * .22 &&
          labels.every((label) => targetWidth(label, field) == _diameter);
      for (final label in labels) {
        final preferredWidth = targetWidth(label, field);
        if (compact) {
          targets.add(const Size.square(_diameter));
          continue;
        }
        painter.text = TextSpan(text: label, style: style);
        painter.layout();
        final naturalWidth = painter.maxIntrinsicWidth.ceilToDouble() + 32;
        painter.text = TextSpan(
          text: label.split(RegExp(r'\s+')).join('\n'),
          style: style,
        );
        painter.layout();
        final minWidth = painter.width.ceilToDouble() + 32;
        painter.text = TextSpan(text: label, style: style);
        final candidate = max(preferredWidth, minWidth);
        var width = min(maxWidth, max(_diameter, min(candidate, naturalWidth)));
        painter.layout(maxWidth: max(1.0, width - 32));
        if (painter.height > _diameter - 12) {
          width = min(maxWidth, max(width, naturalWidth));
          painter.layout(maxWidth: max(1.0, width - 32));
        }
        final height = max(_diameter, painter.height.ceilToDouble() + 16);
        targets.add(Size(width, height));
      }
    } finally {
      painter.dispose();
    }
    stackHeight =
        targets.fold<double>(0, (height, target) => height + target.height) +
        max(0, targets.length - 1) * _gap;
    stacked =
        targets.any(
          (size) => size.width > _diameter || size.height > _diameter,
        ) ||
        promptHeight + 24 > field.height * .22;
    scrolls = stacked && (promptHeight + stackHeight + 32 > field.height);
  }

  final Size field;
  late final TextStyle promptStyle;
  late final double promptHeight;
  late final double stackHeight;
  late final bool stacked;
  late final bool scrolls;
  final targets = <Size>[];

  double _stackTop() => max(
    promptHeight + 24,
    min(field.height * .25, field.height - stackHeight - _frame),
  );

  double _drift(int index) =>
      (index.isEven ? 1 : -1) *
      max(
        0,
        min(field.width * .08, (field.width - targets[index].width) / 2 - 4),
      );

  List<Offset> centers(double t) {
    if (!stacked) {
      return wavePositions(
        count: targets.length,
        t: t,
        width: field.width,
        height: field.height,
      );
    }
    var dy = field.height + 2;
    final amplitude = dy - _stackTop();
    return [
      for (final (index, size) in targets.indexed)
        trajectory(
          t: t,
          lane: field.width / 2 - _drift(index) / 2,
          drift: _drift(index),
          apex: amplitude,
          bottom: (dy += size.height + _gap) - size.height / 2 - _gap,
        ),
    ];
  }

  Offset velocity(int index, double t, Duration duration) {
    if (!stacked) {
      return waveVelocity(
        count: targets.length,
        index: index,
        t: t,
        width: field.width,
        height: field.height,
        duration: duration,
      );
    }
    return trajectoryVelocity(
      t: t,
      drift: _drift(index),
      apex: field.height + 2 - _stackTop(),
      duration: duration,
    );
  }
}
