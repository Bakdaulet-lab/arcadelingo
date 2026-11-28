part of 'app_strings.dart';

extension CandyDeliveryStrings on AppStrings {
  String get candyDelivery => _text(
    en: 'Candy Delivery',
    ru: 'Доставка конфеты',
    es: 'Entrega de caramelos',
    kk: 'Кәмпит жеткізу',
  );
  String get candyHomeHint => _text(
    en: 'Read the order and cut the rope to deliver the sweet.',
    ru: 'Прочитай заказ и разрежь верёвку, чтобы угостить кролика.',
    es: 'Lee el pedido y corta la cuerda para darle el caramelo al conejo.',
    kk: 'Тапсырысты оқып, қоянға кәмпит жеткізу үшін арқанды кес.',
  );
  String candyOrderNumber(int n, int total) => _text(
    en: 'Order $n of $total',
    ru: 'Заказ $n из $total',
    es: 'Pedido $n de $total',
    kk: 'Тапсырыс $n/$total',
  );
  String get candySwipe => _text(
    en: 'Swipe across the rope',
    ru: 'Проведи поперёк верёвки',
    es: 'Desliza el dedo sobre la cuerda para cortarla',
    kk: 'Арқанды кесу үшін үстінен саусағыңмен сырғыт',
  );
  String get candyAim => _text(
    en: 'Choose a direction, then cut',
    ru: 'Выбери направление и разрежь верёвку',
    es: 'Elige una dirección y corta la cuerda',
    kk: 'Бағытты таңдап, арқанды кес',
  );
  String get candyCut => _text(
    en: 'Cut the rope',
    ru: 'Разрезать',
    es: 'Cortar',
    kk: 'Арқанды кесу',
  );
  String get candyFlying => _text(
    en: 'On its way…',
    ru: 'Конфета летит…',
    es: 'El caramelo está en el aire…',
    kk: 'Кәмпит ұшып барады…',
  );
  String get candyDelivered => _text(
    en: 'Delivered!',
    ru: 'Доставлено!',
    es: '¡Entregado!',
    kk: 'Кәмпит жеткізілді!',
  );
  String get candyOtherRabbit => _text(
    en: 'Another rabbit caught it',
    ru: 'Конфета у другого кролика',
    es: 'Otro conejo recibió el caramelo',
    kk: 'Кәмпитті басқа қоян ұстап алды',
  );
  String get candyInGrass => _text(
    en: 'It landed in the grass',
    ru: 'Конфета упала в траву',
    es: 'El caramelo cayó en la hierba',
    kk: 'Кәмпит шөпке түсті',
  );
  String get candyRetry => _text(
    en: 'Try again',
    ru: 'Ещё раз',
    es: 'Reintentar',
    kk: 'Қайталап көру',
  );
  String get candyNext => _text(
    en: 'Next order',
    ru: 'Следующий заказ',
    es: 'Siguiente pedido',
    kk: 'Келесі тапсырыс',
  );
  String get candyUnavailable => _text(
    en: 'There are no orders for this course and level yet.',
    ru: 'Для этого курса и уровня пока нет заказов.',
    es: 'Todavía no hay pedidos para este curso y nivel.',
    kk: 'Бұл курс пен деңгейге арналған тапсырыстар әзірге жоқ.',
  );
  String candyLane(int lane) => switch (lane) {
    0 => _text(en: 'Left', ru: 'Слева', es: 'Izquierda', kk: 'Сол жақ'),
    1 => _text(en: 'Middle', ru: 'В центре', es: 'Centro', kk: 'Ортада'),
    _ => _text(en: 'Right', ru: 'Справа', es: 'Derecha', kk: 'Оң жақ'),
  };
  String candyRabbit(int identity) => switch (identity) {
    0 => _text(
      en: 'Rabbit wearing a scarf',
      ru: 'Кролик в шарфе',
      es: 'Conejo con bufanda',
      kk: 'Шарф таққан қоян',
    ),
    1 => _text(
      en: 'Rabbit sleeping under a blanket',
      ru: 'Кролик спит под пледом',
      es: 'Conejo dormido bajo una manta',
      kk: 'Көрпенің астында ұйықтап жатқан қоян',
    ),
    _ => _text(
      en: 'Rabbit reading a book, with a flower by its ear',
      ru: 'Кролик с цветком у уха читает книгу',
      es: 'Conejo leyendo un libro, con una flor junto a la oreja',
      kk: 'Құлағының тұсында гүлі бар, кітап оқып отырған қоян',
    ),
  };
}
