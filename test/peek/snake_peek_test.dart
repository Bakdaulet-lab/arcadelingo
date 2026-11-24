@Tags(['peek'])
library;

import 'package:arcadelingo/domain/review/review_contract.dart';
import 'package:arcadelingo/domain/review/study_course.dart';
import 'package:arcadelingo/domain/session/leitner_review_session.dart';
import 'package:arcadelingo/features/games/snake/snake_field.dart';
import 'package:arcadelingo/features/games/snake/snake_game.dart';
import 'package:arcadelingo/features/games/snake/snake_run.dart';
import 'package:arcadelingo/ui/theme.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'peek_harness.dart';

const _pairs = {'llave': 'ключ', 'mesa': 'стол', 'reloj': 'часы'};
const _longPairs = {
  'punto de inflexión': 'переломный момент',
  'planteamiento': 'подход',
  'responsabilidad': 'ответственность',
};

Future<void> _pumpSnake(
  WidgetTester tester,
  Brightness brightness, {
  bool largeText = false,
}) async {
  final level = largeText ? CefrLevel.c1 : CefrLevel.a1;
  final vocabulary = [
    for (final entry in (largeText ? _longPairs : _pairs).entries)
      Word(
        id: entry.key,
        text: entry.key,
        translation: entry.value,
        level: level,
      ),
  ];
  tester.view.physicalSize =
      largeText ? const Size(960, 2340) : peekPhysicalSize;
  tester.view.devicePixelRatio = peekDevicePixelRatio;
  tester.platformDispatcher.textScaleFactorTestValue = largeText ? 1.6 : 1;
  addTearDown(tester.view.reset);
  addTearDown(tester.platformDispatcher.clearAllTestValues);
  await tester.pumpWidget(
    MaterialApp(
      debugShowCheckedModeBanner: false,
      theme: wordarcadeTheme(
        brightness: brightness,
        platform: TargetPlatform.android,
      ),
      home: SnakeGame(
        session: LeitnerReviewSession.start(
          cards: {},
          items: vocabulary.map((word) => ReviewItem(word: word)).toList(),
          target: vocabulary.length,
          now: () => DateTime(2026, 11, 21),
          onCardsChanged: (_) {},
        ),
        vocabulary: vocabulary,
        onPlayAgain: () {},
        onExit: () {},
        course: StudyCourse.spanishFromRussian,
        level: level,
        seed: 12,
      ),
    ),
  );
  await tester.pumpAndSettle();
}

Future<void> _catchKey(WidgetTester tester) async {
  final field = find.byKey(SnakeKeys.field);
  final run = tester.widget<SnakeField>(field).run;
  final target = run.apples.firstWhere((a) => a.word.text == 'llave').cell;
  final start = run.body.first;
  final finger = await tester.startGesture(tester.getCenter(field));
  for (final (direction, end) in [
    if (target.y != start.y)
      (
        target.y < start.y ? SnakeDirection.up : SnakeDirection.down,
        (x: start.x, y: target.y),
      ),
    (target.x < start.x ? SnakeDirection.left : SnakeDirection.right, target),
  ]) {
    await finger.moveBy(Offset(direction.dx * 24.0, direction.dy * 24.0));
    for (var frame = 0; run.body.first != end && frame < 180; frame++) {
      await tester.pump(const Duration(milliseconds: 20));
    }
  }
  await finger.up();
  if (run.phase != SnakePhase.feedback) throw StateError('Ключ не пойман');
  await tester.pumpAndSettle();
}

void main() {
  for (final brightness in Brightness.values) {
    testWidgets('змейка — ${brightness.name}', (tester) async {
      await _pumpSnake(tester, brightness);
      await peek(tester, 'snake_${brightness.name}_ready');
      await _catchKey(tester);
      await peek(tester, 'snake_${brightness.name}_answer');
    });
  }

  testWidgets('змейка — увеличенный текст на узком экране', (tester) async {
    await _pumpSnake(tester, Brightness.light, largeText: true);
    await peek(tester, 'snake_light_large_text');
  });
}
