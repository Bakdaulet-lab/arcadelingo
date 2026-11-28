import 'dart:math';

import '../review/review_contract.dart';
import '../review/study_course.dart';

enum KitchenIngredient {
  coffee('Coffee', 'Café', 'Кофе', 'Кофе', 'Kaffee'),
  tea('Tea', 'Té', 'Чай', 'Шай', 'Tee'),
  milk('Milk', 'Leche', 'Молоко', 'Сүт', 'Milch'),
  sugar('Sugar', 'Azúcar', 'Сахар', 'Қант', 'Zucker'),
  lemon('Lemon', 'Limón', 'Лимон', 'Лимон', 'Zitrone'),
  honey('Honey', 'Miel', 'Мёд', 'Бал', 'Honig');

  const KitchenIngredient(
    this._english,
    this._spanish,
    this._russian,
    this._kazakh,
    this._german,
  );
  final String _english;
  final String _spanish;
  final String _russian;
  final String _kazakh;
  final String _german;

  String label(String language) => switch (language) {
    'es' => _spanish,
    'ru' => _russian,
    'kk' => _kazakh,
    'de' => _german,
    _ => _english,
  };
}

class KitchenOrder {
  const KitchenOrder._(
    this.ingredients,
    this._english,
    this._spanish,
    this._russian,
    this._kazakh,
    this._german,
  );

  final Set<KitchenIngredient> ingredients;
  final String _english;
  final String _spanish;
  final String _russian;
  final String _kazakh;
  final String _german;

  String phrase(String language) => switch (language) {
    'es' => _spanish,
    'ru' => _russian,
    'kk' => _kazakh,
    'de' => _german,
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
    'Шай беріңізші.',
    'Einen Tee, bitte.',
  ),
  KitchenOrder._(
    {KitchenIngredient.coffee},
    'A coffee, please.',
    'Un café, por favor.',
    'Кофе, пожалуйста.',
    'Кофе беріңізші.',
    'Einen Kaffee, bitte.',
  ),
];

const _withOneExtra = [
  KitchenOrder._(
    {KitchenIngredient.tea, KitchenIngredient.honey},
    'Tea with honey, please.',
    'Un té con miel, por favor.',
    'Чай с мёдом, пожалуйста.',
    'Бал қосылған шай беріңізші.',
    'Einen Tee mit Honig, bitte.',
  ),
  KitchenOrder._(
    {KitchenIngredient.coffee, KitchenIngredient.sugar},
    'A coffee with sugar, please.',
    'Un café con azúcar, por favor.',
    'Кофе с сахаром, пожалуйста.',
    'Қант қосылған кофе беріңізші.',
    'Einen Kaffee mit Zucker, bitte.',
  ),
  KitchenOrder._(
    {KitchenIngredient.tea, KitchenIngredient.lemon},
    'I’d like a tea with lemon.',
    'Quiero un té con limón, por favor.',
    'Мне чай с лимоном, пожалуйста.',
    'Маған лимон қосылған шай беріңізші.',
    'Ich möchte einen Tee mit Zitrone.',
  ),
  KitchenOrder._(
    {KitchenIngredient.tea, KitchenIngredient.milk},
    'A tea with milk, please.',
    'Un té con leche, por favor.',
    'Чай с молоком, пожалуйста.',
    'Сүт қосылған шай беріңізші.',
    'Einen Tee mit Milch, bitte.',
  ),
  KitchenOrder._(
    {KitchenIngredient.coffee, KitchenIngredient.milk},
    'I’d like a coffee with milk.',
    'Quiero un café con leche, por favor.',
    'Мне кофе с молоком, пожалуйста.',
    'Маған сүт қосылған кофе беріңізші.',
    'Ich möchte einen Kaffee mit Milch.',
  ),
  KitchenOrder._(
    {KitchenIngredient.tea, KitchenIngredient.sugar},
    'A tea with sugar, please.',
    'Un té con azúcar, por favor.',
    'Чай с сахаром, пожалуйста.',
    'Қант қосылған шай беріңізші.',
    'Einen Tee mit Zucker, bitte.',
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
      'Сүт пен қант қосылған кофе беріңізші.',
      'Kaffee mit Milch und Zucker, bitte.',
    ),
    KitchenOrder._(
      {KitchenIngredient.coffee, KitchenIngredient.milk},
      'Coffee with milk, no sugar, please.',
      'Un café con leche, sin azúcar, por favor.',
      'Кофе с молоком, без сахара, пожалуйста.',
      'Сүт қосылған, бірақ қантсыз кофе беріңізші.',
      'Kaffee mit Milch, aber ohne Zucker, bitte.',
    ),
  ),
  (
    KitchenOrder._(
      {KitchenIngredient.tea, KitchenIngredient.lemon, KitchenIngredient.honey},
      'Tea with lemon and honey, please.',
      'Un té con limón y miel, por favor.',
      'Чай с лимоном и мёдом, пожалуйста.',
      'Лимон мен бал қосылған шай беріңізші.',
      'Tee mit Zitrone und Honig, bitte.',
    ),
    KitchenOrder._(
      {KitchenIngredient.tea, KitchenIngredient.lemon},
      'Tea with lemon, no honey, please.',
      'Un té con limón, sin miel, por favor.',
      'Чай с лимоном, без мёда, пожалуйста.',
      'Лимон қосылған, бірақ балсыз шай беріңізші.',
      'Tee mit Zitrone, aber ohne Honig, bitte.',
    ),
  ),
  (
    KitchenOrder._(
      {KitchenIngredient.tea, KitchenIngredient.milk, KitchenIngredient.sugar},
      'Tea with milk and sugar, please.',
      'Un té con leche y azúcar, por favor.',
      'Чай с молоком и сахаром, пожалуйста.',
      'Сүт пен қант қосылған шай беріңізші.',
      'Tee mit Milch und Zucker, bitte.',
    ),
    KitchenOrder._(
      {KitchenIngredient.tea, KitchenIngredient.sugar},
      'Tea with sugar, but without milk, please.',
      'Un té con azúcar, pero sin leche, por favor.',
      'Чай с сахаром, но без молока, пожалуйста.',
      'Қант қосылған, бірақ сүтсіз шай беріңізші.',
      'Tee mit Zucker, aber ohne Milch, bitte.',
    ),
  ),
  (
    KitchenOrder._(
      {KitchenIngredient.tea, KitchenIngredient.lemon, KitchenIngredient.sugar},
      'Tea with lemon and sugar, please.',
      'Un té con limón y azúcar, por favor.',
      'Чай с лимоном и сахаром, пожалуйста.',
      'Лимон мен қант қосылған шай беріңізші.',
      'Tee mit Zitrone und Zucker, bitte.',
    ),
    KitchenOrder._(
      {KitchenIngredient.tea, KitchenIngredient.lemon},
      'Tea with lemon, but without sugar, please.',
      'Un té con limón, pero sin azúcar, por favor.',
      'Чай с лимоном, но без сахара, пожалуйста.',
      'Лимон қосылған, бірақ қантсыз шай беріңізші.',
      'Tee mit Zitrone, aber ohne Zucker, bitte.',
    ),
  ),
];

bool kitchenAvailableFor(StudyCourse course, CefrLevel level) {
  if (level != CefrLevel.a1 ||
      course.id != '${course.translationLanguage}-${course.studyLanguage}') {
    return false;
  }
  return const {
        'ru-en',
        'ru-es',
        'es-en',
        'en-es',
        'kk-ru',
        'kk-en',
        'kk-es',
      }.contains(course.id) ||
      StudyCourse.germanCourses.any((entry) => entry.id == course.id);
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
