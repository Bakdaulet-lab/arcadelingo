import 'package:arcadelingo/domain/challenges/challenge_session.dart';
import 'package:arcadelingo/domain/review/review_contract.dart';
import 'package:arcadelingo/domain/review/study_course.dart';
import 'package:arcadelingo/domain/settings/app_settings.dart';
import 'package:arcadelingo/domain/stories/situation_story.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';

const russianStrings = AppStrings(InterfaceLanguage.russian);

/// Тексты ArcadeLingo. Язык курса задаёт данные карточки независимо от меню.
class AppStrings {
  const AppStrings(this.language);

  static const delegate = _AppStringsDelegate();
  static AppStrings of(BuildContext context) =>
      Localizations.of<AppStrings>(context, AppStrings) ?? russianStrings;

  final InterfaceLanguage language;
  bool get isRussian => language == InterfaceLanguage.russian;

  String _text({required String en, required String ru, required String es}) =>
      switch (language) {
        InterfaceLanguage.english => en,
        InterfaceLanguage.spanish => es,
        InterfaceLanguage.russian || InterfaceLanguage.system => ru,
      };

  String get challenge =>
      _text(en: 'Challenge', ru: 'Испытание', es: 'Desafío');

  String get situationStories => _text(
    en: 'On the way home',
    ru: 'Пока ехал домой',
    es: 'De camino a casa',
  );

  String get activeRecall =>
      _text(en: 'Recall it', ru: 'Вспомни сам', es: 'Recuerda la palabra');

  String get confusedWords => _text(
    en: 'Words I mix up',
    ru: 'Слова, которые я путаю',
    es: 'Palabras que confundo',
  );
  String get noConfusedPairs => _text(
    en: 'No repeated mix-ups yet',
    ru: 'Пока нет повторяющихся пар',
    es: 'Aún no hay confusiones repetidas',
  );
  String get confusionThreshold => _text(
    en:
        'A pair appears here when you choose one word instead of the other twice.',
    ru:
        'Пара появится здесь, когда ты дважды выберешь одно слово вместо другого.',
    es:
        'Aquí aparecerá una pareja cuando elijas dos veces una palabra en lugar de la otra.',
  );
  String confusionCount(int count) => _text(
    en: 'Mix-ups: $count',
    ru: 'Ошибок с этой парой — $count',
    es: 'Confusiones: $count',
  );
  String get practisePair => _text(
    en: 'Practise this pair',
    ru: 'Разобрать пару',
    es: 'Practicar esta pareja',
  );
  String get completeSentence => _text(
    en: 'Complete the sentence',
    ru: 'Дополни фразу',
    es: 'Completa la frase',
  );
  String get pickByMeaning => _text(
    en: 'Choose the matching word',
    ru: 'Выбери слово по значению',
    es: 'Elige la palabra que corresponde',
  );
  String get tryOtherWord => _text(
    en: 'Try the other word',
    ru: 'Попробуй другое слово',
    es: 'Prueba con la otra palabra',
  );
  String get pairComplete => _text(
    en: 'Pair practised',
    ru: 'Пара разобрана',
    es: 'Práctica completada',
  );
  String confusionScore(int score, int total) => _text(
    en: 'Correct on the first try: $score of $total',
    ru: 'С первой попытки — $score из $total',
    es: 'A la primera: $score de $total',
  );
  String get backToPairs => _text(
    en: 'Back to word pairs',
    ru: 'К парам слов',
    es: 'Volver a las parejas',
  );

  String get recallHomeHint => _text(
    en: 'Recall the word, then spell it with letters',
    ru: 'Вспомни слово и собери его из букв',
    es: 'Recuerda la palabra y fórmala con letras',
  );

  String recallPrompt(String tag) => _text(
    en: 'How do you say this in ${languageName(tag)}?',
    ru: switch (tag) {
      'en' => 'Как это сказать по-английски?',
      'es' => 'Как это сказать по-испански?',
      _ => 'Как это сказать на изучаемом языке?',
    },
    es: '¿Cómo se dice en ${languageName(tag).toLowerCase()}?',
  );

  String get recallSpell =>
      _text(en: 'Spell the word', ru: 'Собрать слово', es: 'Formar la palabra');
  String get recallOptions =>
      _text(en: 'Show choices', ru: 'Показать варианты', es: 'Ver opciones');
  String get recallCheck =>
      _text(en: 'Check', ru: 'Проверить', es: 'Comprobar');
  String get recallUndo => _text(
    en: 'Remove last letter',
    ru: 'Убрать последнюю букву',
    es: 'Quitar la última letra',
  );
  String get recallChoicesPrompt =>
      _text(en: 'Choose the word', ru: 'Выбери слово', es: 'Elige la palabra');
  String get recallRightWord => _text(
    en: 'The word to remember',
    ru: 'Слово для повторения',
    es: 'La palabra para repasar',
  );
  String get recallIndependent =>
      _text(en: 'Recalled unaided', ru: 'Без подсказки', es: 'Sin ayuda');
  String get recallWithHelp => _text(
    en: 'Recognised from choices',
    ru: 'С подсказкой',
    es: 'Con opciones',
  );
  String get recallMistakes =>
      _text(en: 'To practise again', ru: 'На повторение', es: 'Para repasar');
  String get recallResults =>
      _text(en: 'See results', ru: 'Посмотреть итоги', es: 'Ver resultados');

  String get storyHomeHint => _text(
    en: 'Two short games and a real-life task',
    ru: 'Две короткие игры и задача из жизни',
    es: 'Dos juegos cortos y una tarea de la vida diaria',
  );

  String get chooseSituation => _text(
    en: 'Choose a situation',
    ru: 'Выбери ситуацию',
    es: 'Elige una situación',
  );

