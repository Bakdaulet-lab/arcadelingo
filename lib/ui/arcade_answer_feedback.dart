import 'dart:async';

import 'package:flutter/material.dart';

/// A single accent on an answer. The game owns the verdict and its duration.
/// Use a new key when consecutive answers share this location in the tree.
class ArcadeAnswerFeedback extends StatefulWidget {
  const ArcadeAnswerFeedback({
    required this.correct,
    required this.child,
    super.key,
  });

  final bool correct;
  final Widget child;

  @override
  State<ArcadeAnswerFeedback> createState() => _ArcadeAnswerFeedbackState();
}

class _ArcadeAnswerFeedbackState extends State<ArcadeAnswerFeedback>
    with SingleTickerProviderStateMixin {
  late final AnimationController _progress;
  bool _firstAnswer = true;
  bool _reduced = false;

  @override
  void initState() {
    super.initState();
    _progress = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 240),
      value: 1,
    );
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _reduced = MediaQuery.disableAnimationsOf(context);
    if (_reduced) {
      _progress.value = 1;
    } else if (_firstAnswer) {
      unawaited(_progress.forward(from: 0));
    }
    _firstAnswer = false;
  }

  @override
  void didUpdateWidget(ArcadeAnswerFeedback oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.correct != widget.correct && !_reduced) {
      unawaited(_progress.forward(from: 0));
    }
  }

  @override
  Widget build(BuildContext context) => AnimatedBuilder(
    animation: _progress,
    child: widget.child,
    builder: (context, child) {
      final pulse = Curves.easeInOut.transform(
        1 - (2 * _progress.value - 1).abs(),
      );
      return Transform(
        transformHitTests: false,
        alignment: Alignment.center,
        transform:
            widget.correct
                ? (Matrix4.translationValues(0, -3 * pulse, 0)
                  ..scale(1 + .025 * pulse, 1 + .025 * pulse))
                : Matrix4.translationValues(-4 * pulse, 0, 0),
        child: child,
      );
    },
  );

  @override
  void dispose() {
    _progress.dispose();
    super.dispose();
  }
}
