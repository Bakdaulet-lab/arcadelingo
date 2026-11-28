@Tags(['peek'])
library;

import 'dart:io';
import 'dart:ui' as ui;

import 'package:arcadelingo/domain/review/review_contract.dart';
import 'package:arcadelingo/domain/review/study_course.dart';
import 'package:arcadelingo/features/games/match_three/match_three_game.dart';
import 'package:arcadelingo/ui/theme.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_test/flutter_test.dart';

import '../support/fake_review_session.dart';
import 'peek_harness.dart';

const _item = ReviewItem(
  word: Word(id: 'llave', text: 'llave', translation: 'ключ'),
  distractors: ['дверь', 'билет'],
);

const _screen = Key('match_three.peek');

Future<void> _fieldFrame(WidgetTester tester, String folder, int frame) async {
  final screen = tester.renderObject<RenderRepaintBoundary>(
    find.byKey(_screen),
  );
  final field = tester.getRect(find.byKey(MatchThreeKeys.field));
  final bounds = field
      .shift(-screen.localToGlobal(Offset.zero))
      .intersect(screen.paintBounds);
  await tester.runAsync(() async {
    final image = await (screen.debugLayer! as OffsetLayer).toImage(bounds);
    try {
      final bytes = await image.toByteData(format: ui.ImageByteFormat.png);
      final file = File(
        '$peekOutDir/$folder/${frame.toString().padLeft(3, '0')}.png',
      );
      file.parent.createSync(recursive: true);
      await file.writeAsBytes(bytes!.buffer.asUint8List());
    } finally {
      image.dispose();
    }
  });
}

void main() {
  for (final brightness in Brightness.values) {
    testWidgets('три в ряд — ${brightness.name}', (tester) async {
      tester.view.physicalSize = peekPhysicalSize;
      tester.view.devicePixelRatio = peekDevicePixelRatio;
      addTearDown(tester.view.reset);
      final cross = brightness == Brightness.dark;
      await tester.pumpWidget(
        MaterialApp(
          debugShowCheckedModeBanner: false,
          theme: wordarcadeTheme(
            brightness: brightness,
            platform: TargetPlatform.android,
          ),
          home: RepaintBoundary(
            key: _screen,
            child: MatchThreeGame(
              session: FakeReviewSession([_item, _item]),
              onPlayAgain: () {},
              onExit: () {},
              course: StudyCourse.spanishFromRussian,
              level: CefrLevel.a1,
              seed: cross ? 3 : 10,
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();
      await peek(tester, 'match_three_${brightness.name}_ready');
      final from = tester.getCenter(
        find.byKey(MatchThreeKeys.cell(cross ? 15 : 9)),
      );
      final to = tester.getCenter(
        find.byKey(MatchThreeKeys.cell(cross ? 16 : 15)),
      );
      final folder = 'match_three_motion/${brightness.name}';
      var frame = 0;
      Future<void> capture() async {
        await tester.pump(const Duration(milliseconds: 33));
        await _fieldFrame(tester, folder, frame++);
      }

      final finger = await tester.startGesture(from);
      for (var i = 1; i <= 6; i++) {
        await finger.moveTo(Offset.lerp(from, to, i / 6)!);
        await capture();
      }
      await finger.up();
      for (var i = 0; i < 25; i++) {
        await capture();
      }
      await tester.pumpAndSettle();
      await peek(tester, 'match_three_${brightness.name}_bonus');
      final correct = find.text(_item.word.translation);
      await tester.ensureVisible(correct);
      await tester.tap(correct);
      await tester.pump();
      for (var i = 0; i < 58; i++) {
        await capture();
      }
    });
  }
}
