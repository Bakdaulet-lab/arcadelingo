import 'dart:math';

import '../review/review_contract.dart';
import '../review/study_course.dart';

enum KitchenIngredient {
  coffee(
    'Coffee',
    'Café',
    'Кофе',
    'Кофе',
    'Kaffee',
    'Café',
    '咖啡',
    'قهوة',
    '커피',
    'コーヒー',
    'Kahve',
  ),
  tea('Tea', 'Té', 'Чай', 'Шай', 'Tee', 'Thé', '茶', 'شاي', '차', '紅茶', 'Çay'),
  milk(
    'Milk',
    'Leche',
    'Молоко',
    'Сүт',
    'Milch',
    'Lait',
    '牛奶',
    'حليب',
    '우유',
    'ミルク',
    'Süt',
  ),
  sugar(
    'Sugar',
    'Azúcar',
    'Сахар',
    'Қант',
    'Zucker',
    'Sucre',
    '糖',
    'سكر',
    '설탕',
    '砂糖',
    'Şeker',
  ),
  lemon(
    'Lemon',
    'Limón',
    'Лимон',
    'Лимон',
    'Zitrone',
    'Citron',
    '柠檬',
    'ليمون',
    '레몬',
    'レモン',
    'Limon',
  ),
  honey(
    'Honey',
    'Miel',
    'Мёд',
    'Бал',
    'Honig',
    'Miel',
    '蜂蜜',
    'عسل',
    '꿀',
    'はちみつ',
    'Bal',
  );

  const KitchenIngredient(
    this._english,
    this._spanish,
    this._russian,
    this._kazakh,
    this._german,
    this._french,
    this._chinese,
    this._arabic,
    this._korean,
    this._japanese,
    this._turkish,
  );
  final String _english;
  final String _spanish;
  final String _russian;
  final String _kazakh;
  final String _german;
  final String _french;
  final String _chinese;
  final String _arabic;
  final String _korean;
  final String _japanese;
  final String _turkish;

  String label(String language) => switch (language) {
    'es' => _spanish,
    'ru' => _russian,
    'kk' => _kazakh,
    'de' => _german,
    'fr' => _french,
    'zh' => _chinese,
    'ar' => _arabic,
    'ko' => _korean,
    'ja' => _japanese,
    'tr' => _turkish,
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
    this._french,
    this._chinese,
    this._arabic,
    this._korean,
    this._japanese,
    this._turkish,
  );

  final Set<KitchenIngredient> ingredients;
  final String _english;
  final String _spanish;
  final String _russian;
  final String _kazakh;
  final String _german;
  final String _french;
  final String _chinese;
  final String _arabic;
  final String _korean;
  final String _japanese;
  final String _turkish;

