import 'package:arcadelingo/app/app.dart';
import 'package:arcadelingo/app/app_ports.dart';
import 'package:arcadelingo/app/app_views.dart';
import 'package:arcadelingo/app/progress_view.dart';
import 'package:arcadelingo/domain/core/result.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import '../support/in_memory_stores.dart';
import '../support/review_items.dart';

Future<void> _openProgress(WidgetTester tester) async {
  await tester.pumpWidget(
    WordarcadeApp(
      ports: AppPorts(
        cards: InMemoryCardStore(),
        streaks: InMemoryStreakStore(),
      ),
      seed: Ok(wordItems(1)),
    ),
  );
  await tester.pumpAndSettle();
  final progress = find.byKey(AppKeys.progress);
  await tester.ensureVisible(progress);
  await tester.tap(progress);
  await tester.pump();
}

void main() {
  testWidgets('pages enter and return with a small vertical movement', (
    tester,
  ) async {
    await _openProgress(tester);
    await tester.pump(const Duration(milliseconds: 72));
    final page = find.byType(ProgressScreen);
    final entering = tester.getTopLeft(page);
    expect(entering.dx, closeTo(0, 0.01));
    expect(entering.dy, inExclusiveRange(0, 24));
    expect(
      tester
          .widgetList<FadeTransition>(
            find.ancestor(of: page, matching: find.byType(FadeTransition)),
          )
          .any((fade) => fade.opacity.value > 0 && fade.opacity.value < 1),
      isTrue,
    );
    await tester.pump(const Duration(milliseconds: 180));
    expect(tester.getTopLeft(page), Offset.zero);

    await tester.binding.handlePopRoute();
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 72));
    final leaving = tester.getTopLeft(page);
    expect(leaving.dx, closeTo(0, 0.01));
    expect(leaving.dy, inExclusiveRange(0, 24));
    await tester.pump(const Duration(milliseconds: 140));
    await tester.pump();
    expect(page, findsNothing);
    expect(find.byType(PlayView), findsOneWidget);
  });

  testWidgets(
    'reduced motion opens and closes pages without elapsed time',
    (tester) async {
      tester.platformDispatcher.accessibilityFeaturesTestValue =
          const FakeAccessibilityFeatures(disableAnimations: true);
      addTearDown(
        tester.platformDispatcher.clearAccessibilityFeaturesTestValue,
      );
      await _openProgress(tester);
      await tester.pump();
      final page = find.byType(ProgressScreen);
      expect(tester.getTopLeft(page), Offset.zero);
      expect(
        ModalRoute.of(tester.element(page))!.animation!.isCompleted,
        isTrue,
      );

      await tester.binding.handlePopRoute();
      await tester.pump();
      await tester.pump();
      expect(page, findsNothing);
      expect(find.byType(PlayView), findsOneWidget);
    },
    variant: const TargetPlatformVariant({
      TargetPlatform.android,
      TargetPlatform.iOS,
    }),
  );

  testWidgets(
    'iOS navigation still follows an edge swipe back',
    (tester) async {
      await _openProgress(tester);
      await tester.pumpAndSettle();
      final page = find.byType(ProgressScreen);
      final width = tester.getSize(page).width;
      final swipe = await tester.startGesture(const Offset(2, 220));
      await swipe.moveBy(const Offset(28, 0));
      await swipe.moveBy(Offset(width * 0.65, 0));
      await tester.pump();
      expect(tester.getTopLeft(page).dx, greaterThan(width / 2));
      await swipe.up();
      await tester.pumpAndSettle();
      expect(page, findsNothing);
      expect(find.byType(PlayView), findsOneWidget);
    },
    variant: TargetPlatformVariant.only(TargetPlatform.iOS),
  );
}
