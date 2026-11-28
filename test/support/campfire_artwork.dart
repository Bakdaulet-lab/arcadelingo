import 'package:arcadelingo/ui/campfire_stage.dart';
import 'package:arcadelingo/ui/valley_campfire_painter.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

/// Wait for exactly the image streams the visible badge and landscape use.
/// Image decoding runs on a real thread, independent of the test's fake clock.
Future<void> warmCampfire(
  WidgetTester tester,
  BuildContext context,
  int days,
  Brightness brightness,
) async {
  final stage = CampfireStage.forDays(days);
  if (stage == null) return;
  await tester.runAsync(() async {
    await Future.wait([
      for (final landscape in [false, true])
        for (final image in ValleyArtwork.assetsFor(
          stage,
          brightness: brightness,
          landscape: landscape,
        ))
          precacheImage(
            image,
            context,
            onError: (error, stack) {
              Error.throwWithStackTrace(error, stack ?? StackTrace.current);
            },
          ),
    ]);
  });
}