  String storyTitle(StorySituation situation) => switch (situation) {
    StorySituation.breakfast => _text(
      en: 'Order breakfast',
      ru: 'Заказать завтрак',
      es: 'Pedir el desayuno',
    ),
    StorySituation.hotel => _text(
      en: 'Check in at a hotel',
      ru: 'Заселиться в отель',
      es: 'Registrarse en un hotel',
    ),
    StorySituation.station => _text(
      en: 'Find your train',
      ru: 'Найти свой поезд',
      es: 'Encontrar tu tren',
    ),
  };

  String storyRound(int round) => _text(
    en: 'Game $round of 2',
    ru: 'Игра $round из 2',
    es: 'Juego $round de 2',
  );

  String get startStoryRound =>
      _text(en: 'Start game', ru: 'Начать игру', es: 'Empezar el juego');

  String get storyRoundInterrupted => _text(
    en: 'Finish this round to continue.',
    ru: 'Чтобы продолжить, доиграй этот раунд.',
    es: 'Termina esta ronda para continuar.',
  );

  String get storyFinal =>
      _text(en: 'Final task', ru: 'Финальное задание', es: 'Tarea final');

  String get tryStoryAnswerAgain => _text(
    en: 'Read the message again and try another answer.',
    ru: 'Прочитай фразу ещё раз и выбери другой ответ.',
    es: 'Vuelve a leer el mensaje y prueba con otra respuesta.',
  );

  String get storyComplete => _text(
    en: 'Situation complete',
    ru: 'Ситуация пройдена',
    es: 'Situación completada',
  );

  String get backToSituations => _text(
    en: 'Back to situations',
    ru: 'К ситуациям',
    es: 'Volver a las situaciones',
  );

  String challengeName(ArcadeChallenge mode) => switch (mode) {
    ArcadeChallenge.sprint => _text(
      en: '60-second sprint',
      ru: '60 секунд',
      es: 'Esprint de 60 segundos',
    ),
    ArcadeChallenge.streak => _text(
      en: 'Eight in a row',
      ru: 'Восемь точных ударов',
      es: 'Ocho cortes seguidos',
    ),
    ArcadeChallenge.claw => _text(
      en: 'Three words, one hint',
      ru: 'Три слова, одна подсказка',
      es: 'Tres palabras, una pista',
    ),
    ArcadeChallenge.brick => _text(
      en: 'Three Golden Bricks',
      ru: 'Три золотых кирпича',
      es: 'Tres bloques dorados',
    ),
  };

  String challengeRules(ArcadeChallenge mode) => switch (mode) {
    ArcadeChallenge.sprint => _text(
      en:
          'Score as many points as you can in 60 seconds. A wrong or missed answer costs 5 seconds.',
      ru:
          'Набери как можно больше очков за 60 секунд. Промах или таймаут отнимает 5 секунд.',
      es:
          'Consigue todos los puntos que puedas en 60 segundos. Cada fallo o respuesta fuera de tiempo resta 5 segundos.',
    ),
    ArcadeChallenge.streak => _text(
      en:
          'Make eight correct cuts in a row. A miss resets the streak and costs a life. Your record is your longest streak.',
      ru:
          'Сделай восемь точных ударов подряд. Промах сбрасывает серию и отнимает жизнь. В рекорд идёт самая длинная серия.',
      es:
          'Haz ocho cortes correctos seguidos. Cada fallo reinicia la racha y cuesta una vida. Tu récord es la racha más larga.',
    ),
    ArcadeChallenge.claw => _text(
      en:
          'Spell three words with one hint for the whole round. Your record counts words spelled without a wrong grab.',
      ru:
          'Собери три слова. На весь раунд есть одна подсказка. В рекорд идут слова, собранные без ошибочных захватов.',
      es:
          'Forma tres palabras con una sola pista para toda la ronda. Para el récord cuentan las palabras completadas sin atrapar letras equivocadas.',
    ),
    ArcadeChallenge.brick => _text(
      en:
          'Break three golden bricks with one life. Each brick earns points. A correct translation gives you three balls. Letting all choices fall spends one chance. Your score counts toward the record.',
      ru:
          'Разбей три золотых кирпича за одну жизнь. Кирпичи приносят очки, а верный перевод даёт три мяча. Если все варианты упали, попытка расходуется. В рекорд идёт счёт партии.',
      es:
          'Rompe tres bloques dorados con una sola vida. Cada bloque da puntos y cada traducción correcta te da tres bolas. Si dejas caer todas las opciones, gastas un intento. Tu puntuación cuenta para el récord.',
    ),
  };

  String challengeBest(int? best) =>
      best == null
          ? _text(
            en: 'No record yet',
            ru: 'Рекорда пока нет',
            es: 'Todavía no hay récord',
          )
          : _text(
            en: 'Personal best: $best',
            ru: 'Личный рекорд: $best',
            es: 'Récord personal: $best',
          );

  String get savingChallenge => _text(
    en: 'Saving result…',
    ru: 'Сохраняем результат…',
    es: 'Guardando el resultado…',
  );

  String get challengeSaveFailed => _text(
    en: 'Couldn’t save the result',
    ru: 'Не удалось сохранить результат',
    es: 'No se pudo guardar el resultado',
  );

  String sprintTime(int seconds) => _text(
    en: 'Time left: $seconds s',
    ru: 'Осталось $seconds с',
    es: 'Quedan $seconds s',
  );

  String challengeStreak(int hits, int target) => _text(
    en: 'Streak: $hits/$target',
    ru: 'Серия: $hits/$target',
    es: 'Racha: $hits/$target',
  );

  String challengeHints(int count) => _text(
    en: 'Hints left: $count',
    ru: 'Подсказок осталось: $count',
    es: 'Pistas restantes: $count',
  );

