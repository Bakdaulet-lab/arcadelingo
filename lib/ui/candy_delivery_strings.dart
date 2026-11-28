part of 'app_strings.dart';

extension CandyDeliveryStrings on AppStrings {
  String get candyDelivery => _text(
    en: 'Candy Delivery',
    ru: 'Доставка конфеты',
    es: 'Entrega de caramelos',
  );
  String get candyHomeHint => _text(
    en: 'Read the order and cut the rope to deliver the sweet.',
    ru: 'Прочитай заказ и разрежь верёвку, чтобы угостить кролика.',
    es: 'Lee el pedido y corta la cuerda para darle el caramelo al conejo.',
  );
  String candyOrderNumber(int n, int total) => _text(
    en: 'Order $n of $total',
    ru: 'Заказ $n из $total',
    es: 'Pedido $n de $total',
  );
  String get candySwipe => _text(
    en: 'Swipe across the rope',
    ru: 'Проведи поперёк верёвки',
    es: 'Desliza el dedo sobre la cuerda para cortarla',
  );
  String get candyAim => _text(
    en: 'Choose a direction, then cut',
    ru: 'Выбери направление и разрежь верёвку',
    es: 'Elige una dirección y corta la cuerda',
  );
  String get candyCut =>
      _text(en: 'Cut the rope', ru: 'Разрезать', es: 'Cortar');
  String get candyFlying => _text(
    en: 'On its way…',
    ru: 'Конфета летит…',
    es: 'El caramelo está en el aire…',
  );
  String get candyDelivered =>
      _text(en: 'Delivered!', ru: 'Доставлено!', es: '¡Entregado!');
  String get candyOtherRabbit => _text(
    en: 'Another rabbit caught it',
    ru: 'Конфета у другого кролика',
    es: 'Otro conejo recibió el caramelo',
  );
  String get candyInGrass => _text(
    en: 'It landed in the grass',
    ru: 'Конфета упала в траву',
    es: 'El caramelo cayó en la hierba',
  );
  String get candyRetry =>
      _text(en: 'Try again', ru: 'Ещё раз', es: 'Reintentar');
  String get candyNext =>
      _text(en: 'Next order', ru: 'Следующий заказ', es: 'Siguiente pedido');
  String get candyUnavailable => _text(
    en: 'There are no orders for this course and level yet.',
    ru: 'Для этого курса и уровня пока нет заказов.',
    es: 'Todavía no hay pedidos para este curso y nivel.',
  );
  String candyLane(int lane) => switch (lane) {
    0 => _text(en: 'Left', ru: 'Слева', es: 'Izquierda'),
    1 => _text(en: 'Middle', ru: 'В центре', es: 'Centro'),
    _ => _text(en: 'Right', ru: 'Справа', es: 'Derecha'),
  };
  String candyRabbit(int identity) => switch (identity) {
    0 => _text(
      en: 'Rabbit wearing a scarf',
      ru: 'Кролик в шарфе',
      es: 'Conejo con bufanda',
    ),
    1 => _text(
      en: 'Rabbit sleeping under a blanket',
      ru: 'Кролик спит под пледом',
      es: 'Conejo dormido bajo una manta',
    ),
    _ => _text(
      en: 'Rabbit reading a book, with a flower by its ear',
      ru: 'Кролик с цветком у уха читает книгу',
      es: 'Conejo leyendo un libro, con una flor junto a la oreja',
    ),
  };
}