  String phrase(String language) => switch (language) {
    'es' => _spanish,
    'ru' => _russian,
    'kk' => _kazakh,
    'de' => _german,
    'fr' => _french,
    'zh' => _chinese,
    'ar' => _arabic,
    'ko' => _korean,
    'ja' => _japanese,
    'tr' => _turkish,
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
    'Un thé, s’il vous plaît.',
    '请给我一杯茶。',
    'شاي، من فضلك.',
    '차 한 잔 주세요.',
    '紅茶を一杯ください。',
    'Bir çay, lütfen.',
  ),
  KitchenOrder._(
    {KitchenIngredient.coffee},
    'A coffee, please.',
    'Un café, por favor.',
    'Кофе, пожалуйста.',
    'Кофе беріңізші.',
    'Einen Kaffee, bitte.',
    'Un café, s’il vous plaît.',
    '请给我一杯咖啡。',
    'قهوة، من فضلك.',
    '커피 한 잔 주세요.',
    'コーヒーを一杯ください。',
    'Bir kahve, lütfen.',
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
    'Un thé au miel, s’il vous plaît.',
    '请给我一杯加蜂蜜的茶。',
    'شاي بالعسل، من فضلك.',
    '꿀을 넣은 차 주세요.',
    'はちみつ入りの紅茶をください。',
    'Ballı çay, lütfen.',
  ),
  KitchenOrder._(
    {KitchenIngredient.coffee, KitchenIngredient.sugar},
    'A coffee with sugar, please.',
    'Un café con azúcar, por favor.',
    'Кофе с сахаром, пожалуйста.',
    'Қант қосылған кофе беріңізші.',
    'Einen Kaffee mit Zucker, bitte.',
    'Un café avec du sucre, s’il vous plaît.',
    '请给我一杯加糖的咖啡。',
    'قهوة مع السكر، من فضلك.',
    '설탕을 넣은 커피 주세요.',
    '砂糖入りのコーヒーをください。',
    'Şekerli bir kahve, lütfen.',
  ),
  KitchenOrder._(
    {KitchenIngredient.tea, KitchenIngredient.lemon},
    'I’d like a tea with lemon.',
    'Quiero un té con limón, por favor.',
    'Мне чай с лимоном, пожалуйста.',
    'Маған лимон қосылған шай беріңізші.',
    'Ich möchte einen Tee mit Zitrone.',
    'Je voudrais un thé au citron.',
    '我想要一杯柠檬茶。',
    'أريد شايًا بالليمون.',
    '레몬을 넣은 차를 주세요.',
    'レモンティーをお願いします。',
    'Limonlu çay istiyorum.',
  ),
  KitchenOrder._(
    {KitchenIngredient.tea, KitchenIngredient.milk},
    'A tea with milk, please.',
    'Un té con leche, por favor.',
    'Чай с молоком, пожалуйста.',
    'Сүт қосылған шай беріңізші.',
    'Einen Tee mit Milch, bitte.',
    'Un thé avec du lait, s’il vous plaît.',
    '请给我一杯加牛奶的茶。',
    'شاي مع الحليب، من فضلك.',
    '우유를 넣은 차 주세요.',
    'ミルクティーをください。',
    'Sütlü bir çay, lütfen.',
  ),
  KitchenOrder._(
    {KitchenIngredient.coffee, KitchenIngredient.milk},
    'I’d like a coffee with milk.',
    'Quiero un café con leche, por favor.',
    'Мне кофе с молоком, пожалуйста.',
    'Маған сүт қосылған кофе беріңізші.',
    'Ich möchte einen Kaffee mit Milch.',
    'Je voudrais un café au lait.',
    '我想要一杯加牛奶的咖啡。',
    'أريد قهوة بالحليب.',
    '우유를 넣은 커피를 주세요.',
    'ミルク入りのコーヒーをお願いします。',
    'Sütlü bir kahve istiyorum.',
  ),
  KitchenOrder._(
    {KitchenIngredient.tea, KitchenIngredient.sugar},
    'A tea with sugar, please.',
    'Un té con azúcar, por favor.',
    'Чай с сахаром, пожалуйста.',
    'Қант қосылған шай беріңізші.',
    'Einen Tee mit Zucker, bitte.',
    'Un thé avec du sucre, s’il vous plaît.',
    '请给我一杯加糖的茶。',
    'شاي مع السكر، من فضلك.',
    '설탕을 넣은 차 주세요.',
    '砂糖入りの紅茶をください。',
    'Şekerli bir çay, lütfen.',
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
      'Un café avec du lait et du sucre, s’il vous plaît.',
      '请给我一杯加牛奶和糖的咖啡。',
      'قهوة بالحليب والسكر، من فضلك.',
      '커피에 우유와 설탕을 넣어 주세요.',
      'コーヒーにミルクと砂糖を入れてください。',
      'Kahveye süt ve şeker koyun, lütfen.',
    ),
    KitchenOrder._(
      {KitchenIngredient.coffee, KitchenIngredient.milk},
      'Coffee with milk, no sugar, please.',
      'Un café con leche, sin azúcar, por favor.',
      'Кофе с молоком, без сахара, пожалуйста.',
      'Сүт қосылған, бірақ қантсыз кофе беріңізші.',
      'Kaffee mit Milch, aber ohne Zucker, bitte.',
      'Un café avec du lait, sans sucre, s’il vous plaît.',
      '请给我一杯加牛奶的咖啡，不加糖。',
      'قهوة بالحليب من دون سكر، من فضلك.',
      '커피에 우유는 넣고 설탕은 빼 주세요.',
      'コーヒーにミルクを入れてください。砂糖はいりません。',
      'Sütlü kahve, lütfen. Şeker olmasın.',
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
      'Un thé au citron et au miel, s’il vous plaît.',
      '请给我一杯加柠檬和蜂蜜的茶。',
      'شاي بالليمون والعسل، من فضلك.',
      '차에 레몬과 꿀을 넣어 주세요.',
      '紅茶にレモンとはちみつを入れてください。',
      'Çaya limon ve bal koyun, lütfen.',
    ),
    KitchenOrder._(
      {KitchenIngredient.tea, KitchenIngredient.lemon},
      'Tea with lemon, no honey, please.',
      'Un té con limón, sin miel, por favor.',
      'Чай с лимоном, без мёда, пожалуйста.',
      'Лимон қосылған, бірақ балсыз шай беріңізші.',
      'Tee mit Zitrone, aber ohne Honig, bitte.',
      'Un thé au citron, sans miel, s’il vous plaît.',
      '请给我一杯柠檬茶，不加蜂蜜。',
      'شاي بالليمون من دون عسل، من فضلك.',
      '차에 레몬은 넣고 꿀은 빼 주세요.',
      '紅茶にレモンを入れてください。はちみつはいりません。',
      'Limonlu çay, lütfen. Bal olmasın.',
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
      'Un thé avec du lait et du sucre, s’il vous plaît.',
      '请给我一杯加牛奶和糖的茶。',
      'شاي بالحليب والسكر، من فضلك.',
      '차에 우유와 설탕을 넣어 주세요.',
      '紅茶にミルクと砂糖を入れてください。',
      'Çaya süt ve şeker koyun, lütfen.',
    ),
    KitchenOrder._(
      {KitchenIngredient.tea, KitchenIngredient.sugar},
      'Tea with sugar, but without milk, please.',
      'Un té con azúcar, pero sin leche, por favor.',
      'Чай с сахаром, но без молока, пожалуйста.',
      'Қант қосылған, бірақ сүтсіз шай беріңізші.',
      'Tee mit Zucker, aber ohne Milch, bitte.',
      'Un thé avec du sucre, mais sans lait, s’il vous plaît.',
      '请给我一杯加糖的茶，但不要加牛奶。',
      'شاي بالسكر، لكن من دون حليب، من فضلك.',
      '차에 설탕은 넣고 우유는 빼 주세요.',
      '紅茶に砂糖を入れてください。ミルクはいりません。',
      'Şekerli çay, lütfen. Süt olmasın.',
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
      'Un thé au citron avec du sucre, s’il vous plaît.',
      '请给我一杯加糖的柠檬茶。',
      'شاي بالليمون والسكر، من فضلك.',
      '차에 레몬과 설탕을 넣어 주세요.',
      '紅茶にレモンと砂糖を入れてください。',
      'Çaya limon ve şeker koyun, lütfen.',
    ),
    KitchenOrder._(
      {KitchenIngredient.tea, KitchenIngredient.lemon},
      'Tea with lemon, but without sugar, please.',
      'Un té con limón, pero sin azúcar, por favor.',
      'Чай с лимоном, но без сахара, пожалуйста.',
      'Лимон қосылған, бірақ қантсыз шай беріңізші.',
      'Tee mit Zitrone, aber ohne Zucker, bitte.',
      'Un thé au citron, mais sans sucre, s’il vous plaît.',
      '请给我一杯柠檬茶，但不要加糖。',
      'شاي بالليمون، لكن من دون سكر، من فضلك.',
      '차에 레몬은 넣고 설탕은 빼 주세요.',
      '紅茶にレモンを入れてください。砂糖はいりません。',
      'Limonlu çay, lütfen. Şeker olmasın.',
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
      [
        ...StudyCourse.germanCourses,
        ...StudyCourse.multilingualCourses,
      ].any((entry) => entry.id == course.id);
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