  String get sources => _text(en: 'Sources', ru: 'Источники', es: 'Fuentes');
  String get chooseGame =>
      _text(en: 'Choose a game', ru: 'Выбери игру', es: 'Elige un juego');
  String get learnAndPlay => _text(
    en: 'Preview words and play',
    ru: 'Знакомство и игра',
    es: 'Aprende las palabras y juega',
  );
  String get play => _text(en: 'Play', ru: 'Играть', es: 'Jugar');
  String get games => _text(en: 'Games', ru: 'Игры', es: 'Juegos');
  String get progress => _text(en: 'Progress', ru: 'Прогресс', es: 'Progreso');
  String get settings => _text(en: 'Settings', ru: 'Настройки', es: 'Ajustes');
  String get appearance => _text(en: 'Theme', ru: 'Тема', es: 'Tema');
  String get lightTheme => _text(en: 'Light', ru: 'Светлая', es: 'Claro');
  String get darkTheme => _text(en: 'Dark', ru: 'Тёмная', es: 'Oscuro');
  String get progressUnreadable => _text(
    en: 'Unable to read progress',
    ru: 'Прогресс не читается',
    es: 'No se pudo leer el progreso',
  );
  String get resetHint => _text(
    en: 'Resetting starts your word practice over.',
    ru: 'После сброса слова начнутся заново, как при первом запуске.',
    es:
        'Si restableces el progreso, volverás a practicar las palabras desde el principio.',
  );
  String get resetProgress => _text(
    en: 'Reset progress',
    ru: 'Сбросить прогресс',
    es: 'Restablecer progreso',
  );
  String get dictionaryUnreadable => _text(
    en: 'Unable to read the course dictionary',
    ru: 'Словарь не читается',
    es: 'No se pudo leer el diccionario del curso',
  );
  String get dictionaryRepairHint => _text(
    en: 'The course data in this version is invalid. Please update the app.',
    ru: 'Это дефект сборки: сбрасывать нечего, поможет только обновление.',
    es:
        'Los datos del curso de esta versión presentan un error. Actualiza la aplicación.',
  );
  String get fallingWords =>
      _text(en: 'Falling Words', ru: 'Падающие слова', es: 'Palabras que caen');
  String get fallingInstruction => _text(
    en: 'Tap the correct translation',
    ru: 'Нажми на верный перевод',
    es: 'Toca la traducción correcta',
  );
  String get ninjaSlash =>
      _text(en: 'Ninja Slash', ru: 'Ниндзя-слэш', es: 'Corte ninja');
  String get ninjaInstruction => _text(
    en: 'Swipe through the correct translation',
    ru: 'Разрежь правильный перевод',
    es: 'Desliza el dedo para cortar la traducción correcta',
  );
  String get clawMachine => _text(
    en: 'Claw Machine',
    ru: 'Автомат с клешнёй',
    es: 'Máquina de garra',
  );
  String get clawInstruction => _text(
    en: 'Collect letters to spell the word',
    ru: 'Собери слово из букв',
    es: 'Atrapa letras para formar la palabra',
  );
  String get chooseCourse =>
      _text(en: 'Choose a course', ru: 'Выбери курс', es: 'Elige un curso');
  String get brickBreaker =>
      _text(en: 'Brick Breaker', ru: 'Арканоид', es: 'Rompebloques');
  String get matchThree =>
      _text(en: 'Match Three', ru: 'Три в ряд', es: 'Combina tres');
  String get matchInstruction => _text(
    en: 'Match gems to unlock word bonuses',
    ru: 'Собирай кристаллы и открывай словесные бонусы',
    es: 'Combina gemas para activar bonos de vocabulario',
  );
  String get matchGuide => _text(
    en: 'Slide the highlighted gem down to make a match of four.',
    ru: 'Сдвинь выделенный кристалл вниз, чтобы собрать четыре в ряд.',
    es: 'Desliza la gema resaltada hacia abajo para alinear cuatro gemas.',
  );
  String get matchHint => _text(
    en: 'Match four gems in a row to unlock a word.',
    ru: 'Собери четыре кристалла в ряд, чтобы открыть слово.',
    es: 'Alinea cuatro gemas para descubrir una palabra.',
  );
  String get matchInvalidMove => _text(
    en: 'Swap two gems to line up three of the same kind.',
    ru: 'Поменяй два кристалла местами, чтобы собрать три одинаковых в ряд.',
    es: 'Intercambia dos gemas para alinear tres del mismo tipo.',
  );
  String get matchBonus => _text(
    en: 'Clear a row',
    ru: 'Бонус «Очистить строку»',
    es: 'Bono «Limpia una fila»',
  );
  String get matchCleared => _text(
    en: 'Row cleared. Correct translation +60.',
    ru: 'Строка очищена. За верный перевод +60.',
    es: 'Fila eliminada. Traducción correcta +60.',
  );
  String matchMoves(int count) =>
      _text(en: 'Moves: $count', ru: 'Ходы: $count', es: 'Movimientos: $count');
  String matchGem(int kind, int row, int column) {
    final names = _text(
      en:
          'cyan diamond,pink sphere,amber hexagon,lilac crystal,mint square,blue triangle,charged gem',
      ru:
          'голубой ромб,розовая сфера,янтарный шестигранник,лиловый кристалл,мятный квадрат,синий треугольник,заряженная фишка',
      es:
          'rombo turquesa,esfera rosa,hexágono ámbar,cristal lila,cuadrado verde,triángulo azul,gema cargada',
    ).split(',');
    final name =
        kind < 0
            ? _text(en: 'empty cell', ru: 'пустая клетка', es: 'casilla vacía')
            : names[kind];
    return _text(
      en: '$name, row $row, column $column',
      ru: '$name, ряд $row, столбец $column',
      es: '$name, fila $row, columna $column',
    );
  }

