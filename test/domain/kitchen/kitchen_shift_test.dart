import 'package:arcadelingo/domain/kitchen/kitchen_shift.dart';
import 'package:arcadelingo/domain/review/review_contract.dart';
import 'package:arcadelingo/domain/review/study_course.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  const courses = [
    StudyCourse.englishFromRussian,
    StudyCourse.spanishFromRussian,
    StudyCourse.englishFromSpanish,
    StudyCourse.spanishFromEnglish,
  ];
  List<KitchenOrder> shift(
    int seed, [
    StudyCourse course = StudyCourse.spanishFromRussian,
  ]) => kitchenOrdersFor(course: course, level: CefrLevel.a1, seed: seed);

  test('offers five distinct A1 orders in all four course directions', () {
    for (final course in courses) {
      for (var seed = 0; seed < 40; seed++) {
        final orders = shift(seed, course);
        expect(orders, hasLength(5));
        for (final language in [
          course.studyLanguage,
          course.translationLanguage,
        ]) {
          final phrases = orders.map((order) => order.phrase(language));
          expect(phrases, everyElement(isNotEmpty));
          expect(phrases.toSet(), hasLength(5));
        }
        final recipes = orders.map(
          (order) => KitchenIngredient.values
              .where(order.ingredients.contains)
              .join(','),
        );
        expect(recipes.toSet(), hasLength(5));
        expect(orders.first.ingredients, hasLength(1));
        expect(
          orders.first.ingredients.single,
          isIn([KitchenIngredient.coffee, KitchenIngredient.tea]),
        );
        final recipesWithOmission = orders.where(
          (order) => order.phrase('es').toLowerCase().contains('sin '),
        );
        expect(recipesWithOmission, isNotEmpty);
      }
    }
  });

  test('excludes other levels and unknown or mismatched course directions', () {
    for (final level in CefrLevel.values.where(
      (level) => level != CefrLevel.a1,
    )) {
      expect(kitchenAvailableFor(courses.first, level), isFalse);
      expect(
        kitchenOrdersFor(course: courses.first, level: level, seed: 1),
        isEmpty,
      );
    }
    for (final course in [
      const StudyCourse(
        id: 'ru-pt',
        studyLanguage: 'pt',
        translationLanguage: 'ru',
      ),
      const StudyCourse(
        id: 'ru-es',
        studyLanguage: 'en',
        translationLanguage: 'ru',
      ),
      const StudyCourse(
        id: 'de-es',
        studyLanguage: 'es',
        translationLanguage: 'de',
      ),
    ]) {
      expect(kitchenAvailableFor(course, CefrLevel.a1), isFalse);
      expect(shift(1, course), isEmpty);
    }
  });

  test('replays the same seed and varies the menu between shifts', () {
    List<String> phrases(int seed) =>
        shift(seed).map((order) => order.phrase('es')).toList();
    expect(phrases(14), phrases(14));
    expect(
      List.generate(24, (index) => phrases(index).join('|')).toSet().length,
      greaterThan(3),
    );
  });

  test(
    'a requested omission and an extra or missing ingredient change the result',
    () {
      final orders = List.generate(
        40,
        (seed) => shift(seed),
      ).expand((menu) => menu);
      final coffee = orders.firstWhere((order) {
        final phrase = order.phrase('es').toLowerCase();
        return phrase.contains('café con leche') &&
            phrase.contains('sin azúcar');
      });
      expect(coffee.phrase('en').toLowerCase(), contains('milk'));
      expect(coffee.phrase('en').toLowerCase(), contains('sugar'));
      expect(coffee.phrase('ru').toLowerCase(), contains('без сахара'));
      expect(
        coffee.matches({KitchenIngredient.milk, KitchenIngredient.coffee}),
        isTrue,
      );
      for (final wrong in [
        <KitchenIngredient>{},
        {KitchenIngredient.coffee},
        {KitchenIngredient.tea, KitchenIngredient.milk},
        {...coffee.ingredients, KitchenIngredient.sugar},
      ]) {
        expect(coffee.matches(wrong), isFalse);
      }
      expect(() => coffee.ingredients.clear(), throwsUnsupportedError);
    },
  );

  test('ingredients have distinct labels in every supported language', () {
    for (final language in ['en', 'es', 'ru']) {
      final labels = KitchenIngredient.values.map(
        (item) => item.label(language),
      );
      expect(labels, everyElement(isNotEmpty));
      expect(labels.toSet(), hasLength(6));
    }
    expect(KitchenIngredient.sugar.label('es').toLowerCase(), 'azúcar');
    expect(KitchenIngredient.honey.label('ru').toLowerCase(), 'мёд');
    expect(KitchenIngredient.tea.label('en').toLowerCase(), 'tea');
  });
}
