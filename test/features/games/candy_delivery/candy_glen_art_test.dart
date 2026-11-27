import 'dart:ui' as ui;

import 'package:arcadelingo/features/games/candy_delivery/candy_glen_art.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  for (final day in [false, true]) {
    testWidgets(
      'glen art in daylight=$day follows the lane order and celebrates only the recipient',
      (tester) async {
        const frame = Key('glen.art');
        const initial = [0, 1, 2];
        const shuffled = [1, 0, 2];
        Future<void> show(List<int> rabbits, int? happyLane) async {
          await tester.pumpWidget(
            Directionality(
              textDirection: TextDirection.ltr,
              child: Center(
                child: RepaintBoundary(
                  key: frame,
                  child: SizedBox(
                    width: 360,
                    height: 292,
                    child: CandyGlenArt(
                      day: day,
                      rabbits: rabbits,
                      happyLane: happyLane,
                    ),
                  ),
                ),
              ),
            ),
          );
        }

        await show(initial, null);
        final context = tester.element(find.byType(CandyGlenArt));
        await tester.runAsync(
          () => precacheImage(CandyGlenArt.imageFor(day), context),
        );
        await tester.pump();

        Future<Uint8List> pixels() async {
          final boundary = tester.renderObject<RenderRepaintBoundary>(
            find.byKey(frame),
          );
          return (await tester.runAsync(() async {
            final image = await boundary.toImage();
            try {
              return (await image.toByteData(
                format: ui.ImageByteFormat.rawRgba,
              ))!.buffer.asUint8List();
            } finally {
              image.dispose();
            }
          }))!;
        }

        List<int> lane(Uint8List image, int x) => [
          for (var row = 186; row < 274; row++)
            ...image.sublist(
              (row * 360 + x - 44) * 4,
              (row * 360 + x + 44) * 4,
            ),
        ];
        final before = await pixels();
        final sky = (8 * 360 + 180) * 4;
        expect(before[sky + 3], 255);
        expect(before[sky], day ? greaterThan(200) : lessThan(100));
        await show(shuffled, null);
        final moved = await pixels();
        expect(listEquals(lane(before, 64), lane(moved, 64)), isFalse);
        expect(listEquals(lane(before, 180), lane(moved, 180)), isFalse);
        expect(listEquals(lane(before, 296), lane(moved, 296)), isTrue);
        await show(shuffled, 0);
        final delivered = await pixels();
        expect(listEquals(lane(moved, 64), lane(delivered, 64)), isFalse);
        expect(listEquals(lane(moved, 180), lane(delivered, 180)), isTrue);
        expect(listEquals(lane(moved, 296), lane(delivered, 296)), isTrue);
      },
    );
  }
}