  String get wordMahjong => _text(
    en: 'Word Mahjong',
    ru: 'Маджонг со словами',
    es: 'Mahjong de palabras',
  );
  String get mahjongInstruction => _text(
    en: 'Match each word with its translation',
    ru: 'Снимай пары из слова и его перевода',
    es: 'Empareja cada palabra con su traducción',
  );
  String get mahjongRules => _text(
    en:
        'Match a word with its translation. Each tile must be uncovered and have a free side.',
    ru:
        'Соедини слово и перевод. Плитка должна быть открыта сверху и свободна хотя бы с одной стороны.',
    es:
        'Une una palabra con su traducción. Cada ficha debe estar descubierta y tener un lado libre.',
  );
  String get mahjongMismatch => _text(
    en: 'These tiles do not match. Try again.',
    ru: 'Эти плитки не совпадают. Попробуй ещё раз.',
    es: 'Estas fichas no forman pareja. Inténtalo de nuevo.',
  );
  String get mahjongHintShown => _text(
    en: 'Tap both highlighted tiles to remove the pair.',
    ru: 'Нажми на обе подсвеченные плитки, чтобы снять пару.',
    es: 'Toca las dos fichas resaltadas para retirar la pareja.',
  );
  String get mahjongWord => _text(en: 'word', ru: 'слово', es: 'palabra');
  String get mahjongTranslation =>
      _text(en: 'translation', ru: 'перевод', es: 'traducción');
  String mahjongPairs(int count, int total) => _text(
    en: 'Pairs: $count / $total',
    ru: 'Пары: $count / $total',
    es: 'Parejas: $count / $total',
  );

  String get snake => _text(en: 'Snake', ru: 'Змейка', es: 'Serpiente');
  String get snakeInstruction => _text(
    en: 'Catch the apple with the right translation',
    ru: 'Поймай яблоко с нужным переводом',
    es: 'Atrapa la manzana con la traducción correcta',
  );
  String get snakePrompt => _text(
    en: 'Find the translation',
    ru: 'Найди перевод',
    es: 'Busca la traducción',
  );
  String get snakeGuide => _text(
    en:
        'Swipe anywhere on the board to steer. Keep your finger down to turn again.',
    ru:
        'Веди пальцем по полю. Чтобы повернуть ещё раз, просто смени направление.',
    es:
        'Desliza el dedo por el tablero. Para volver a girar, cambia de dirección sin levantarlo.',
  );
  String get snakeBoard => _text(
    en: 'Snake board',
    ru: 'Поле змейки',
    es: 'Tablero de la serpiente',
  );
  String get snakeStart =>
      _text(en: 'Start moving', ru: 'Начать движение', es: 'Empezar a moverse');
  String get snakePause => _text(en: 'Pause', ru: 'Пауза', es: 'Pausa');
  String get snakeResume =>
      _text(en: 'Resume', ru: 'Продолжить', es: 'Continuar');
  String get snakeResults =>
      _text(en: 'Results', ru: 'Итоги', es: 'Resultados');
  String get snakeTail => _text(
    en: 'The snake ran into its tail.',
    ru: 'Змейка коснулась хвоста.',
    es: 'La serpiente chocó con su cola.',
  );
  String get snakeLeft => _text(en: 'Left', ru: 'Влево', es: 'Izquierda');
  String get snakeUp => _text(en: 'Up', ru: 'Вверх', es: 'Arriba');
  String get snakeDown => _text(en: 'Down', ru: 'Вниз', es: 'Abajo');
  String get snakeRight => _text(en: 'Right', ru: 'Вправо', es: 'Derecha');
  String snakeCount(int count, int total) => _text(
    en: 'Correct $count/$total',
    ru: 'Верно $count/$total',
    es: 'Aciertos $count/$total',
  );
  String snakeAnswer(Word word, Word choice, {required bool correct}) {
    final pair = '${word.text} — ${word.translation}';
    if (correct) return '${this.correct}! $pair';
    return _text(
      en: '${choice.text} — ${choice.translation}. Correct match: $pair.',
      ru: '${choice.text} — ${choice.translation}. Верная пара: $pair.',
      es: '${choice.text} — ${choice.translation}. Pareja correcta: $pair.',
    );
  }

