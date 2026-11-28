part of 'app_strings.dart';

extension SpaceWordStrings on AppStrings {
  String get spaceWordInstruction => _text(
    en: 'Dodge asteroids and shoot the drone with the right translation',
    ru: 'Облетай астероиды и сбивай дрон с верным переводом',
    es: 'Esquiva los asteroides y dispara al dron con la traducción correcta',
    kk: 'Астероидтарды айналып өтіп, дұрыс аудармасы бар дронды атып түсір',
  );
  String get spaceFind => _text(
    en: 'Find the translation',
    ru: 'Найди перевод',
    es: 'Busca la traducción',
    kk: 'Аударманы тап',
  );
  String get spaceWave =>
      _text(en: 'Wave', ru: 'Волна', es: 'Oleada', kk: 'Толқын');
  String get spaceShield =>
      _text(en: 'Shield', ru: 'Щит', es: 'Escudo', kk: 'Қалқан');
  String get spacePoints =>
      _text(en: 'Score', ru: 'Очки', es: 'Puntos', kk: 'Ұпай');
  String get spaceLaunch => _text(
    en: 'Launch',
    ru: 'Начать полёт',
    es: 'Despegar',
    kk: 'Ұшуды бастау',
  );
  String get spaceFire =>
      _text(en: 'Fire', ru: 'Огонь', es: 'Disparar', kk: 'Ату');
  String get spaceDrag => _text(
    en: 'Drag to fly. Keep holding to fire.',
    ru: 'Веди пальцем по полю. Удерживай для стрельбы.',
    es: 'Arrastra para pilotar. Mantén el dedo en la pantalla para disparar.',
    kk: 'Кемені жылжыту үшін саусағыңды сырғыт. Ату үшін басып тұр.',
  );
  String get spaceKeys => _text(
    en: 'Move with WASD or the arrow keys. Fire with Space.',
    ru: 'Стрелки или WASD — движение. Пробел — огонь.',
    es: 'Muévete con WASD o las flechas. Dispara con la barra espaciadora.',
    kk:
        'Кемені WASD не бағыттауыш пернелермен жылжыт. Ату үшін бос орын пернесін бас.',
  );
  String spaceDamage(int shields) => _text(
    en: 'Collision! Shield charges left: $shields.',
    ru: 'Столкновение! Зарядов щита осталось: $shields.',
    es: '¡Colisión! Cargas de escudo restantes: $shields.',
    kk: 'Қақтығыс! Қалқан қоры: $shields.',
  );
  String spaceWrong(Word choice, String goal) => _text(
    en: '${choice.text} — ${choice.translation}. Look for “$goal”.',
    ru: '${choice.text} — ${choice.translation}. Цель — «$goal».',
    es: '${choice.text} — ${choice.translation}. Busca «$goal».',
    kk: '${choice.text} — ${choice.translation}. «$goal» аудармасын ізде.',
  );
}
