import 'dart:ui' as ui;

import 'package:arcadelingo/domain/kitchen/kitchen_shift.dart';
import 'package:arcadelingo/features/games/order_kitchen/kitchen_counter_scene.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  for (final brightness in Brightness.values) {
    testWidgets(
      '${brightness.name}: milk blends between taps and reduced motion shows the final cup',
      (tester) async {
        const scene = Key('counter');
        const blackCoffee = {KitchenIngredient.coffee};
        const whiteCoffee = {...blackCoffee, KitchenIngredient.milk};

        Future<void> show(
          Set<KitchenIngredient> ingredients, {
          bool reduce = false,
          bool served = false,
        }) => tester.pumpWidget(
          MediaQuery(
            data: MediaQueryData(disableAnimations: reduce),
            child: Theme(
              data: ThemeData(brightness: brightness),
              child: Directionality(
                textDirection: TextDirection.ltr,
                child: Center(
                  child: RepaintBoundary(
                    key: scene,
                    child: SizedBox(
                      width: 240,
                      height: 120,
                      child: KitchenCounterScene(
                        selected: ingredients,
                        guestIndex: 1,
                        served: served,
                        mistake: false,
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ),
        );

        Future<Uint8List> pixels() async {
          final boundary = tester.renderObject<RenderRepaintBoundary>(
            find.byKey(scene),
          );
          final bytes = await tester.runAsync(() async {
            final image = await boundary.toImage();
            try {
              return (await image.toByteData(
                format: ui.ImageByteFormat.rawRgba,
              ))!.buffer.asUint8List();
            } finally {
              image.dispose();
            }
          });
          return bytes!;
        }

        await show(blackCoffee);
        await tester.pumpAndSettle();
        final black = await pixels();
        await show(whiteCoffee);
        await tester.pump(const Duration(milliseconds: 80));
        final blending = await pixels();
        await tester.pumpAndSettle();
        final white = await pixels();
        // Sample the liquid itself. Steam and a blinking guest also change
        // between frames, even when the milk is made to switch instantly.
        List<int> drinkColor(Uint8List frame) {
          const offset = (90 * 240 + 146) * 4;
          return frame.sublist(offset, offset + 3);
        }

        expect(drinkColor(blending), isNot(drinkColor(black)));
        expect(drinkColor(blending), isNot(drinkColor(white)));
        expect(drinkColor(black), isNot(drinkColor(white)));

        await show(blackCoffee, reduce: true);
        expect(listEquals(await pixels(), black), isTrue);
        await show(whiteCoffee, reduce: true);
        expect(listEquals(await pixels(), white), isTrue);
        await show(whiteCoffee, reduce: true, served: true);
        final served = await pixels();
        expect(listEquals(served, white), isFalse);
        await tester.pump(const Duration(milliseconds: 80));
        expect(listEquals(await pixels(), served), isTrue);
      },
    );
  }
}