  String get brickInstruction => _text(
    en: 'Break bricks and catch translations',
    ru: 'Разбивай кирпичи и лови переводы',
    es: 'Rompe bloques y atrapa traducciones',
  );
  String get brickCatch => _text(
    en: 'Catch the translation with the paddle',
    ru: 'Поймай перевод платформой',
    es: 'Atrapa la traducción con la pala',
  );
  String get brickGold => _text(
    en: 'Break a gold brick to reveal a word',
    ru: 'Разбей золотой кирпич, чтобы открыть слово',
    es: 'Rompe un bloque dorado para descubrir una palabra',
  );
  String get brickMove => _text(
    en: 'Drag sideways to move the paddle',
    ru: 'Веди пальцем влево или вправо',
    es: 'Desliza el dedo a los lados para mover la pala',
  );
  String get brickLaunch =>
      _text(en: 'Launch', ru: 'Пустить мяч', es: 'Lanzar');
  String get brickPause => _text(en: 'Pause', ru: 'Пауза', es: 'Pausar');
  String get brickPaused => _text(en: 'Paused', ru: 'На паузе', es: 'En pausa');
  String get brickResume =>
      _text(en: 'Resume', ru: 'Продолжить', es: 'Continuar');
  String get brickMultiball => _text(
    en: 'Bonus: three balls',
    ru: 'Бонус: три мяча',
    es: 'Bono: tres bolas',
  );
  String get brickMissed => _text(
    en: 'Missed the catch. Break another gold brick to try again.',
    ru: 'Промах. Разбей ещё один золотой кирпич для новой попытки.',
    es:
        'No atrapaste ninguna opción. Rompe otro bloque dorado para volver a intentarlo.',
  );
  String brickField(int value) =>
      _text(en: 'Board $value', ru: 'Поле $value', es: 'Tablero $value');
  String get appLanguage => _text(
    en: 'App language',
    ru: 'Язык приложения',
    es: 'Idioma de la aplicación',
  );
  String get systemLanguage => _text(
    en: 'Device language',
    ru: 'Язык устройства',
    es: 'Idioma del dispositivo',
  );
  String get settingsSaveFailed => _text(
    en: 'Couldn’t save your preference. Try again.',
    ru: 'Не удалось сохранить настройку. Попробуй ещё раз.',
    es: 'No se pudo guardar el ajuste. Vuelve a intentarlo.',
  );
  String get reminderTime => _text(
    en: 'Reminder time',
    ru: 'Время напоминания',
    es: 'Hora del recordatorio',
  );
  String get cancel => _text(en: 'Cancel', ru: 'Отмена', es: 'Cancelar');
  String get save => _text(en: 'Save', ru: 'Сохранить', es: 'Guardar');
  String get hours => _text(en: 'Hour', ru: 'Часы', es: 'Hora');
  String get minutes => _text(en: 'Minute', ru: 'Минуты', es: 'Minutos');
  String get dailyReminder => _text(
    en: 'Daily reminder',
    ru: 'Ежедневное напоминание',
    es: 'Recordatorio diario',
  );
  String get time => _text(en: 'Time', ru: 'Время', es: 'Hora');
  String get gameSounds => _text(
    en: 'Game sounds',
    ru: 'Звуки в играх',
    es: 'Sonidos de los juegos',
  );
  String get notificationsDenied => _text(
    en: 'Notifications are blocked. You can allow them in your device settings.',
    ru:
        'Система не разрешила уведомления. Включить их можно в настройках телефона.',
    es:
        'Las notificaciones están bloqueadas. Puedes activarlas en los ajustes del dispositivo.',
  );
  String get licenses => _text(
    en: 'Full license texts',
    ru: 'Полные тексты лицензий',
    es: 'Textos completos de las licencias',
  );
  String get loadingSources => _text(
    en: 'Loading sources',
    ru: 'Загрузка источников',
    es: 'Cargando las fuentes',
  );
  String get sourcesLoadFailed => _text(
    en: 'Couldn’t load sources',
    ru: 'Источники не читаются',
    es: 'No se pudieron cargar las fuentes',
  );
  String get progressLoadFailed => _text(
    en: 'Couldn’t load progress',
    ru: 'Прогресс не загрузился',
    es: 'No se pudo cargar el progreso',
  );
  String get reopenProgress => _text(
    en: 'Close this screen and open it again.',
    ru: 'Попробуй открыть экран ещё раз.',
    es: 'Cierra esta pantalla y vuelve a abrirla.',
  );
  String get loadingProgress => _text(
    en: 'Loading progress',
    ru: 'Загрузка прогресса',
    es: 'Cargando el progreso',
  );
  String get personalDictionary =>
      _text(en: 'My Word List', ru: 'Личный словарь', es: 'Mi diccionario');
  String get customWords =>
      _text(en: 'My words', ru: 'Свои слова', es: 'Mis palabras');
  String get addWord =>
      _text(en: 'Add a word', ru: 'Добавить слово', es: 'Añadir palabra');
  String get playCustomWords => _text(
    en: 'Play with my words',
    ru: 'Играть со своими словами',
    es: 'Jugar con mis palabras',
  );
  String get noCustomWords => _text(
    en: 'Add a word or phrase to practise it in games.',
    ru: 'Добавь слово или фразу, чтобы потренироваться в играх.',
    es: 'Añade una palabra o frase para practicarla en los juegos.',
  );
  String customWordLabel(String tag) => _text(
    en: 'Word or phrase (${languageName(tag)})',
    ru: 'Слово или фраза (${languageName(tag).toLowerCase()})',
    es: 'Palabra o frase (${languageName(tag).toLowerCase()})',
  );
  String customTranslationLabel(String tag) => _text(
    en: 'Translation (${languageName(tag)})',
    ru: 'Перевод (${languageName(tag).toLowerCase()})',
    es: 'Traducción (${languageName(tag).toLowerCase()})',
  );
  String get enterWord => _text(
    en: 'Enter a word or phrase.',
    ru: 'Введи слово или фразу.',
    es: 'Escribe una palabra o frase.',
  );
  String get enterTranslation => _text(
    en: 'Enter a translation.',
    ru: 'Введи перевод.',
    es: 'Escribe una traducción.',
  );
  String get customWordNeedsLetter => _text(
    en: 'The word or phrase needs at least one letter.',
    ru: 'В слове или фразе должна быть хотя бы одна буква.',
    es: 'La palabra o frase debe contener al menos una letra.',
  );
  String get duplicateCustomWord => _text(
    en: 'You already have this word at this level.',
    ru: 'Это слово уже есть среди твоих слов на этом уровне.',
    es: 'Esta palabra ya está en tu lista de este nivel.',
  );
  String get customWordSaveFailed => _text(
    en: 'Couldn’t save this word. Try again.',
    ru: 'Не удалось сохранить слово. Попробуй ещё раз.',
    es: 'No se pudo guardar la palabra. Vuelve a intentarlo.',
  );
  String get firstRoundProgress => _text(
    en: 'Play your first round to see your progress here',
    ru: 'Сыграй первую партию, и здесь появится, сколько пройдено',
    es: 'Juega tu primera ronda para ver tu progreso aquí',
  );
  String get allTime =>
      _text(en: 'All time', ru: 'За всё время', es: 'Desde el inicio');
  String get words => _text(en: 'Words', ru: 'Слова', es: 'Palabras');
  String get learned => _text(en: 'Learned', ru: 'Выучено', es: 'Aprendidas');
  String get learning =>
      _text(en: 'Learning', ru: 'В работе', es: 'En práctica');
  String get hardWords =>
      _text(en: 'Difficult', ru: 'Трудные', es: 'Difíciles');
  String get twoWeeks =>
      _text(en: 'Two weeks', ru: 'Две недели', es: 'Dos semanas');
  String get answersByDay => _text(
    en: 'Answers by day',
    ru: 'Ответы по дням',
    es: 'Respuestas por día',
  );
  String get answers => _text(en: 'Answers', ru: 'Ответы', es: 'Respuestas');
  String get total => _text(en: 'Total', ru: 'Всего', es: 'Total');
  String get correctCount => _text(en: 'Correct', ru: 'Верных', es: 'Aciertos');
  String get days => _text(en: 'Days', ru: 'Дни', es: 'Días');
  String get daysWithAnswers =>
      _text(en: 'With answers', ru: 'С ответами', es: 'Con respuestas');
  String get bestStreak =>
      _text(en: 'Best streak', ru: 'Лучшая серия', es: 'Mejor racha');
  String get recentWords => _text(
    en: 'Recently seen',
    ru: 'Недавно встретил',
    es: 'Vistas recientemente',
  );
  String get noRecentWords => _text(
    en: 'Words you encounter will appear here',
    ru: 'Пока нет встреченных слов',
    es: 'Todavía no has visto ninguna palabra',
  );
  String get oftenMissed =>
      _text(en: 'Often missed', ru: 'Часто ошибаюсь', es: 'Errores frecuentes');
  String get noDifficultWords => _text(
    en: 'No frequently missed words yet',
    ru: 'Пока нет слов с частыми ошибками',
    es: 'Todavía no hay palabras en las que suelas fallar',
  );
  String get favorites =>
      _text(en: 'Favorites', ru: 'Избранное', es: 'Favoritas');
  String get noFavorites => _text(
    en: 'No favorites yet',
    ru: 'В избранном пока пусто',
    es: 'Todavía no tienes palabras favoritas',
  );
  String get wordListLoadFailed => _text(
    en: 'Couldn’t load your word list',
    ru: 'Словарь не загрузился',
    es: 'No se pudo cargar tu diccionario',
  );
  String get retry => _text(
    en: 'Try again',
    ru: 'Попробовать ещё раз',
    es: 'Volver a intentar',
  );
  String get loadingWordList => _text(
    en: 'Loading word list',
    ru: 'Загрузка словаря',
    es: 'Cargando el diccionario',
  );
  String get wordDetails => _text(
    en: 'Word details',
    ru: 'Карточка слова',
    es: 'Ficha de la palabra',
  );
  String get removeFavorite => _text(
    en: 'Remove from favorites',
    ru: 'Убрать из избранного',
    es: 'Quitar de favoritas',
  );
  String get addFavorite => _text(
    en: 'Add to favorites',
    ru: 'В избранное',
    es: 'Añadir a favoritas',
  );
  String get favoriteSaveFailed => _text(
    en: 'Couldn’t update your favorites. Try again.',
    ru: 'Не удалось сохранить избранное. Попробуй ещё раз.',
    es: 'No se pudo actualizar la lista de favoritas. Vuelve a intentarlo.',
  );
  String get answerHistory => _text(
    en: 'Answer history',
    ru: 'История ответов',
    es: 'Historial de respuestas',
  );
  String get correct => _text(en: 'Correct', ru: 'Верно', es: 'Correcto');
  String get mistake => _text(en: 'Incorrect', ru: 'Ошибка', es: 'Error');
  String get reviewMistakes => _text(
    en: 'Review mistakes',
    ru: 'Разбор ошибок',
    es: 'Revisión de errores',
  );
  String get wordPreview =>
      _text(en: 'Word preview', ru: 'Знакомство', es: 'Conoce las palabras');
  String get noMistakes => _text(
    en: 'No mistakes in this round',
    ru: 'В этом раунде нет ошибок',
    es: 'No hubo errores en esta ronda',
  );
  String get backToResults => _text(
    en: 'You can go back to the results.',
    ru: 'Можно вернуться к итогам.',
    es: 'Puedes volver a los resultados.',
  );
  String get yourAnswer =>
      _text(en: 'Your answer', ru: 'Твой ответ', es: 'Tu respuesta');
  String get timeUp =>
      _text(en: 'Time’s up', ru: 'Время вышло', es: 'Se acabó el tiempo');
  String get reviewWithoutTimer => _text(
    en: 'Review the words at your own pace.',
    ru: 'Повтори слова без таймера.',
    es: 'Repasa las palabras a tu ritmo.',
  );
  String get readAndListen => _text(
    en: 'Read the translation and listen to the word before playing.',
    ru: 'Прочитай перевод и послушай слово перед игрой.',
    es: 'Lee la traducción y escucha la palabra antes de jugar.',
  );
  String get next => _text(en: 'Next', ru: 'Дальше', es: 'Siguiente');
  String get startGame =>
      _text(en: 'Start game', ru: 'Начать игру', es: 'Empezar a jugar');
  String get back => _text(en: 'Back', ru: 'Назад', es: 'Atrás');
  String get done => _text(en: 'Done', ru: 'Готово', es: 'Listo');
  String get skipPreview =>
      _text(en: 'Skip to game', ru: 'Сразу в игру', es: 'Ir directo al juego');
  String get playAgain =>
      _text(en: 'Play again', ru: 'Ещё раз', es: 'Volver a jugar');
  String get exit => _text(en: 'Exit', ru: 'Выйти', es: 'Salir');
  String get nothingToday => _text(
    en: 'You’re all caught up',
    ru: 'На сегодня всё',
    es: 'Estás al día',
  );
  String get reviewsDone => _text(
    en: 'There are no words due for review. Come back tomorrow.',
    ru: 'Слова к повторению кончились. Возвращайся завтра.',
    es: 'No quedan palabras pendientes de repaso. Vuelve mañana.',
  );
  String get left =>
      _text(en: 'Move left', ru: 'Влево', es: 'Mover a la izquierda');
  String get right =>
      _text(en: 'Move right', ru: 'Вправо', es: 'Mover a la derecha');
  String get grab => _text(en: 'Grab', ru: 'Захватить', es: 'Atrapar');
  String get hint => _text(en: 'Hint', ru: 'Подсказка', es: 'Pista');
  String get roundComplete =>
      _text(en: 'Round complete', ru: 'Раунд окончен', es: 'Fin de la ronda');
  String get outOfLives => _text(
    en: 'Out of lives',
    ru: 'Жизни кончились',
    es: 'Te quedaste sin vidas',
  );
  String get wordsReady => _text(
    en: 'More words are ready. Play another round.',
    ru: 'Ещё есть слова — сыграй ещё раунд',
    es: 'Hay más palabras para practicar. Juega otra ronda.',
  );
  String get dailyWordsDone => _text(
    en: 'No more words for today',
    ru: 'Слова на сегодня кончились',
    es: 'No quedan más palabras por hoy',
  );
  String get comeBackTomorrow => _text(
    en: 'Come back tomorrow',
    ru: 'Возвращайся завтра',
    es: 'Vuelve mañana',
  );
  String get correctTranslation => _text(
    en: 'Correct translation',
    ru: 'Правильный перевод',
    es: 'Traducción correcta',
  );
  String get noun => _text(en: 'Noun', ru: 'Существительное', es: 'Sustantivo');
  String get verb => _text(en: 'Verb', ru: 'Глагол', es: 'Verbo');
  String get adjective =>
      _text(en: 'Adjective', ru: 'Прилагательное', es: 'Adjetivo');
  String get adverb => _text(en: 'Adverb', ru: 'Наречие', es: 'Adverbio');
  String get numeral => _text(en: 'Numeral', ru: 'Числительное', es: 'Numeral');
  String get pronoun =>
      _text(en: 'Pronoun', ru: 'Местоимение', es: 'Pronombre');
  String get preposition =>
      _text(en: 'Preposition', ru: 'Предлог', es: 'Preposición');
  String get conjunction =>
      _text(en: 'Conjunction', ru: 'Союз', es: 'Conjunción');
  String get interjection =>
      _text(en: 'Interjection', ru: 'Междометие', es: 'Interjección');
  String get determiner =>
      _text(en: 'Determiner', ru: 'Определитель', es: 'Determinante');
  String voiceUnavailable(String studyLanguage) => switch (studyLanguage) {
    'en' => _text(
      en:
          'English speech is unavailable. Check your device’s text-to-speech settings for a local English voice.',
      ru:
          'Английский голос недоступен. Проверь настройки синтеза речи на устройстве и установи английский голос.',
      es:
          'El audio en inglés no está disponible. Instala una voz en inglés en los ajustes de síntesis de voz del dispositivo.',
    ),
    'es' => _text(
      en:
          'Spanish speech is unavailable. Install a local Spanish voice in your device’s text-to-speech settings.',
      ru:
          'Испанский голос недоступен. Установи испанский голос в настройках синтеза речи устройства.',
      es:
          'El audio en español no está disponible. Instala una voz en español en los ajustes de síntesis de voz del dispositivo.',
    ),
    _ => _text(
      en:
          'Speech is unavailable. Install a voice for the course language in your device’s text-to-speech settings.',
      ru:
          'Озвучка недоступна. Установи голос для языка курса в настройках синтеза речи устройства.',
      es:
          'El audio no está disponible. Instala una voz en el idioma del curso en los ajustes de síntesis de voz del dispositivo.',
    ),
  };
  String get speechFailed => _text(
    en: 'Couldn’t play the pronunciation. Try again.',
    ru: 'Не удалось произнести слово. Попробуй ещё раз.',
    es: 'No se pudo reproducir la pronunciación. Vuelve a intentarlo.',
  );
  String get listen => _text(en: 'Listen', ru: 'Послушать', es: 'Escuchar');
  String get listenAgain =>
      _text(en: 'Listen again', ru: 'Ещё раз', es: 'Escuchar de nuevo');
  String get noStreak => _text(
    en: 'No streak yet',
    ru: 'Серии нет',
    es: 'Aún no tienes una racha',
  );
  String get startStreak => _text(
    en: 'Start your streak',
    ru: 'Начни свою серию',
    es: 'Empieza tu racha',
  );
  String get playedToday =>
      _text(en: 'Played today', ru: 'Сегодня сыграно', es: 'Ya jugaste hoy');
  String get notPlayedToday => _text(
    en: 'Not played today',
    ru: 'Сегодня ещё не сыграно',
    es: 'Aún no has jugado hoy',
  );
  String get continueStreak => _text(
    en: 'Keep your streak going',
    ru: 'Продолжить серию',
    es: 'Mantener la racha',
  );
  String get saveStreak =>
      _text(en: 'Save your streak', ru: 'Спасти серию', es: 'Salvar la racha');
  String get playAnotherRound => _text(
    en: 'Play another round',
    ru: 'Сыграть ещё раз',
    es: 'Jugar otra ronda',
  );
  String get freezeAvailable => _text(
    en: 'Streak Freeze available',
    ru: 'Заморозка в запасе',
    es: 'Protección de racha disponible',
  );
  String get playedDay => _text(en: 'played', ru: 'сыграно', es: 'día jugado');
  String get frozenDay =>
      _text(en: 'streak frozen', ru: 'заморозка', es: 'racha protegida');
  String get missedDay =>
      _text(en: 'missed', ru: 'пропущено', es: 'día sin jugar');
  String get pendingDay => _text(
    en: 'today, not played yet',
    ru: 'сегодня, ещё не сыграно',
    es: 'hoy, aún sin jugar',
  );
  String get futureDay =>
      _text(en: 'upcoming', ru: 'ещё не наступил', es: 'día próximo');
  String get reminderSavedByFreeze => _text(
    en: 'Play today. A Streak Freeze will cover the day you missed.',
    ru: 'Сыграй сегодня — заморозка прикроет вчерашний пропуск',
    es: 'Juega hoy. La protección de racha cubrirá el día que faltaste.',
  );
  String get oneRoundCounts => _text(
    en: 'One round is all it takes to count today.',
    ru: 'Одна партия — и день засчитан',
    es: 'Juega una ronda para sumar el día de hoy.',
  );
  String get timeToReturn => _text(
    en: 'Ready to play again?',
    ru: 'Пора вернуться',
    es: '¿Todo listo para volver a jugar?',
  );
  String get restartStreak => _text(
    en: 'Play one round to start a new streak.',
    ru: 'Одна партия, и серия начнётся заново',
    es: 'Juega una ronda para empezar una nueva racha.',
  );

