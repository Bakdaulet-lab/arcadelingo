import 'package:arcadelingo/domain/review/review_contract.dart';
import 'package:flutter/material.dart';

abstract final class ClawKeys {
  static const prompt = Key('claw.prompt');
  static const slots = Key('claw.slots');
  static const left = Key('claw.left');
  static const right = Key('claw.right');
  static const grab = Key('claw.grab');
  static const hint = Key('claw.hint');
  static const next = Key('claw.next');
  static const result = Key('claw.result');
  static const summary = Key('claw.summary');
  static Key topCapsule(int column) => ValueKey('claw.capsule.$column');
}

class ClawMachineGame extends StatefulWidget {
  const ClawMachineGame({
    required this.session,
    required this.onExit,
    required this.onPlayAgain,
    this.onRoundOver,
    this.summaryFooter,
    this.mistakeCount,
    this.onReviewMistakes,
    this.now,
    this.seed,
    super.key,
  });

  final ReviewSession session;
  final VoidCallback onExit;
  final VoidCallback onPlayAgain;
  final VoidCallback? onRoundOver;
  final String Function()? summaryFooter;
  final int Function()? mistakeCount;
  final VoidCallback? onReviewMistakes;
  final DateTime Function()? now;
  final int? seed;

  @override
  State<ClawMachineGame> createState() => throw UnimplementedError();
}
