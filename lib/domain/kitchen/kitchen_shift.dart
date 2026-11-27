import 'dart:math';

import '../review/review_contract.dart';
import '../review/study_course.dart';

enum KitchenIngredient {
  coffee('Coffee', 'Café', 'Кофе'),
  tea('Tea', 'Té', 'Чай'),
  milk('Milk', 'Leche', 'Молоко'),
  sugar('Sugar', 'Azúcar', 'Сахар'),
  lemon('Lemon', 'Limón', 'Лимон'),
  honey('Honey', 'Miel', 'Мёд');

  const KitchenIngredient(this._english, this._spanish, this._russian);
  final String _english;
  final String _spanish;
  final String _russian;

  String label(String language) => switch (language) {
    'es' => _spanish,
    'ru' => _russian,
    _ => _english,
  };
}

class KitchenOrder {
  const KitchenOrder._(
    this.ingredients,
    this._english,
    this._spanish,
    this._russian,
  );

  final Set<KitchenIngredient> ingredients;
  final String _english;
  final String _spanish;
  final String _russian;

  String phrase(String language) => switch (language) {
    'es' => _spanish,
    'ru' => _russian,
    _ => _english,
  };

  bool matches(Set<KitchenIngredient> cup) =>
      cup.length == ingredients.length && cup.containsAll(ingredients);
}

const _plain = [
  KitchenOrder._(
    {KitchenIngredient.tea},
    'A tea, please.',
    'Un té, por favor.',
    'Чай, пожалуйста.',
  ),
  KitchenOrder._(
    {KitchenIngredient.coffee},
    'A coffee, please.',
    'Un café, por favor.',
    'Кофе, пожалуйста.',
  ),
];

const _withOneExtra = [
  KitchenOrder._(
    {KitchenIngredient.tea, KitchenIngredient.honey},
    'Tea with honey, please.',
    'Un té con miel, por favor.',
    'Чай с мёдом, пожалуйста.',
  ),
  KitchenOrder._(
    {KitchenIngredient.coffee, KitchenIngredient.sugar},
    'A coffee with sugar, please.',
    'Un café con azúcar, por favor.',
    'Кофе с сахаром, пожалуйста.',
  ),
  KitchenOrder._(
    {KitchenIngredient.tea, KitchenIngredient.lemon},
    'I’d like a tea with lemon.',
    'Quiero un té con limón, por favor.',
    'Мне чай с лимоном, пожалуйста.',
  ),
  KitchenOrder._(
    {KitchenIngredient.tea, KitchenIngredient.milk},
    'A tea with milk, please.',
    'Un té con leche, por favor.',
    'Чай с молоком, пожалуйста.',
  ),
  KitchenOrder._(
    {KitchenIngredient.coffee, KitchenIngredient.milk},
    'I’d like a coffee with milk.',
    'Quiero un café con leche, por favor.',
    'Мне кофе с молоком, пожалуйста.',
  ),
  KitchenOrder._(
    {KitchenIngredient.tea, KitchenIngredient.sugar},
    'A tea with sugar, please.',
    'Un té con azúcar, por favor.',
    'Чай с сахаром, пожалуйста.',
  ),
];

// A contrast pair differs by exactly one ingredient. The guest names that
// ingredient in both orders, so recognising just the nouns is insufficient.
const _contrasts = [
  (
    KitchenOrder._(
      {
        KitchenIngredient.coffee,
        KitchenIngredient.milk,
        KitchenIngredient.sugar,
      },
      'Coffee with milk and sugar, please.',
      'Un café con leche y azúcar, por favor.',
      'Кофе с молоком и сахаром, пожалуйста.',
    ),
    KitchenOrder._(
      {KitchenIngredient.coffee, KitchenIngredient.milk},
      'Coffee with milk, no sugar, please.',
      'Un café con leche, sin azúcar, por favor.',
      'Кофе с молоком, без сахара, пожалуйста.',
    ),
  ),
  (
    KitchenOrder._(
      {KitchenIngredient.tea, KitchenIngredient.lemon, KitchenIngredient.honey},
      'Tea with lemon and honey, please.',
      'Un té con limón y miel, por favor.',
      'Чай с лимоном и мёдом, пожалуйста.',
    ),
    KitchenOrder._(
      {KitchenIngredient.tea, KitchenIngredient.lemon},
      'Tea with lemon, no honey, please.',
      'Un té con limón, sin miel, por favor.',
      'Чай с лимоном, без мёда, пожалуйста.',
    ),
  ),
  (
    KitchenOrder._(
      {KitchenIngredient.tea, KitchenIngredient.milk, KitchenIngredient.sugar},
      'Tea with milk and sugar, please.',
      'Un té con leche y azúcar, por favor.',
      'Чай с молоком и сахаром, пожалуйста.',
    ),
    KitchenOrder._(
      {KitchenIngredient.tea, KitchenIngredient.sugar},
      'Tea with sugar, but without milk, please.',
      'Un té con azúcar, pero sin leche, por favor.',
      'Чай с сахаром, но без молока, пожалуйста.',
    ),
  ),
  (
    KitchenOrder._(
      {KitchenIngredient.tea, KitchenIngredient.lemon, KitchenIngredient.sugar},
      'Tea with lemon and sugar, please.',
      'Un té con limón y azúcar, por favor.',
      'Чай с лимоном и сахаром, пожалуйста.',
    ),
    KitchenOrder._(
      {KitchenIngredient.tea, KitchenIngredient.lemon},
      'Tea with lemon, but without sugar, please.',
      'Un té con limón, pero sin azúcar, por favor.',
      'Чай с лимоном, но без сахара, пожалуйста.',
    ),
  ),
];

bool kitchenAvailableFor(StudyCourse course, CefrLevel level) {
  if (level != CefrLevel.a1 ||
      course.id != '${course.translationLanguage}-${course.studyLanguage}') {
    return false;
  }
  return const {'ru-en', 'ru-es', 'es-en', 'en-es'}.contains(course.id);
}

List<KitchenOrder> kitchenOrdersFor({
  required StudyCourse course,
  required CefrLevel level,
  required int seed,
}) {
  if (!kitchenAvailableFor(course, level)) return const [];
  final random = Random(seed);
  final plain = _plain[random.nextInt(_plain.length)];
  final (withExtra, withoutExtra) =
      _contrasts[random.nextInt(_contrasts.length)];
  final middle =
      _withOneExtra
          .where((order) => !withoutExtra.matches(order.ingredients))
          .toList()
        ..shuffle(random);
  final contrast = [withExtra, withoutExtra]..shuffle(random);
  return List.unmodifiable([plain, ...middle.take(2), ...contrast]);
}