  String courseName(StudyCourse course) {
    final study = languageName(course.studyLanguage);
    final translation = languageName(course.translationLanguage);
    return _text(
      en: '$study · $translation translations',
      ru: '$study · переводы на ${translation.toLowerCase()}',
      es: '$study · traducciones al ${translation.toLowerCase()}',
    );
  }

  String languageName(String tag) => switch (tag) {
    'en' => _text(en: 'English', ru: 'Английский', es: 'Inglés'),
    'ru' => _text(en: 'Russian', ru: 'Русский', es: 'Ruso'),
    'es' => _text(en: 'Spanish', ru: 'Испанский', es: 'Español'),
    _ => tag,
  };

  String levelOf(String tag) => _text(
    en: '${languageName(tag)} level',
    ru: switch (tag) {
      'en' => 'Уровень английского',
      'ru' => 'Уровень русского',
      'es' => 'Уровень испанского',
      _ => 'Уровень языка ($tag)',
    },
    es: 'Nivel de ${languageName(tag).toLowerCase()}',
  );

  String weekday(int weekday, String russianLabel) => _text(
    en: const ['Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat', 'Sun'][weekday - 1],
    ru: russianLabel,
    es: const ['lun', 'mar', 'mié', 'jue', 'vie', 'sáb', 'dom'][weekday - 1],
  );

