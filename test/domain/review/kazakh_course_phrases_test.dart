import 'package:arcadelingo/domain/candy_delivery/candy_orders.dart';
import 'package:arcadelingo/domain/kitchen/kitchen_shift.dart';
import 'package:arcadelingo/domain/review/review_contract.dart';
import 'package:arcadelingo/domain/review/study_course.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('kitchen shows a Kazakh explanation after a correctly served order', () {
    for (final course in StudyCourse.kazakhCourses) {
      final orders = kitchenOrdersFor(
        course: course,
        level: CefrLevel.a1,
        seed: 5,
      );
      expect(orders, hasLength(5));
      expect(kitchenAvailableFor(course, CefrLevel.a2), isFalse);
      for (final order in orders) {
        expect(order.phrase('kk'), isNot(order.phrase(course.studyLanguage)));
        expect(order.phrase('kk'), contains('беріңізші'));
      }
    }
    expect(KitchenIngredient.milk.label('kk'), 'Сүт');
  });

  test(
    'candy clues use the requested target language and Kazakh translation',
    () {
      for (final course in StudyCourse.kazakhCourses) {
        for (final level in CefrLevel.values.take(5)) {
          final orders = candyOrdersFor(course: course, level: level, seed: 12);
          expect(orders.map((order) => order.target).toSet(), hasLength(3));
          for (final order in orders) {
            expect(order.level, level);
            expect(order.courseId, course.id);
            expect(order.translation, matches(RegExp(r'[әғқңөұүһі]')));
            expect(order.translation, isNot(order.phrase));
          }
        }
        expect(candyAvailableFor(course, CefrLevel.c2), isFalse);
      }
    },
  );
}
