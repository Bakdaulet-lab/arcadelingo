import 'package:arcadelingo/domain/settings/app_settings.dart';
import 'package:arcadelingo/ui/app_strings.dart';

extension KitchenStrings on AppStrings {
  String _choose(String ru, String en, String es, String kk) =>
      switch (language) {
        InterfaceLanguage.english => en,
        InterfaceLanguage.spanish => es,
        InterfaceLanguage.kazakh => kk,
        InterfaceLanguage.russian || InterfaceLanguage.system => ru,
      };

  String ticket(int number, int total) => _choose(
    'Заказ $number из $total',
    'Order $number of $total',
    'Pedido $number de $total',
    'Тапсырыс $number/$total',
  );

  String get ingredients =>
      _choose('Ингредиенты', 'Ingredients', 'Ingredientes', 'Сусын құрамы');
  String get serveDrink =>
      _choose('Подать напиток', 'Serve drink', 'Servir bebida', 'Сусынды беру');
  String get nextGuest => _choose(
    'Следующий гость',
    'Next guest',
    'Siguiente cliente',
    'Келесі қонақ',
  );
  String get finishShift => _choose(
    'Итоги смены',
    'Finish shift',
    'Terminar turno',
    'Ауысым қорытындысы',
  );
  String get adjustDrink => _choose(
    'Немного поправим',
    'Adjust the drink',
    'Ajusta la bebida',
    'Сусынның құрамын түзет',
  );
  String get addItems => _choose('Добавить', 'Add', 'Añadir', 'Қосу');
  String get removeItems =>
      _choose('Убрать', 'Remove', 'Quitar', 'Алып тастау');
  String get servedDrink => _choose(
    'Спасибо, всё по заказу!',
    'Just right, thank you!',
    '¡Así está perfecto, gracias!',
    'Рақмет, дәл тапсырысымдағыдай!',
  );
  String get shiftDone => _choose(
    'Смена окончена',
    'Shift complete',
    'Turno completado',
    'Ауысым аяқталды',
  );
  String get firstTry => _choose(
    'С первой попытки',
    'On the first try',
    'Al primer intento',
    'Бірінші әрекетте',
  );
  String get anotherShift => _choose(
    'Ещё одна смена',
    'Another shift',
    'Otro turno',
    'Тағы бір ауысым',
  );
  String get unavailable => _choose(
    'Для этого курса пока нет заказов.',
    'There are no orders for this course yet.',
    'Aún no hay pedidos para este curso.',
    'Бұл курсқа арналған тапсырыстар әзірге жоқ.',
  );
}