  String noWordsForLevel(String level) => _text(
    en: 'No $level words in this course yet',
    ru: 'Для $level пока нет слов',
    es: 'Aún no hay palabras de nivel $level en este curso',
  );

  String level(String level) =>
      _text(en: 'Level $level', ru: 'Уровень $level', es: 'Nivel $level');

  String correctAnswers(int count, int total) => _text(
    en: 'Correct answers: $count of $total',
    ru: 'Верных ответов: $count из $total',
    es: 'Aciertos: $count de $total',
  );

  String reviewMistakesCount(int count) => _text(
    en: 'Review mistakes ($count)',
    ru: 'Разобрать ошибки ($count)',
    es: 'Revisar errores ($count)',
  );

  String score(int value) =>
      _text(en: 'Score: $value', ru: 'Счёт: $value', es: 'Puntos: $value');

  String bestCombo(int value) => _text(
    en: 'Best combo: $value',
    ru: 'Лучшая серия: $value',
    es: 'Mejor combo: $value',
  );

  String lives(int value, int total) => _text(
    en: 'Lives: $value of $total',
    ru: 'Жизни: $value из $total',
    es: 'Vidas: $value de $total',
  );

  String wordNumber(int index, int total) => _text(
    en: 'Word $index of $total',
    ru: 'Слово $index из $total',
    es: 'Palabra $index de $total',
  );

