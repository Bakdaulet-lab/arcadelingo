part of 'app_strings.dart';

extension SpaceWordStrings on AppStrings {
  String get spaceWordInstruction => _text(
    en: 'Dodge asteroids and shoot the drone with the right translation',
    ru: 'Облетай астероиды и сбивай дрон с верным переводом',
    es: 'Esquiva los asteroides y dispara al dron con la traducción correcta',
  );
  String get spaceFind => _text(
    en: 'Find the translation',
    ru: 'Найди перевод',
    es: 'Busca la traducción',
  );
  String get spaceWave => _text(en: 'Wave', ru: 'Волна', es: 'Oleada');
  String get spaceShield => _text(en: 'Shield', ru: 'Щит', es: 'Escudo');
  String get spacePoints => _text(en: 'Score', ru: 'Очки', es: 'Puntos');
  String get spaceLaunch =>
      _text(en: 'Launch', ru: 'Начать полёт', es: 'Despegar');
  String get spaceFire => _text(en: 'Fire', ru: 'Огонь', es: 'Disparar');
  String get spaceDrag => _text(
    en: 'Drag to fly. Keep holding to fire.',
    ru: 'Веди пальцем по полю. Удерживай для стрельбы.',
    es: 'Arrastra para pilotar. Mantén el dedo en la pantalla para disparar.',
  );
  String get spaceKeys => _text(
    en: 'Move with WASD or the arrow keys. Fire with Space.',
    ru: 'Стрелки или WASD — движение. Пробел — огонь.',
    es: 'Muévete con WASD o las flechas. Dispara con la barra espaciadora.',
  );
  String spaceDamage(int shields) => _text(
    en: 'Collision! Shield charges left: $shields.',
    ru: 'Столкновение! Зарядов щита осталось: $shields.',
    es: '¡Colisión! Cargas de escudo restantes: $shields.',
  );
  String spaceWrong(Word choice, String goal) => _text(
    en: '${choice.text} — ${choice.translation}. Look for “$goal”.',
    ru: '${choice.text} — ${choice.translation}. Цель — «$goal».',
    es: '${choice.text} — ${choice.translation}. Busca «$goal».',
  );
}
