import 'package:arcadelingo/domain/settings/app_settings.dart';
import 'package:arcadelingo/ui/app_strings.dart';

extension KitchenStrings on AppStrings {
  String _choose(String ru, String en, String es) => switch (language) {
    InterfaceLanguage.english => en,
    InterfaceLanguage.spanish => es,
    InterfaceLanguage.russian || InterfaceLanguage.system => ru,
  };

  String ticket(int number, int total) => _choose(
    'Заказ $number из $total',
    'Order $number of $total',
    'Pedido $number de $total',
  );

  String get ingredients =>
      _choose('Ингредиенты', 'Ingredients', 'Ingredientes');
  String get serveDrink =>
      _choose('Подать напиток', 'Serve drink', 'Servir bebida');
  String get nextGuest =>
      _choose('Следующий гость', 'Next guest', 'Siguiente cliente');
  String get finishShift =>
      _choose('Итоги смены', 'Finish shift', 'Terminar turno');
  String get adjustDrink =>
      _choose('Немного поправим', 'Adjust the drink', 'Ajusta la bebida');
  String get addItems => _choose('Добавить', 'Add', 'Añadir');
  String get removeItems => _choose('Убрать', 'Remove', 'Quitar');
  String get servedDrink => _choose(
    'Спасибо, всё по заказу!',
    'Just right, thank you!',
    '¡Así está perfecto, gracias!',
  );
  String get shiftDone =>
      _choose('Смена окончена', 'Shift complete', 'Turno completado');
  String get firstTry =>
      _choose('С первой попытки', 'On the first try', 'Al primer intento');
  String get anotherShift =>
      _choose('Ещё одна смена', 'Another shift', 'Otro turno');
  String get unavailable => _choose(
    'Для этого курса пока нет заказов.',
    'There are no orders for this course yet.',
    'Aún no hay pedidos para este curso.',
  );
}
