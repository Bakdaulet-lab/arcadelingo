import 'package:arcadelingo/domain/candy_delivery/candy_orders.dart';
import 'package:arcadelingo/domain/kitchen/kitchen_shift.dart';
import 'package:arcadelingo/domain/review/review_contract.dart';
import 'package:arcadelingo/domain/review/study_course.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test(
    'German kitchen orders keep the A1 recipe and the omitted ingredient',
    () {
      expect(KitchenIngredient.values.map((item) => item.label('de')), [
        'Kaffee',
        'Tee',
        'Milch',
        'Zucker',
        'Zitrone',
        'Honig',
      ]);

      final phrases = <String>{};
      const omittedIngredients = {
        'Milch': KitchenIngredient.milk,
        'Zucker': KitchenIngredient.sugar,
        'Honig': KitchenIngredient.honey,
      };
      final seenOmissions = <KitchenIngredient>{};

      for (final course in StudyCourse.germanCourses) {
        for (final level in CefrLevel.values.skip(1)) {
          expect(
            kitchenOrdersFor(course: course, level: level, seed: 0),
            isEmpty,
          );
        }
        for (var seed = 0; seed < 64; seed++) {
          final orders = kitchenOrdersFor(
            course: course,
            level: CefrLevel.a1,
            seed: seed,
          );
          expect(orders, hasLength(5));
          for (final order in orders) {
            final phrase = order.phrase('de');
            phrases.add(phrase);
            expect(phrase, isNot(order.phrase(course.translationLanguage)));
            for (final ingredient in order.ingredients) {
              expect(phrase, contains(ingredient.label('de')));
            }
          }

          final contrast = orders
              .skip(3)
              .singleWhere((order) => order.phrase('de').contains('ohne '));
          final without =
              contrast.phrase('de').split('ohne ').last.split(',').first;
          final excluded = omittedIngredients[without];
          expect(excluded, isNotNull);
          seenOmissions.add(excluded!);
          expect(contrast.ingredients, isNot(contains(excluded)));
          final withExtra = orders
              .skip(3)
              .singleWhere((order) => order != contrast);
          expect(withExtra.ingredients, {...contrast.ingredients, excluded});
        }
      }

      expect(phrases, hasLength(16));
      expect(seenOmissions, omittedIngredients.values.toSet());
    },
  );

  test(
    'German candy clues keep the selected level, translation and rabbit',
    () {
      final germanPhrases = <String>{};
      for (final level in CefrLevel.values.take(5)) {
        final germanByRabbit = {for (var i = 0; i < 3; i++) i: <String>{}};
        for (var seed = 0; seed < 64; seed++) {
          final english = candyOrdersFor(
            course: StudyCourse.englishFromRussian,
            level: level,
            seed: seed,
          );
          final spanish = candyOrdersFor(
            course: StudyCourse.spanishFromEnglish,
            level: level,
            seed: seed,
          );
          final kazakh = candyOrdersFor(
            course: StudyCourse.englishFromKazakh,
            level: level,
            seed: seed,
          );
          List<CandyOrder>? firstDirection;
          for (final course in StudyCourse.germanCourses) {
            final actual = candyOrdersFor(
              course: course,
              level: level,
              seed: seed,
            );
            firstDirection ??= actual;
            expect(actual, hasLength(3));
            for (final (i, order) in actual.indexed) {
              expect(order.courseId, course.id);
              expect(order.level, level);
              expect(order.target, english[i].target);
              expect(order.rabbits, english[i].rabbits);
              expect(order.phrase, firstDirection[i].phrase);
              final translation = switch (course.translationLanguage) {
                'ru' => english[i].translation,
                'en' => english[i].phrase,
                'es' => spanish[i].phrase,
                _ => kazakh[i].translation,
              };
              expect(order.translation, translation);
              expect(order.phrase, isNot(order.translation));
              germanByRabbit[order.target]!.add(order.phrase);
            }
          }
        }
        for (final phrases in germanByRabbit.values) {
          expect(phrases, hasLength(3));
          germanPhrases.addAll(phrases);
        }
      }
      expect(germanPhrases, hasLength(45));
      for (final course in StudyCourse.germanCourses) {
        expect(
          candyOrdersFor(course: course, level: CefrLevel.c2, seed: 0),
          isEmpty,
        );
      }
    },
  );
}