  String lettersCollected(int count, int total) => _text(
    en: 'Letters collected: $count of $total',
    ru: 'Собрано букв: $count из $total',
    es: 'Letras atrapadas: $count de $total',
  );

  String letterMiss(String letter) => _text(
    en: 'Letter $letter doesn’t fit',
    ru: 'Буква $letter не подошла',
    es: 'La letra $letter no encaja',
  );

  String capsule(String letter, {required bool hintShown}) => _text(
    en: hintShown ? 'Capsule $letter, hint' : 'Capsule $letter',
    ru: hintShown ? 'Капсула $letter, подсказка' : 'Капсула $letter',
    es:
        hintShown
            ? 'Cápsula con la letra $letter, pista'
            : 'Cápsula con la letra $letter',
  );

  String attemptCounts(int count, int mistakes) => _text(
    en: 'Attempts: $count · Mistakes: $mistakes',
    ru: 'Попыток: $count · Ошибок: $mistakes',
    es: 'Intentos: $count · Errores: $mistakes',
  );

  String answersForDay(String date, int count) => _text(
    en: '$date, $count ${count == 1 ? 'answer' : 'answers'}',
    ru: '$date, ответов $count',
    es: '$date, $count ${count == 1 ? 'respuesta' : 'respuestas'}',
  );

  String pronounce(String word) => _text(
    en: 'Pronounce $word',
    ru: 'Произнести $word',
    es: 'Pronunciar $word',
  );
}

class _AppStringsDelegate extends LocalizationsDelegate<AppStrings> {
  const _AppStringsDelegate();

  @override
  bool isSupported(Locale locale) =>
      InterfaceLanguage.fromTag(locale.languageCode) !=
      InterfaceLanguage.system;

  @override
  Future<AppStrings> load(Locale locale) => SynchronousFuture(
    AppStrings(InterfaceLanguage.fromTag(locale.languageCode)),
  );

  @override
  bool shouldReload(_AppStringsDelegate old) => false;
}

extension AppLocalization on BuildContext {
  AppStrings get strings => AppStrings.of(this);
}
