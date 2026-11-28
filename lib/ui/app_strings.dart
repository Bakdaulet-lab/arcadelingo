import 'package:arcadelingo/domain/challenges/challenge_session.dart';
import 'package:arcadelingo/domain/review/review_contract.dart';
import 'package:arcadelingo/domain/review/study_course.dart';
import 'package:arcadelingo/domain/settings/app_settings.dart';
import 'package:arcadelingo/domain/stories/situation_story.dart';
import 'package:arcadelingo/ui/campfire_stage.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';

part 'candy_delivery_strings.dart';
part 'space_word_strings.dart';

const russianStrings = AppStrings(InterfaceLanguage.russian);

/// Тексты ArcadeLingo. Язык курса задаёт данные карточки независимо от меню.
class AppStrings {
  const AppStrings(this.language);

  static const delegate = _AppStringsDelegate();
  static AppStrings of(BuildContext context) =>
      Localizations.of<AppStrings>(context, AppStrings) ?? russianStrings;

  final InterfaceLanguage language;
  bool get isRussian => language == InterfaceLanguage.russian;

  String _text({
    required String en,
    required String ru,
    required String es,
    required String kk,
  }) => switch (language) {
    InterfaceLanguage.english => en,
    InterfaceLanguage.spanish => es,
    InterfaceLanguage.kazakh => kk,
    InterfaceLanguage.russian || InterfaceLanguage.system => ru,
  };

  String confusionMeaningPrompt(
    String gloss, {
    required bool inMessage,
  }) => _text(
    en:
        inMessage
            ? 'How would you say “$gloss” in a message to a friend?'
            : 'You want to say “$gloss” in a conversation. Which word would you use?',
    ru:
        inMessage
            ? 'Как передать «$gloss» в сообщении другу?'
            : 'В разговоре ты хочешь сказать «$gloss». Какое слово подойдёт?',
    es:
        inMessage
            ? '¿Cómo dirías «$gloss» en un mensaje a un amigo?'
            : 'En una conversación quieres decir «$gloss». ¿Qué palabra usarías?',
    kk:
        inMessage
            ? 'Досыңа «$gloss» дегенді қалай жазар едің?'
            : 'Әңгімеде «$gloss» дегенді қалай айтасың?',
  );

  String get challenge =>
      _text(en: 'Challenge', ru: 'Испытание', es: 'Desafío', kk: 'Сынақ');

  String get dailyWord => _text(
    en: 'Word of the day',
    ru: 'Слово дня',
    es: 'Palabra del día',
    kk: 'Күн сөзі',
  );
  String get dailyWordHomeHint => _text(
    en: 'Guess today’s word in six tries.',
    ru: 'Угадай сегодняшнее слово за шесть попыток.',
    es: 'Adivina la palabra de hoy en seis intentos.',
    kk: 'Бүгінгі сөзді табуға алты әрекет берілген.',
  );
  String get dailyWordUnavailable => _text(
    en: 'Today’s word is unavailable for this course and level.',
    ru: 'Слово дня недоступно для этого курса и уровня.',
    es: 'La palabra de hoy no está disponible para este curso y nivel.',
    kk: 'Бұл курс пен деңгейде күн сөзі әзірге жоқ.',
  );
  String get dailyWordCopied => _text(
    en: 'Result copied to clipboard.',
    ru: 'Результат скопирован в буфер обмена.',
    es: 'Resultado copiado al portapapeles.',
    kk: 'Нәтиже алмасу буферіне көшірілді.',
  );
  String get dailyWordShareFailed => _text(
    en: 'Couldn’t share the result. Try again.',
    ru: 'Не удалось поделиться результатом. Попробуй ещё раз.',
    es: 'No se ha podido compartir el resultado. Inténtalo de nuevo.',
    kk: 'Нәтижемен бөлісу мүмкін болмады. Қайталап көр.',
  );
  String get dailyWordClue => _text(
    en: 'Translation',
    ru: 'Перевод',
    es: 'Traducción',
    kk: 'Аудармасы',
  );
  String dailyWordAttempt(int n, int total) => _text(
    en: 'Try $n of $total',
    ru: 'Попытка $n из $total',
    es: 'Intento $n de $total',
    kk: 'Әрекет $n/$total',
  );
  String get dailyWordExact => _text(
    en: 'Right spot',
    ru: 'На месте',
    es: 'En su lugar',
    kk: 'Дәл орнында',
  );
  String get dailyWordPresent => _text(
    en: 'Different spot',
    ru: 'В другом месте',
    es: 'En otro lugar',
    kk: 'Басқа орында',
  );
  String get dailyWordAbsent =>
      _text(en: 'Absent', ru: 'Нет в слове', es: 'No aparece', kk: 'Сөзде жоқ');
  String dailyWordEntry(int length) => _text(
    en: 'Enter a $length-letter word',
    ru: 'Введи слово из $length букв',
    es: 'Escribe una palabra de $length letras',
    kk: '$length әріптен тұратын сөз енгіз',
  );
  String dailyWordWrongLength(int length) => _text(
    en: 'Use exactly $length letters.',
    ru: 'Нужная длина слова — $length.',
    es: 'La palabra debe tener $length letras.',
    kk: 'Сөз дәл $length әріптен тұруы керек.',
  );
  String get dailyWordInvalidLetters => _text(
    en: 'Use letters from the language you’re learning.',
    ru: 'Используй буквы языка, который изучаешь.',
    es: 'Usa letras del idioma que estás aprendiendo.',
    kk: 'Үйреніп жүрген тілдің әріптерін қолдан.',
  );
  String get dailyWordUnknown => _text(
    en: 'Try a word from this course’s dictionary.',
    ru: 'Попробуй слово из словаря этого курса.',
    es: 'Prueba con una palabra del diccionario de este curso.',
    kk: 'Осы курстың сөздігіндегі бір сөзді енгізіп көр.',
  );
  String get dailyWordRepeated => _text(
    en: 'You’ve already tried that word.',
    ru: 'Это слово уже было.',
    es: 'Ya has probado esa palabra.',
    kk: 'Бұл сөзді енгізіп қойғансың.',
  );
  String get dailyWordSaveFailed => _text(
    en: 'Couldn’t save your guess. Try again.',
    ru: 'Не удалось сохранить попытку. Попробуй ещё раз.',
    es: 'No se ha podido guardar tu intento. Inténtalo de nuevo.',
    kk: 'Жауап сақталмады. Қайталап көр.',
  );
  String get dailyWordUpdated => _text(
    en: 'Another guess was saved. The board is up to date.',
    ru: 'За это время сохранился другой ход. Поле обновлено.',
    es: 'Se ha guardado otro intento. El tablero está actualizado.',
    kk: 'Осы арада басқа жауап сақталды. Ойын алаңы жаңартылды.',
  );
  String get dailyWordWon => _text(
    en: 'You found it!',
    ru: 'Слово угадано!',
    es: '¡Lo has adivinado!',
    kk: 'Сөзді таптың!',
  );
  String get dailyWordLost => _text(
    en: 'Out of guesses',
    ru: 'Попытки закончились',
    es: 'Se acabaron los intentos',
    kk: 'Әрекеттер таусылды',
  );
  String get dailyWordShare => _text(
    en: 'Share result',
    ru: 'Поделиться результатом',
    es: 'Compartir resultado',
    kk: 'Нәтижемен бөлісу',
  );

  String get situationStories => _text(
    en: 'On the way home',
    ru: 'Пока ехал домой',
    es: 'De camino a casa',
    kk: 'Үйге қайтар жолда',
  );

  String get orderKitchen => _text(
    en: 'Café Orders',
    ru: 'Кухня заказов',
    es: 'Pedidos de cafetería',
    kk: 'Кафедегі тапсырыстар',
  );
  String get orderKitchenHint => _text(
    en: 'Read each order and make the guest’s drink.',
    ru: 'Прочитай заказ и приготовь гостю напиток.',
    es: 'Lee cada pedido y prepara la bebida.',
    kk: 'Тапсырысты оқып, қонаққа сусын дайында.',
  );

  String get activeRecall => _text(
    en: 'Recall it',
    ru: 'Вспомни сам',
    es: 'Recuerda la palabra',
    kk: 'Сөзді еске түсір',
  );

  String get confusedWords => _text(
    en: 'Words I mix up',
    ru: 'Слова, которые я путаю',
    es: 'Palabras que confundo',
    kk: 'Шатастыратын сөздерім',
  );
  String get noConfusedPairs => _text(
    en: 'No repeated mix-ups yet',
    ru: 'Пока нет повторяющихся пар',
    es: 'Aún no hay confusiones repetidas',
    kk: 'Қайта шатастырған сөз жұптары әзірге жоқ',
  );
  String get confusionThreshold => _text(
    en:
        'A pair appears here when you choose one word instead of the other twice.',
    ru:
        'Пара появится здесь, когда ты дважды выберешь одно слово вместо другого.',
    es:
        'Aquí aparecerá una pareja cuando elijas dos veces una palabra en lugar de la otra.',
    kk:
        'Бір сөздің орнына екіншісін екі рет таңдасаң, сол жұп осы жерден көрінеді.',
  );
  String confusionCount(int count) => _text(
    en: 'Mix-ups: $count',
    ru: 'Ошибок с этой парой — $count',
    es: 'Confusiones: $count',
    kk: 'Бұл жұптағы қателер — $count',
  );
  String get practisePair => _text(
    en: 'Practise this pair',
    ru: 'Разобрать пару',
    es: 'Practicar esta pareja',
    kk: 'Осы жұпты қайталау',
  );
  String get completeSentence => _text(
    en: 'Complete the sentence',
    ru: 'Дополни фразу',
    es: 'Completa la frase',
    kk: 'Сөйлемді толықтыр',
  );
  String get pickByMeaning => _text(
    en: 'Choose the matching word',
    ru: 'Выбери слово по значению',
    es: 'Elige la palabra que corresponde',
    kk: 'Мағынасына сай сөзді таңда',
  );
  String get tryOtherWord => _text(
    en: 'Try the other word',
    ru: 'Попробуй другое слово',
    es: 'Prueba con la otra palabra',
    kk: 'Басқа сөзді таңдап көр',
  );
  String get pairComplete => _text(
    en: 'Pair practised',
    ru: 'Пара разобрана',
    es: 'Práctica completada',
    kk: 'Жұпты қайталап шықтың',
  );
  String confusionScore(int score, int total) => _text(
    en: 'Correct on the first try: $score of $total',
    ru: 'С первой попытки — $score из $total',
    es: 'A la primera: $score de $total',
    kk: 'Бірінші әрекеттегі дұрыс жауаптар — $score/$total',
  );
  String get backToPairs => _text(
    en: 'Back to word pairs',
    ru: 'К парам слов',
    es: 'Volver a las parejas',
    kk: 'Сөз жұптарына оралу',
  );

  String get recallHomeHint => _text(
    en: 'Recall the word, then spell it with letters',
    ru: 'Вспомни слово и собери его из букв',
    es: 'Recuerda la palabra y fórmala con letras',
    kk: 'Сөзді еске түсіріп, әріптерден құрастыр',
  );

  String recallPrompt(String tag) => _text(
    en: 'How do you say this in ${languageName(tag)}?',
    ru: switch (tag) {
      'en' => 'Как это сказать по-английски?',
      'es' => 'Как это сказать по-испански?',
      'ru' => 'Как это сказать по-русски?',
      _ => 'Как это сказать на изучаемом языке?',
    },
    es: '¿Cómo se dice en ${languageName(tag).toLowerCase()}?',
    kk: switch (tag) {
      'en' => 'Мұны ағылшынша қалай айтады?',
      'es' => 'Мұны испанша қалай айтады?',
      'ru' => 'Мұны орысша қалай айтады?',
      _ => 'Мұны үйреніп жүрген тіліңде қалай айтады?',
    },
  );

  String get recallSpell => _text(
    en: 'Spell the word',
    ru: 'Собрать слово',
    es: 'Formar la palabra',
    kk: 'Сөзді құрастыру',
  );
  String get recallOptions => _text(
    en: 'Show choices',
    ru: 'Показать варианты',
    es: 'Ver opciones',
    kk: 'Нұсқаларды көрсету',
  );
  String get recallCheck =>
      _text(en: 'Check', ru: 'Проверить', es: 'Comprobar', kk: 'Тексеру');
  String get recallUndo => _text(
    en: 'Remove last letter',
    ru: 'Убрать последнюю букву',
    es: 'Quitar la última letra',
    kk: 'Соңғы әріпті өшіру',
  );
  String get recallChoicesPrompt => _text(
    en: 'Choose the word',
    ru: 'Выбери слово',
    es: 'Elige la palabra',
    kk: 'Сөзді таңда',
  );
  String get recallRightWord => _text(
    en: 'The word to remember',
    ru: 'Слово для повторения',
    es: 'La palabra para repasar',
    kk: 'Қайталауға арналған сөз',
  );
  String get recallIndependent => _text(
    en: 'Recalled unaided',
    ru: 'Без подсказки',
    es: 'Sin ayuda',
    kk: 'Көмексіз',
  );
  String get recallWithHelp => _text(
    en: 'Recognised from choices',
    ru: 'С подсказкой',
    es: 'Con opciones',
    kk: 'Нұсқалардың көмегімен',
  );
  String get recallMistakes => _text(
    en: 'To practise again',
    ru: 'На повторение',
    es: 'Para repasar',
    kk: 'Қайталау керек',
  );
  String get recallResults => _text(
    en: 'See results',
    ru: 'Посмотреть итоги',
    es: 'Ver resultados',
    kk: 'Нәтижелерді көру',
  );

  String get storyHomeHint => _text(
    en: 'Two short games and a real-life task',
    ru: 'Две короткие игры и задача из жизни',
    es: 'Dos juegos cortos y una tarea de la vida diaria',
    kk: 'Екі қысқа ойын және өмірден алынған тапсырма',
  );

  String get chooseSituation => _text(
    en: 'Choose a situation',
    ru: 'Выбери ситуацию',
    es: 'Elige una situación',
    kk: 'Жағдайды таңда',
  );

  String storyTitle(StorySituation situation) => switch (situation) {
    StorySituation.breakfast => _text(
      en: 'Order breakfast',
      ru: 'Заказать завтрак',
      es: 'Pedir el desayuno',
      kk: 'Таңғы асқа тапсырыс беру',
    ),
    StorySituation.hotel => _text(
      en: 'Check in at a hotel',
      ru: 'Заселиться в отель',
      es: 'Registrarse en un hotel',
      kk: 'Қонақүйге орналасу',
    ),
    StorySituation.station => _text(
      en: 'Find your train',
      ru: 'Найти свой поезд',
      es: 'Encontrar tu tren',
      kk: 'Пойызыңды табу',
    ),
  };

  String storyRound(int round) => _text(
    en: 'Game $round of 2',
    ru: 'Игра $round из 2',
    es: 'Juego $round de 2',
    kk: '$round-ойын · барлығы 2',
  );

  String get startStoryRound => _text(
    en: 'Start game',
    ru: 'Начать игру',
    es: 'Empezar el juego',
    kk: 'Ойынды бастау',
  );

  String get storyRoundInterrupted => _text(
    en: 'Finish this round to continue.',
    ru: 'Чтобы продолжить, доиграй этот раунд.',
    es: 'Termina esta ronda para continuar.',
    kk: 'Жалғастыру үшін осы раундты аяқта.',
  );

  String get storyFinal => _text(
    en: 'Final task',
    ru: 'Финальное задание',
    es: 'Tarea final',
    kk: 'Қорытынды тапсырма',
  );

  String get tryStoryAnswerAgain => _text(
    en: 'Read the message again and try another answer.',
    ru: 'Прочитай фразу ещё раз и выбери другой ответ.',
    es: 'Vuelve a leer el mensaje y prueba con otra respuesta.',
    kk: 'Хабарламаны қайта оқып, басқа жауапты таңда.',
  );

  String get storyComplete => _text(
    en: 'Situation complete',
    ru: 'Ситуация пройдена',
    es: 'Situación completada',
    kk: 'Тапсырманы орындадың',
  );

  String get backToSituations => _text(
    en: 'Back to situations',
    ru: 'К ситуациям',
    es: 'Volver a las situaciones',
    kk: 'Жағдайлар тізіміне оралу',
  );

  String challengeName(ArcadeChallenge mode) => switch (mode) {
    ArcadeChallenge.continuous => continuousMode,
    ArcadeChallenge.sprint => _text(
      en: '60-second sprint',
      ru: '60 секунд',
      es: 'Esprint de 60 segundos',
      kk: '60 секундтық жарыс',
    ),
    ArcadeChallenge.streak => _text(
      en: 'Eight in a row',
      ru: 'Восемь точных ударов',
      es: 'Ocho cortes seguidos',
      kk: 'Сегіз дәл соққы',
    ),
    ArcadeChallenge.claw => _text(
      en: 'Three words, one hint',
      ru: 'Три слова, одна подсказка',
      es: 'Tres palabras, una pista',
      kk: 'Үш сөз, бір көмек',
    ),
    ArcadeChallenge.brick => _text(
      en: 'Three Golden Bricks',
      ru: 'Три золотых кирпича',
      es: 'Tres bloques dorados',
      kk: 'Үш алтын кірпіш',
    ),
  };

  String challengeRules(ArcadeChallenge mode) => switch (mode) {
    ArcadeChallenge.continuous => _text(
      en:
          'A new word appears after every answer. Keep playing for a high score, or pause to finish your run.',
      ru:
          'После каждого ответа сразу появляется новое слово. Набирай очки, пока хочется играть. Завершить партию можно на паузе.',
      es:
          'Después de cada respuesta aparece otra palabra. Sigue sumando puntos o pausa el juego para terminar la partida.',
      kk:
          'Әр жауаптан кейін бірден жаңа сөз шығады. Ұпай жинай бер. Ойынды аяқтау үшін кідіріс мәзірін аш.',
    ),
    ArcadeChallenge.sprint => _text(
      en:
          'Score as many points as you can in 60 seconds. A wrong or missed answer costs 5 seconds.',
      ru:
          'Набери как можно больше очков за 60 секунд. Промах или таймаут отнимает 5 секунд.',
      es:
          'Consigue todos los puntos que puedas en 60 segundos. Cada fallo o respuesta fuera de tiempo resta 5 segundos.',
      kk:
          '60 секундта мүмкіндігінше көп ұпай жина. Қателессең немесе жауап беріп үлгермесең, 5 секунд шегеріледі.',
    ),
    ArcadeChallenge.streak => _text(
      en:
          'Make eight correct cuts in a row. A miss resets the streak and costs a life. Your record is your longest streak.',
      ru:
          'Сделай восемь точных ударов подряд. Промах сбрасывает серию и отнимает жизнь. В рекорд идёт самая длинная серия.',
      es:
          'Haz ocho cortes correctos seguidos. Cada fallo reinicia la racha y cuesta una vida. Tu récord es la racha más larga.',
      kk:
          'Қатарынан сегіз рет дәл соқ. Мүлт кетсең, серия үзіліп, бір өмірден айырыласың. Ең ұзақ серияң рекорд болады.',
    ),
    ArcadeChallenge.claw => _text(
      en:
          'Spell three words with one hint for the whole round. Your record counts words spelled without a wrong grab.',
      ru:
          'Собери три слова. На весь раунд есть одна подсказка. В рекорд идут слова, собранные без ошибочных захватов.',
      es:
          'Forma tres palabras con una sola pista para toda la ronda. Para el récord cuentan las palabras completadas sin atrapar letras equivocadas.',
      kk:
          'Үш сөз құрастыр. Раунд бойы бір рет қана көмек аласың. Рекордқа қате әріп алмай құрастырған сөздерің кіреді.',
    ),
    ArcadeChallenge.brick => _text(
      en:
          'Break three golden bricks with one life. Each brick earns points. A correct translation gives you three balls. Letting all choices fall spends one chance. Your score counts toward the record.',
      ru:
          'Разбей три золотых кирпича за одну жизнь. Кирпичи приносят очки, а верный перевод даёт три мяча. Если все варианты упали, попытка расходуется. В рекорд идёт счёт партии.',
      es:
          'Rompe tres bloques dorados con una sola vida. Cada bloque da puntos y cada traducción correcta te da tres bolas. Si dejas caer todas las opciones, gastas un intento. Tu puntuación cuenta para el récord.',
      kk:
          'Бір өмірмен үш алтын кірпішті сындыр. Әр кірпіш ұпай береді, дұрыс аударма үш доп береді. Барлық нұсқа түсіп кетсе, бір мүмкіндігің кетеді. Раунд ұпайы рекордқа есептеледі.',
    ),
  };

  String challengeBest(int? best) =>
      best == null
          ? _text(
            en: 'No record yet',
            ru: 'Рекорда пока нет',
            es: 'Todavía no hay récord',
            kk: 'Әзірге рекорд жоқ',
          )
          : _text(
            en: 'Personal best: $best',
            ru: 'Личный рекорд: $best',
            es: 'Récord personal: $best',
            kk: 'Жеке рекорд — $best',
          );

  String get savingChallenge => _text(
    en: 'Saving result…',
    ru: 'Сохраняем результат…',
    es: 'Guardando el resultado…',
    kk: 'Нәтиже сақталып жатыр…',
  );

  String get challengeSaveFailed => _text(
    en: 'Couldn’t save the result',
    ru: 'Не удалось сохранить результат',
    es: 'No se pudo guardar el resultado',
    kk: 'Нәтижені сақтау мүмкін болмады',
  );

  String sprintTime(int seconds) => _text(
    en: 'Time left: $seconds s',
    ru: 'Осталось $seconds с',
    es: 'Quedan $seconds s',
    kk: '$seconds секунд қалды',
  );

  String challengeStreak(int hits, int target) => _text(
    en: 'Streak: $hits/$target',
    ru: 'Серия: $hits/$target',
    es: 'Racha: $hits/$target',
    kk: 'Серия — $hits/$target',
  );

  String challengeHints(int count) => _text(
    en: 'Hints left: $count',
    ru: 'Подсказок осталось: $count',
    es: 'Pistas restantes: $count',
    kk: 'Көмек — $count қалды',
  );

  String get sources =>
      _text(en: 'Sources', ru: 'Источники', es: 'Fuentes', kk: 'Дереккөздер');
  String get chooseGame => _text(
    en: 'Choose a game',
    ru: 'Выбери игру',
    es: 'Elige un juego',
    kk: 'Ойын таңда',
  );
  String get learnAndPlay => _text(
    en: 'Preview words and play',
    ru: 'Знакомство и игра',
    es: 'Aprende las palabras y juega',
    kk: 'Сөздермен танысып, ойнау',
  );
  String get play => _text(en: 'Play', ru: 'Играть', es: 'Jugar', kk: 'Ойнау');
  String get games =>
      _text(en: 'Games', ru: 'Игры', es: 'Juegos', kk: 'Ойындар');
  String get progress =>
      _text(en: 'Progress', ru: 'Прогресс', es: 'Progreso', kk: 'Ілгерілеу');
  String get settings =>
      _text(en: 'Settings', ru: 'Настройки', es: 'Ajustes', kk: 'Баптаулар');
  String get appearance =>
      _text(en: 'Theme', ru: 'Тема', es: 'Tema', kk: 'Көрініс');
  String get lightTheme =>
      _text(en: 'Light', ru: 'Светлая', es: 'Claro', kk: 'Ашық');
  String get darkTheme =>
      _text(en: 'Dark', ru: 'Тёмная', es: 'Oscuro', kk: 'Қараңғы');
  String get progressUnreadable => _text(
    en: 'Unable to read progress',
    ru: 'Прогресс не читается',
    es: 'No se pudo leer el progreso',
    kk: 'Ілгерілеу деректерін оқу мүмкін болмады',
  );
  String get resetHint => _text(
    en: 'Resetting starts your word practice over.',
    ru: 'После сброса слова начнутся заново, как при первом запуске.',
    es:
        'Si restableces el progreso, volverás a practicar las palabras desde el principio.',
    kk: 'Ілгерілеуді өшірсең, сөздерді басынан қайталайсың.',
  );
  String get resetProgress => _text(
    en: 'Reset progress',
    ru: 'Сбросить прогресс',
    es: 'Restablecer progreso',
    kk: 'Ілгерілеуді өшіру',
  );
  String get dictionaryUnreadable => _text(
    en: 'Unable to read the course dictionary',
    ru: 'Словарь не читается',
    es: 'No se pudo leer el diccionario del curso',
    kk: 'Курс сөздігін оқу мүмкін болмады',
  );
  String get dictionaryRepairHint => _text(
    en: 'The course data in this version is invalid. Please update the app.',
    ru: 'Это дефект сборки: сбрасывать нечего, поможет только обновление.',
    es:
        'Los datos del curso de esta versión presentan un error. Actualiza la aplicación.',
    kk: 'Бұл нұсқада курс деректерінде қате бар. Қолданбаны жаңарт.',
  );
  String get fallingWords => _text(
    en: 'Falling Words',
    ru: 'Падающие слова',
    es: 'Palabras que caen',
    kk: 'Құлайтын сөздер',
  );
  String get listeningMode =>
      _text(en: 'Listening', ru: 'На слух', es: 'De oído', kk: 'Тыңдап тану');
  String get listeningModeHint => _text(
    en: 'Listen and choose the translation in Falling Words',
    ru: 'Послушай слово и выбери перевод в «Падающих словах»',
    es: 'Escucha y elige la traducción en Palabras que caen',
    kk: 'Сөзді тыңдап, «Құлайтын сөздер» ойынында аудармасын таңда',
  );
  String get listenToWord => _text(
    en: 'Listen to the word',
    ru: 'Слушай слово',
    es: 'Escucha la palabra',
    kk: 'Сөзді тыңда',
  );
  String get chooseListeningTranslation => _text(
    en: 'Choose the translation',
    ru: 'Выбери перевод',
    es: 'Elige la traducción',
    kk: 'Аудармасын таңда',
  );
  String get listeningChoicesAfterAudio => _text(
    en: 'The translations will appear when the word finishes playing.',
    ru: 'Когда слово прозвучит, появятся варианты перевода.',
    es: 'Las traducciones aparecerán cuando termines de oír la palabra.',
    kk: 'Сөз айтылып болғанда, аударма нұсқалары шығады.',
  );
  String get replayWord => _text(
    en: 'Listen again',
    ru: 'Прослушать снова',
    es: 'Escuchar de nuevo',
    kk: 'Қайта тыңдау',
  );
  String get useWrittenWords => _text(
    en: 'Play with written words',
    ru: 'Играть с текстом',
    es: 'Jugar con palabras escritas',
    kk: 'Мәтінмен ойнау',
  );
  String get fallingInstruction => _text(
    en: 'Tap the correct translation',
    ru: 'Нажми на верный перевод',
    es: 'Toca la traducción correcta',
    kk: 'Дұрыс аударманы түрт',
  );
  String get ninjaSlash => _text(
    en: 'Ninja Slash',
    ru: 'Ниндзя-слэш',
    es: 'Corte ninja',
    kk: 'Ниндзяның соққысы',
  );
  String get ninjaInstruction => _text(
    en: 'Swipe through the correct translation',
    ru: 'Разрежь правильный перевод',
    es: 'Desliza el dedo para cortar la traducción correcta',
    kk: 'Дұрыс аударманы саусағыңмен сырғытып кес',
  );
  String get clawMachine => _text(
    en: 'Claw Machine',
    ru: 'Автомат с клешнёй',
    es: 'Máquina de garra',
    kk: 'Қысқышы бар автомат',
  );
  String get clawInstruction => _text(
    en: 'Collect letters to spell the word',
    ru: 'Собери слово из букв',
    es: 'Atrapa letras para formar la palabra',
    kk: 'Әріптерді ұстап, сөз құрастыр',
  );

  String get chooseCourse => _text(
    en: 'Choose a course',
    ru: 'Выбери курс',
    es: 'Elige un curso',
    kk: 'Курсты таңда',
  );
  String get brickBreaker => _text(
    en: 'Brick Breaker',
    ru: 'Арканоид',
    es: 'Rompebloques',
    kk: 'Кірпіш бұзу',
  );
  String get matchThree => _text(
    en: 'Match Three',
    ru: 'Три в ряд',
    es: 'Combina tres',
    kk: 'Үштік',
  );
  String get matchInstruction => _text(
    en: 'Match gems to unlock word bonuses',
    ru: 'Собирай кристаллы и открывай словесные бонусы',
    es: 'Combina gemas para activar bonos de vocabulario',
    kk: 'Кристалдарды қатар тізіп, сөз бонустарын аш',
  );
  String get matchGuide => _text(
    en: 'Slide the highlighted gem down to make a match of four.',
    ru: 'Сдвинь выделенный кристалл вниз, чтобы собрать четыре в ряд.',
    es: 'Desliza la gema resaltada hacia abajo para alinear cuatro gemas.',
    kk: 'Төрт кристалды қатар тізу үшін белгіленген кристалды төмен сырғыт.',
  );
  String get matchHint => _text(
    en:
        'Three matches charge a word crystal. Four gems in a line charge it instantly.',
    ru:
        'Три совпадения заряжают кристалл слова. Четыре в ряд дают полный заряд сразу.',
    es:
        'Con tres combinaciones desbloqueas una palabra. Una línea de cuatro la desbloquea al instante.',
    kk:
        'Үш қатар құрастырсаң, сөз кристалы қуаттанады. Төрт кристалды бір қатарға тізсең, ол бірден толады.',
  );
  String get matchInvalidMove => _text(
    en: 'Try another swap. That move was free.',
    ru: 'Попробуй другой обмен. Ход сохранился.',
    es: 'Prueba otro intercambio. Conservas el movimiento.',
    kk: 'Басқа кристалдардың орнын ауыстырып көр. Бұл жүріс есептелмеді.',
  );
  String get matchBonus => _text(
    en: 'Translate to clear a row',
    ru: 'Переведи слово, чтобы очистить ряд',
    es: 'Traduce para despejar una fila',
    kk: 'Қатарды тазарту үшін сөзді аудар',
  );
  String get matchCrossBonus => _text(
    en: 'Translate to clear a row and a column',
    ru: 'Переведи слово, чтобы очистить ряд и столбец',
    es: 'Traduce para despejar una fila y una columna',
    kk: 'Қатар мен бағанды тазарту үшін сөзді аудар',
  );
  String get matchRowBurst => _text(
    en: 'Row blast · +60',
    ru: 'Разряд по ряду · +60',
    es: 'Descarga en fila · +60',
    kk: 'Қатар тазартылды · +60',
  );
  String get matchCrossBurst => _text(
    en: 'Cross blast · +60',
    ru: 'Крестовой разряд · +60',
    es: 'Descarga en cruz · +60',
    kk: 'Қатар мен баған тазартылды · +60',
  );
  String get matchChargeLabel => _text(
    en: 'Word charge',
    ru: 'Заряд слова',
    es: 'Carga de la gema',
    kk: 'Сөз қуаты',
  );
  String get matchScoreLabel =>
      _text(en: 'Score', ru: 'Очки', es: 'Puntos', kk: 'Ұпай');
  String get matchMovesLabel =>
      _text(en: 'Moves', ru: 'Ходы', es: 'Movimientos', kk: 'Жүрістер');
  String get matchLastCharge => _text(
    en: 'One more match unlocks a word.',
    ru: 'Ещё одно совпадение откроет слово.',
    es: 'Una combinación más desbloquea una palabra.',
    kk: 'Тағы бір қатар құрастырсаң, сөз ашылады.',
  );
  String get matchHowTo => _text(
    en: 'How to play',
    ru: 'Как играть',
    es: 'Cómo jugar',
    kk: 'Ойын ережесі',
  );
  String get matchSwapRule => _text(
    en: 'Swipe a gem or tap two neighbors to line up three of the same shape.',
    ru:
        'Сдвинь кристалл или нажми на два соседних, чтобы выстроить три одинаковых в ряд.',
    es:
        'Desliza una gema o toca dos gemas vecinas para alinear tres de la misma forma.',
    kk:
        'Пішіні бірдей үш кристалды қатар тізу үшін бір кристалды сырғыт немесе көршілес екі кристалды түрт.',
  );
  String get matchCrossRule => _text(
    en:
        'A line of five or a T or L shape earns a cross. Translate the word to clear both a row and a column.',
    ru:
        'Пять в ряд или фигура в форме T или L дают крестовой разряд. Верный перевод очистит и ряд, и столбец.',
    es:
        'Una línea de cinco o una figura en T o en L forma una cruz. Acierta la traducción para despejar una fila y una columna.',
    kk:
        'Бес кристалды қатар немесе T не L пішінінде тізсең, айқас разряд пайда болады. Сөзді дұрыс аударсаң, қатар да, баған да тазарады.',
  );
  String matchCascade(int multiplier) => _text(
    en: 'Cascade · points ×$multiplier',
    ru: 'Каскад · очки ×$multiplier',
    es: 'Cascada · puntos ×$multiplier',
    kk: 'Каскад · ұпай ×$multiplier',
  );
  String matchGem(int kind, int row, int column) {
    final names = _text(
      en:
          'cyan diamond,pink sphere,amber hexagon,lilac crystal,mint square,blue triangle,charged gem',
      ru:
          'голубой ромб,розовая сфера,янтарный шестигранник,лиловый кристалл,мятный квадрат,синий треугольник,заряженная фишка',
      es:
          'rombo turquesa,esfera rosa,hexágono ámbar,cristal lila,cuadrado verde,triángulo azul,gema cargada',
      kk:
          'көгілдір ромб,қызғылт шар,кәріптас түсті алтыбұрыш,ашық күлгін кристалл,жалбыз түсті шаршы,көк үшбұрыш,қуатталған кристалл',
    ).split(',');
    final name =
        kind < 0
            ? _text(
              en: 'empty cell',
              ru: 'пустая клетка',
              es: 'casilla vacía',
              kk: 'бос ұяшық',
            )
            : names[kind];
    return _text(
      en: '$name, row $row, column $column',
      ru: '$name, ряд $row, столбец $column',
      es: '$name, fila $row, columna $column',
      kk: '$name, $row-қатар, $column-баған',
    );
  }

  String get wordMahjong => _text(
    en: 'Word Mahjong',
    ru: 'Маджонг со словами',
    es: 'Mahjong de palabras',
    kk: 'Сөз маджонгы',
  );
  String get mahjongInstruction => _text(
    en: 'Match each word with its translation',
    ru: 'Снимай пары из слова и его перевода',
    es: 'Empareja cada palabra con su traducción',
    kk: 'Әр сөзді өз аудармасымен жұптастыр',
  );
  String get mahjongRules => _text(
    en:
        'Match a word with its translation. Each tile must be uncovered and have a free side.',
    ru:
        'Соедини слово и перевод. Плитка должна быть открыта сверху и свободна хотя бы с одной стороны.',
    es:
        'Une una palabra con su traducción. Cada ficha debe estar descubierta y tener un lado libre.',
    kk:
        'Сөз бен аудармасын жұптастыр. Тақташаның үсті ашық, кемінде бір жағы бос болуы керек.',
  );
  String get mahjongMismatch => _text(
    en: 'These tiles do not match. Try again.',
    ru: 'Эти плитки не совпадают. Попробуй ещё раз.',
    es: 'Estas fichas no forman pareja. Inténtalo de nuevo.',
    kk: 'Бұл тақташалар жұп болмайды. Қайта байқап көр.',
  );
  String get mahjongHintShown => _text(
    en: 'Tap both highlighted tiles to remove the pair.',
    ru: 'Нажми на обе подсвеченные плитки, чтобы снять пару.',
    es: 'Toca las dos fichas resaltadas para retirar la pareja.',
    kk: 'Жұпты алып тастау үшін белгіленген екі тақташаны да түрт.',
  );
  String get mahjongWord =>
      _text(en: 'word', ru: 'слово', es: 'palabra', kk: 'сөз');
  String get mahjongTranslation =>
      _text(en: 'translation', ru: 'перевод', es: 'traducción', kk: 'аударма');
  String mahjongPairs(int count, int total) => _text(
    en: 'Pairs: $count / $total',
    ru: 'Пары: $count / $total',
    es: 'Parejas: $count / $total',
    kk: 'Жұптар: $count / $total',
  );

  String get snake =>
      _text(en: 'Snake', ru: 'Змейка', es: 'Serpiente', kk: 'Жылан');
  String get continuousMode => _text(
    en: 'Endless play',
    ru: 'Непрерывная игра',
    es: 'Juego sin fin',
    kk: 'Шексіз ойын',
  );
  String continuousProgress(int number) => _text(
    en: 'Word $number',
    ru: 'Слово $number',
    es: 'Palabra $number',
    kk: '$number-сөз',
  );
  String get finishRun => _text(
    en: 'Finish run',
    ru: 'Завершить партию',
    es: 'Terminar partida',
    kk: 'Ойынды аяқтау',
  );
  String get snakeObstacle => _text(
    en: 'The snake hit a rock.',
    ru: 'Змейка врезалась в камень.',
    es: 'La serpiente chocó con una roca.',
    kk: 'Жылан тасқа соғылды.',
  );
  String get snakeContinuousGuide => _text(
    en:
        'Swipe to steer around rocks. The snake gets faster as you collect words.',
    ru:
        'Обводи камни свайпом. Чем больше слов поймаешь, тем быстрее ползёт змейка.',
    es:
        'Desliza el dedo para esquivar las rocas. La serpiente acelera a medida que recoges palabras.',
    kk:
        'Тастарды айналып өту үшін саусағыңды сырғыт. Сөз жинаған сайын жылан жылдамдайды.',
  );
  String get wordMaze => _text(
    en: 'Word maze',
    ru: 'Лабиринт',
    es: 'Laberinto de palabras',
    kk: 'Сөз лабиринті',
  );
  String get mazeInstruction => _text(
    en: 'Dodge the ghosts and reach the gate with the right word',
    ru: 'Обойди привидений и найди ворота с нужным словом',
    es: 'Esquiva a los fantasmas y llega a la puerta con la palabra correcta',
    kk: 'Елестерді айналып өтіп, дұрыс сөз жазылған қақпаға жет',
  );
  String get mazeBoard => _text(
    en: 'Maze with word gates',
    ru: 'Лабиринт с воротами',
    es: 'Laberinto con puertas',
    kk: 'Сөз жазылған қақпалары бар лабиринт',
  );
  String get mazeSteering => _text(
    en: 'Swipe to steer. You can turn before a corner.',
    ru: 'Веди пальцем по полю. Поворот можно задать заранее.',
    es:
        'Desliza el dedo para girar. Puedes indicar el giro antes de llegar a la esquina.',
    kk: 'Бағытты саусағыңмен басқар. Бұрылысқа жетпей-ақ бағытты өзгерте аласың.',
  );
  String get mazeReadyGuide => _text(
    en:
        'Swipe toward the gate with the right word. Collect dots and dodge the ghosts.',
    ru:
        'Веди пальцем к воротам с нужным словом. Собирай точки и обходи привидений.',
    es:
        'Desliza el dedo hacia la puerta con la palabra correcta. Recoge los puntos y esquiva a los fantasmas.',
    kk:
        'Дұрыс сөз жазылған қақпаға қарай саусағыңды сырғыт. Нүктелерді жинап, елестерді айналып өт.',
  );
  String get mazeContinueSwipe => _text(
    en: 'Swipe the board to keep playing.',
    ru: 'Проведи по полю, чтобы продолжить.',
    es: 'Desliza el dedo por el tablero para seguir.',
    kk: 'Жалғастыру үшін ойын алаңында саусағыңды сырғыт.',
  );
  String get mazeCaught => _text(
    en: 'A ghost caught you',
    ru: 'Привидение тебя поймало',
    es: 'Te ha atrapado un fantasma',
    kk: 'Елес сені ұстап алды',
  );
  String get mazeTryAgain => _text(
    en: 'Try another route',
    ru: 'Попробовать другой путь',
    es: 'Probar otro camino',
    kk: 'Басқа жолды байқап көру',
  );
  String mazeProgress(int number, int total) => _text(
    en: 'Word $number of $total',
    ru: 'Слово $number из $total',
    es: 'Palabra $number de $total',
    kk: 'Сөз $number/$total',
  );
  String get snakeInstruction => _text(
    en: 'Catch the apple with the right translation',
    ru: 'Поймай яблоко с нужным переводом',
    es: 'Atrapa la manzana con la traducción correcta',
    kk: 'Дұрыс аударма жазылған алманы ұста',
  );
  String get snakePrompt => _text(
    en: 'Find the translation',
    ru: 'Найди перевод',
    es: 'Busca la traducción',
    kk: 'Аудармасын тап',
  );
  String get snakeGuide => _text(
    en: 'Swipe to steer around rocks. Keep your finger down to turn again.',
    ru:
        'Обходи камни. Чтобы повернуть ещё раз, смени направление, не отрывая пальца.',
    es:
        'Esquiva las rocas deslizando el dedo. Para volver a girar, cambia de dirección sin levantarlo.',
    kk:
        'Тастарды айналып өт. Қайта бұрылу үшін саусағыңды экраннан алмай, бағытыңды өзгерт.',
  );
  String get snakeBoard => _text(
    en: 'Snake board',
    ru: 'Поле змейки',
    es: 'Tablero de la serpiente',
    kk: 'Жыланның ойын алаңы',
  );
  String get snakeStart => _text(
    en: 'Start moving',
    ru: 'Начать движение',
    es: 'Empezar a moverse',
    kk: 'Қозғалысты бастау',
  );
  String get snakePause =>
      _text(en: 'Pause', ru: 'Пауза', es: 'Pausa', kk: 'Кідірту');
  String get snakeResume =>
      _text(en: 'Resume', ru: 'Продолжить', es: 'Continuar', kk: 'Жалғастыру');
  String get snakeResults =>
      _text(en: 'Results', ru: 'Итоги', es: 'Resultados', kk: 'Нәтижелер');
  String get snakeTail => _text(
    en: 'The snake ran into its tail.',
    ru: 'Змейка коснулась хвоста.',
    es: 'La serpiente chocó con su cola.',
    kk: 'Жылан өз құйрығына соғылды.',
  );
  String get snakeLeft =>
      _text(en: 'Left', ru: 'Влево', es: 'Izquierda', kk: 'Солға');
  String get snakeUp =>
      _text(en: 'Up', ru: 'Вверх', es: 'Arriba', kk: 'Жоғары');
  String get snakeDown =>
      _text(en: 'Down', ru: 'Вниз', es: 'Abajo', kk: 'Төмен');
  String get snakeRight =>
      _text(en: 'Right', ru: 'Вправо', es: 'Derecha', kk: 'Оңға');
  String snakeCount(int count, int total) => _text(
    en: 'Correct $count/$total',
    ru: 'Верно $count/$total',
    es: 'Aciertos $count/$total',
    kk: 'Дұрыс жауап: $count/$total',
  );
  String snakeAnswer(Word word, Word choice, {required bool correct}) {
    final pair = '${word.text} — ${word.translation}';
    if (correct) return '${this.correct}! $pair';
    return _text(
      en: '${choice.text} — ${choice.translation}. Correct match: $pair.',
      ru: '${choice.text} — ${choice.translation}. Верная пара: $pair.',
      es: '${choice.text} — ${choice.translation}. Pareja correcta: $pair.',
      kk: '${choice.text} — ${choice.translation}. Дұрыс жұп: $pair.',
    );
  }

  String get brickInstruction => _text(
    en: 'Break bricks and catch translations',
    ru: 'Разбивай кирпичи и лови переводы',
    es: 'Rompe bloques y atrapa traducciones',
    kk: 'Кірпіштерді бұзып, аудармаларын ұста',
  );
  String get brickCatch => _text(
    en: 'Catch the translation with the paddle',
    ru: 'Поймай перевод платформой',
    es: 'Atrapa la traducción con la pala',
    kk: 'Аударманы қалақшамен ұста',
  );
  String get brickGold => _text(
    en: 'Break a gold brick to reveal a word',
    ru: 'Разбей золотой кирпич, чтобы открыть слово',
    es: 'Rompe un bloque dorado para descubrir una palabra',
    kk: 'Сөзді ашу үшін алтын кірпішті бұз',
  );
  String get brickMove => _text(
    en: 'Drag sideways to move the paddle',
    ru: 'Веди пальцем влево или вправо',
    es: 'Desliza el dedo a los lados para mover la pala',
    kk: 'Қалақшаны жылжыту үшін саусағыңды оңға не солға сырғыт',
  );
  String get brickTapToAim => _text(
    en: 'Tap a card to move the paddle under it',
    ru: 'Коснись карточки, чтобы подвести под неё платформу',
    es: 'Toca una tarjeta para colocar la pala debajo',
    kk: 'Қалақшаны карточканың астына апару үшін карточканы түрт',
  );
  String get brickLaunch =>
      _text(en: 'Launch', ru: 'Пустить мяч', es: 'Lanzar', kk: 'Допты жіберу');
  String get brickPause =>
      _text(en: 'Pause', ru: 'Пауза', es: 'Pausar', kk: 'Кідірту');
  String get brickPaused => _text(
    en: 'Paused',
    ru: 'На паузе',
    es: 'En pausa',
    kk: 'Ойын кідіртілді',
  );
  String get brickResume =>
      _text(en: 'Resume', ru: 'Продолжить', es: 'Continuar', kk: 'Жалғастыру');
  String get brickMultiball => _text(
    en: 'Bonus: three balls',
    ru: 'Бонус: три мяча',
    es: 'Bono: tres bolas',
    kk: 'Бонус: үш доп',
  );
  String get brickMissed => _text(
    en: 'Missed the catch. Break another gold brick to try again.',
    ru: 'Промах. Разбей ещё один золотой кирпич для новой попытки.',
    es:
        'No atrapaste ninguna opción. Rompe otro bloque dorado para volver a intentarlo.',
    kk: 'Ұстай алмадың. Қайта байқап көру үшін тағы бір алтын кірпішті бұз.',
  );
  String brickField(int value) => _text(
    en: 'Board $value',
    ru: 'Поле $value',
    es: 'Tablero $value',
    kk: '$value-алаң',
  );

  String get appLanguage => _text(
    en: 'App language',
    ru: 'Язык приложения',
    es: 'Idioma de la aplicación',
    kk: 'Қолданба тілі',
  );
  String get systemLanguage => _text(
    en: 'Device language',
    ru: 'Язык устройства',
    es: 'Idioma del dispositivo',
    kk: 'Құрылғы тілі',
  );
  String get settingsSaveFailed => _text(
    en: 'Couldn’t save your preference. Try again.',
    ru: 'Не удалось сохранить настройку. Попробуй ещё раз.',
    es: 'No se pudo guardar el ajuste. Vuelve a intentarlo.',
    kk: 'Баптау сақталмады. Қайталап көр.',
  );
  String get reminderTime => _text(
    en: 'Reminder time',
    ru: 'Время напоминания',
    es: 'Hora del recordatorio',
    kk: 'Еске салу уақыты',
  );
  String get cancel =>
      _text(en: 'Cancel', ru: 'Отмена', es: 'Cancelar', kk: 'Бас тарту');
  String get save =>
      _text(en: 'Save', ru: 'Сохранить', es: 'Guardar', kk: 'Сақтау');

  String get wordSets => _text(
    en: 'My word sets',
    ru: 'Мои наборы',
    es: 'Mis listas',
    kk: 'Сөз жинақтарым',
  );
  String get createWordSet => _text(
    en: 'Create a set',
    ru: 'Создать набор',
    es: 'Crear una lista',
    kk: 'Жинақ жасау',
  );
  String get emptyWordSets => _text(
    en: 'Group words by topic and play with the ones you choose.',
    ru: 'Собери слова по теме и сыграй с ними в аркаду.',
    es: 'Agrupa palabras por tema y juega con las que elijas.',
    kk: 'Сөздерді тақырып бойынша жинап, таңдаған сөздеріңмен ойна.',
  );
  String get wordSetName => _text(
    en: 'Set name',
    ru: 'Название набора',
    es: 'Nombre de la lista',
    kk: 'Жинақ атауы',
  );
  String get wordSetSearch => _text(
    en: 'Search words or translations',
    ru: 'Поиск по слову или переводу',
    es: 'Buscar palabras o traducciones',
    kk: 'Сөз не аударма бойынша іздеу',
  );
  String get wordSetNoMatches => _text(
    en: 'No matching words',
    ru: 'Подходящих слов нет',
    es: 'No hay palabras que coincidan',
    kk: 'Сәйкес сөз табылмады',
  );
  String wordSetCount(int count) => _text(
    en: '$count ${count == 1 ? "word" : "words"}',
    ru: switch ((count % 10, count % 100)) {
      (1, != 11) => '$count слово',
      (>= 2 && <= 4, < 12 || > 14) => '$count слова',
      _ => '$count слов',
    },
    es: '$count ${count == 1 ? "palabra" : "palabras"}',
    kk: '$count сөз',
  );
  String selectedWordSetCount(int count) => _text(
    en: 'Selected ($count)',
    ru: 'Выбрано ($count)',
    es: 'Seleccionadas ($count)',
    kk: 'Таңдалды ($count)',
  );
  String get editWordSet => _text(
    en: 'Edit set',
    ru: 'Изменить набор',
    es: 'Editar lista',
    kk: 'Жинақты өзгерту',
  );
  String get edit =>
      _text(en: 'Edit', ru: 'Изменить', es: 'Editar', kk: 'Өзгерту');
  String get delete =>
      _text(en: 'Delete', ru: 'Удалить', es: 'Eliminar', kk: 'Жою');
  String deleteWordSet(String name) => _text(
    en: 'Delete “$name”?',
    ru: 'Удалить «$name»?',
    es: '¿Eliminar «$name»?',
    kk: '«$name» жинағын жоясың ба?',
  );
  String get deletingSetKeepsWords => _text(
    en: 'Your words will stay in the dictionary.',
    ru: 'Слова останутся в словаре.',
    es: 'Las palabras seguirán en el diccionario.',
    kk: 'Сөздер сөздікте қалады.',
  );
  String get addWordsToSet => _text(
    en: 'Add words',
    ru: 'Добавить слова',
    es: 'Añadir palabras',
    kk: 'Сөз қосу',
  );
  String get wordSetNeedsName => _text(
    en: 'Enter a name for this set.',
    ru: 'Введи название набора.',
    es: 'Escribe un nombre para la lista.',
    kk: 'Жинақтың атауын енгіз.',
  );
  String get duplicateWordSet => _text(
    en: 'A set with this name already exists.',
    ru: 'Набор с таким названием уже есть.',
    es: 'Ya existe una lista con este nombre.',
    kk: 'Мұндай атауы бар жинақ бар.',
  );
  String get missingWordSet => _text(
    en: 'This set has been deleted.',
    ru: 'Этот набор уже удалён.',
    es: 'Esta lista ya se ha eliminado.',
    kk: 'Бұл жинақ жойылған.',
  );
  String get wordSetWriteFailed => _text(
    en: 'Couldn’t save the changes. Try again.',
    ru: 'Не удалось сохранить изменения. Попробуй ещё раз.',
    es: 'No se pudieron guardar los cambios. Inténtalo de nuevo.',
    kk: 'Өзгерістер сақталмады. Қайталап көр.',
  );
  String get hours => _text(en: 'Hour', ru: 'Часы', es: 'Hora', kk: 'Сағат');
  String get minutes =>
      _text(en: 'Minute', ru: 'Минуты', es: 'Minutos', kk: 'Минут');
  String get dailyReminder => _text(
    en: 'Daily reminder',
    ru: 'Ежедневное напоминание',
    es: 'Recordatorio diario',
    kk: 'Күнделікті еске салу',
  );
  String get time => _text(en: 'Time', ru: 'Время', es: 'Hora', kk: 'Уақыт');
  String get gameSounds => _text(
    en: 'Game sounds',
    ru: 'Звуки в играх',
    es: 'Sonidos de los juegos',
    kk: 'Ойын дыбыстары',
  );
  String get notificationsDenied => _text(
    en: 'Notifications are blocked. You can allow them in your device settings.',
    ru:
        'Система не разрешила уведомления. Включить их можно в настройках телефона.',
    es:
        'Las notificaciones están bloqueadas. Puedes activarlas en los ajustes del dispositivo.',
    kk: 'Хабарландырулар өшірулі. Оларды құрылғы баптауларынан қосуға болады.',
  );
  String get licenses => _text(
    en: 'Full license texts',
    ru: 'Полные тексты лицензий',
    es: 'Textos completos de las licencias',
    kk: 'Лицензиялардың толық мәтіні',
  );
  String get loadingSources => _text(
    en: 'Loading sources',
    ru: 'Загрузка источников',
    es: 'Cargando las fuentes',
    kk: 'Дереккөздер жүктелуде',
  );
  String get sourcesLoadFailed => _text(
    en: 'Couldn’t load sources',
    ru: 'Источники не читаются',
    es: 'No se pudieron cargar las fuentes',
    kk: 'Дереккөздер жүктелмеді',
  );
  String get progressLoadFailed => _text(
    en: 'Couldn’t load progress',
    ru: 'Прогресс не загрузился',
    es: 'No se pudo cargar el progreso',
    kk: 'Ілгерілеу деректері жүктелмеді',
  );
  String get reopenProgress => _text(
    en: 'Close this screen and open it again.',
    ru: 'Попробуй открыть экран ещё раз.',
    es: 'Cierra esta pantalla y vuelve a abrirla.',
    kk: 'Бұл бетті жауып, қайта ашып көр.',
  );
  String get loadingProgress => _text(
    en: 'Loading progress',
    ru: 'Загрузка прогресса',
    es: 'Cargando el progreso',
    kk: 'Ілгерілеу деректері жүктелуде',
  );
  String get personalDictionary => _text(
    en: 'My Word List',
    ru: 'Личный словарь',
    es: 'Mi diccionario',
    kk: 'Жеке сөздік',
  );
  String get customWords => _text(
    en: 'My words',
    ru: 'Свои слова',
    es: 'Mis palabras',
    kk: 'Өз сөздерім',
  );
  String get addWord => _text(
    en: 'Add a word',
    ru: 'Добавить слово',
    es: 'Añadir palabra',
    kk: 'Сөз қосу',
  );
  String get playCustomWords => _text(
    en: 'Play with my words',
    ru: 'Играть со своими словами',
    es: 'Jugar con mis palabras',
    kk: 'Өз сөздеріммен ойнау',
  );
  String get noCustomWords => _text(
    en: 'Add a word or phrase to practise it in games.',
    ru: 'Добавь слово или фразу, чтобы потренироваться в играх.',
    es: 'Añade una palabra o frase para practicarla en los juegos.',
    kk: 'Ойындарда жаттығу үшін сөз немесе тіркес қос.',
  );
  String customWordLabel(String tag) => _text(
    en: 'Word or phrase (${languageName(tag)})',
    ru: 'Слово или фраза (${languageName(tag).toLowerCase()})',
    es: 'Palabra o frase (${languageName(tag).toLowerCase()})',
    kk: 'Сөз немесе тіркес (${languageName(tag)})',
  );
  String customTranslationLabel(String tag) => _text(
    en: 'Translation (${languageName(tag)})',
    ru: 'Перевод (${languageName(tag).toLowerCase()})',
    es: 'Traducción (${languageName(tag).toLowerCase()})',
    kk: 'Аударма (${languageName(tag)})',
  );
  String get enterWord => _text(
    en: 'Enter a word or phrase.',
    ru: 'Введи слово или фразу.',
    es: 'Escribe una palabra o frase.',
    kk: 'Сөз немесе тіркес енгіз.',
  );
  String get enterTranslation => _text(
    en: 'Enter a translation.',
    ru: 'Введи перевод.',
    es: 'Escribe una traducción.',
    kk: 'Аудармасын енгіз.',
  );
  String get customWordNeedsLetter => _text(
    en: 'The word or phrase needs at least one letter.',
    ru: 'В слове или фразе должна быть хотя бы одна буква.',
    es: 'La palabra o frase debe contener al menos una letra.',
    kk: 'Сөзде немесе тіркесте кемінде бір әріп болсын.',
  );
  String get duplicateCustomWord => _text(
    en: 'You already have this word at this level.',
    ru: 'Это слово уже есть среди твоих слов на этом уровне.',
    es: 'Esta palabra ya está en tu lista de este nivel.',
    kk: 'Бұл сөз осы деңгейдегі сөздеріңнің арасында бар.',
  );
  String get customWordSaveFailed => _text(
    en: 'Couldn’t save this word. Try again.',
    ru: 'Не удалось сохранить слово. Попробуй ещё раз.',
    es: 'No se pudo guardar la palabra. Vuelve a intentarlo.',
    kk: 'Сөз сақталмады. Қайталап көр.',
  );
  String get firstRoundProgress => _text(
    en: 'Play your first round to see your progress here',
    ru: 'Сыграй первую партию, и здесь появится, сколько пройдено',
    es: 'Juega tu primera ronda para ver tu progreso aquí',
    kk: 'Алғашқы раундты ойнасаң, ілгерілеуің осында көрінеді',
  );
  String get allTime => _text(
    en: 'All time',
    ru: 'За всё время',
    es: 'Desde el inicio',
    kk: 'Барлық уақыт',
  );
  String get words =>
      _text(en: 'Words', ru: 'Слова', es: 'Palabras', kk: 'Сөздер');
  String get learned => _text(
    en: 'Learned',
    ru: 'Выучено',
    es: 'Aprendidas',
    kk: 'Үйренген сөздер',
  );
  String get learning => _text(
    en: 'Learning',
    ru: 'В работе',
    es: 'En práctica',
    kk: 'Үйреніп жүрген сөздер',
  );
  String get hardWords =>
      _text(en: 'Difficult', ru: 'Трудные', es: 'Difíciles', kk: 'Қиын сөздер');
  String get twoWeeks => _text(
    en: 'Two weeks',
    ru: 'Две недели',
    es: 'Dos semanas',
    kk: 'Екі апта',
  );
  String get answersByDay => _text(
    en: 'Answers by day',
    ru: 'Ответы по дням',
    es: 'Respuestas por día',
    kk: 'Күн сайынғы жауаптар',
  );
  String get answers =>
      _text(en: 'Answers', ru: 'Ответы', es: 'Respuestas', kk: 'Жауаптар');
  String get total =>
      _text(en: 'Total', ru: 'Всего', es: 'Total', kk: 'Барлығы');
  String get correctCount =>
      _text(en: 'Correct', ru: 'Верных', es: 'Aciertos', kk: 'Дұрыс жауаптар');
  String get days => _text(en: 'Days', ru: 'Дни', es: 'Días', kk: 'Күндер');
  String get daysWithAnswers => _text(
    en: 'With answers',
    ru: 'С ответами',
    es: 'Con respuestas',
    kk: 'Жауап берген күндер',
  );
  String get bestStreak => _text(
    en: 'Best streak',
    ru: 'Лучшая серия',
    es: 'Mejor racha',
    kk: 'Ең ұзақ серия',
  );
  String get recentWords => _text(
    en: 'Recently seen',
    ru: 'Недавно встретил',
    es: 'Vistas recientemente',
    kk: 'Жуырда кездескен сөздер',
  );
  String get noRecentWords => _text(
    en: 'Words you encounter will appear here',
    ru: 'Пока нет встреченных слов',
    es: 'Todavía no has visto ninguna palabra',
    kk: 'Кездескен сөздерің осында шығады',
  );
  String get oftenMissed => _text(
    en: 'Often missed',
    ru: 'Часто ошибаюсь',
    es: 'Errores frecuentes',
    kk: 'Жиі қате жауап берілген сөздер',
  );
  String get noDifficultWords => _text(
    en: 'No frequently missed words yet',
    ru: 'Пока нет слов с частыми ошибками',
    es: 'Todavía no hay palabras en las que suelas fallar',
    kk: 'Жиі қате жауап берілген сөз әзірге жоқ',
  );
  String get favorites => _text(
    en: 'Favorites',
    ru: 'Избранное',
    es: 'Favoritas',
    kk: 'Таңдаулылар',
  );
  String get noFavorites => _text(
    en: 'No favorites yet',
    ru: 'В избранном пока пусто',
    es: 'Todavía no tienes palabras favoritas',
    kk: 'Таңдаулылар әзірге бос',
  );
  String get wordListLoadFailed => _text(
    en: 'Couldn’t load your word list',
    ru: 'Словарь не загрузился',
    es: 'No se pudo cargar tu diccionario',
    kk: 'Сөздік жүктелмеді',
  );
  String get retry => _text(
    en: 'Try again',
    ru: 'Попробовать ещё раз',
    es: 'Volver a intentar',
    kk: 'Қайталап көру',
  );
  String get loadingWordList => _text(
    en: 'Loading word list',
    ru: 'Загрузка словаря',
    es: 'Cargando el diccionario',
    kk: 'Сөздік жүктелуде',
  );
  String get wordDetails => _text(
    en: 'Word details',
    ru: 'Карточка слова',
    es: 'Ficha de la palabra',
    kk: 'Сөз карточкасы',
  );
  String get removeFavorite => _text(
    en: 'Remove from favorites',
    ru: 'Убрать из избранного',
    es: 'Quitar de favoritas',
    kk: 'Таңдаулылардан алып тастау',
  );
  String get addFavorite => _text(
    en: 'Add to favorites',
    ru: 'В избранное',
    es: 'Añadir a favoritas',
    kk: 'Таңдаулыларға қосу',
  );
  String get favoriteSaveFailed => _text(
    en: 'Couldn’t update your favorites. Try again.',
    ru: 'Не удалось сохранить избранное. Попробуй ещё раз.',
    es: 'No se pudo actualizar la lista de favoritas. Vuelve a intentarlo.',
    kk: 'Таңдаулылар сақталмады. Қайталап көр.',
  );
  String get answerHistory => _text(
    en: 'Answer history',
    ru: 'История ответов',
    es: 'Historial de respuestas',
    kk: 'Жауаптар тарихы',
  );
  String get correct =>
      _text(en: 'Correct', ru: 'Верно', es: 'Correcto', kk: 'Дұрыс');
  String get mistake =>
      _text(en: 'Incorrect', ru: 'Ошибка', es: 'Error', kk: 'Қате');
  String get reviewMistakes => _text(
    en: 'Review mistakes',
    ru: 'Разбор ошибок',
    es: 'Revisión de errores',
    kk: 'Қателерді талдау',
  );
  String get wordPreview => _text(
    en: 'Word preview',
    ru: 'Знакомство',
    es: 'Conoce las palabras',
    kk: 'Сөздермен танысу',
  );
  String get noMistakes => _text(
    en: 'No mistakes in this round',
    ru: 'В этом раунде нет ошибок',
    es: 'No hubo errores en esta ronda',
    kk: 'Бұл раундта қате болған жоқ',
  );
  String get backToResults => _text(
    en: 'You can go back to the results.',
    ru: 'Можно вернуться к итогам.',
    es: 'Puedes volver a los resultados.',
    kk: 'Нәтижелерге қайта орала аласың.',
  );
  String get yourAnswer => _text(
    en: 'Your answer',
    ru: 'Твой ответ',
    es: 'Tu respuesta',
    kk: 'Сенің жауабың',
  );
  String get timeUp => _text(
    en: 'Time’s up',
    ru: 'Время вышло',
    es: 'Se acabó el tiempo',
    kk: 'Уақыт бітті',
  );
  String get reviewWithoutTimer => _text(
    en: 'Review the words at your own pace.',
    ru: 'Повтори слова без таймера.',
    es: 'Repasa las palabras a tu ritmo.',
    kk: 'Сөздерді асықпай қайтала.',
  );
  String get readAndListen => _text(
    en: 'Read the translation and listen to the word before playing.',
    ru: 'Прочитай перевод и послушай слово перед игрой.',
    es: 'Lee la traducción y escucha la palabra antes de jugar.',
    kk: 'Ойынға кіріспес бұрын аудармасын оқып, сөздің айтылуын тыңда.',
  );
  String get next =>
      _text(en: 'Next', ru: 'Дальше', es: 'Siguiente', kk: 'Келесі');
  String get startGame => _text(
    en: 'Start game',
    ru: 'Начать игру',
    es: 'Empezar a jugar',
    kk: 'Ойынды бастау',
  );
  String get back => _text(en: 'Back', ru: 'Назад', es: 'Atrás', kk: 'Артқа');
  String get done => _text(en: 'Done', ru: 'Готово', es: 'Listo', kk: 'Дайын');
  String get skipPreview => _text(
    en: 'Skip to game',
    ru: 'Сразу в игру',
    es: 'Ir directo al juego',
    kk: 'Бірден ойнау',
  );
  String get playAgain => _text(
    en: 'Play again',
    ru: 'Ещё раз',
    es: 'Volver a jugar',
    kk: 'Қайта ойнау',
  );
  String get exit => _text(en: 'Exit', ru: 'Выйти', es: 'Salir', kk: 'Шығу');
  String get nothingToday => _text(
    en: 'You’re all caught up',
    ru: 'На сегодня всё',
    es: 'Estás al día',
    kk: 'Бүгінге осы жеткілікті',
  );
  String get reviewsDone => _text(
    en: 'There are no words due for review. Come back tomorrow.',
    ru: 'Слова к повторению кончились. Возвращайся завтра.',
    es: 'No quedan palabras pendientes de repaso. Vuelve mañana.',
    kk: 'Қайталайтын сөз қалмады. Ертең қайта кел.',
  );
  String get left => _text(
    en: 'Move left',
    ru: 'Влево',
    es: 'Mover a la izquierda',
    kk: 'Солға жылжы',
  );
  String get right => _text(
    en: 'Move right',
    ru: 'Вправо',
    es: 'Mover a la derecha',
    kk: 'Оңға жылжы',
  );
  String get grab =>
      _text(en: 'Grab', ru: 'Захватить', es: 'Atrapar', kk: 'Қармау');
  String get hint =>
      _text(en: 'Hint', ru: 'Подсказка', es: 'Pista', kk: 'Көмек');
  String get roundComplete => _text(
    en: 'Round complete',
    ru: 'Раунд окончен',
    es: 'Fin de la ronda',
    kk: 'Раунд аяқталды',
  );
  String get outOfLives => _text(
    en: 'Out of lives',
    ru: 'Жизни кончились',
    es: 'Te quedaste sin vidas',
    kk: 'Өмір қоры таусылды',
  );
  String get wordsReady => _text(
    en: 'More words are ready. Play another round.',
    ru: 'Ещё есть слова — сыграй ещё раунд',
    es: 'Hay más palabras para practicar. Juega otra ronda.',
    kk: 'Тағы сөздер бар. Тағы бір раунд ойна.',
  );
  String get dailyWordsDone => _text(
    en: 'No more words for today',
    ru: 'Слова на сегодня кончились',
    es: 'No quedan más palabras por hoy',
    kk: 'Бүгінгі сөздер таусылды',
  );
  String get comeBackTomorrow => _text(
    en: 'Come back tomorrow',
    ru: 'Возвращайся завтра',
    es: 'Vuelve mañana',
    kk: 'Ертең қайта кел',
  );
  String get correctTranslation => _text(
    en: 'Correct translation',
    ru: 'Правильный перевод',
    es: 'Traducción correcta',
    kk: 'Дұрыс аударма',
  );
  String get noun => _text(
    en: 'Noun',
    ru: 'Существительное',
    es: 'Sustantivo',
    kk: 'Зат есім',
  );
  String get verb =>
      _text(en: 'Verb', ru: 'Глагол', es: 'Verbo', kk: 'Етістік');
  String get adjective => _text(
    en: 'Adjective',
    ru: 'Прилагательное',
    es: 'Adjetivo',
    kk: 'Сын есім',
  );
  String get adverb =>
      _text(en: 'Adverb', ru: 'Наречие', es: 'Adverbio', kk: 'Үстеу');
  String get numeral =>
      _text(en: 'Numeral', ru: 'Числительное', es: 'Numeral', kk: 'Сан есім');
  String get pronoun =>
      _text(en: 'Pronoun', ru: 'Местоимение', es: 'Pronombre', kk: 'Есімдік');
  String get preposition => _text(
    en: 'Preposition',
    ru: 'Предлог',
    es: 'Preposición',
    kk: 'Септеулік шылау',
  );
  String get conjunction => _text(
    en: 'Conjunction',
    ru: 'Союз',
    es: 'Conjunción',
    kk: 'Жалғаулық шылау',
  );
  String get interjection => _text(
    en: 'Interjection',
    ru: 'Междометие',
    es: 'Interjección',
    kk: 'Одағай',
  );
  String get determiner => _text(
    en: 'Determiner',
    ru: 'Определитель',
    es: 'Determinante',
    kk: 'Анықтауыш сөз',
  );
  String get phrase =>
      _text(en: 'Phrase', ru: 'Выражение', es: 'Expresión', kk: 'Сөз тіркесі');
  String voiceUnavailable(String studyLanguage) => switch (studyLanguage) {
    'en' => _text(
      en:
          'English speech is unavailable. Check your device’s text-to-speech settings for a local English voice.',
      ru:
          'Английский голос недоступен. Проверь настройки синтеза речи на устройстве и установи английский голос.',
      es:
          'El audio en inglés no está disponible. Instala una voz en inglés en los ajustes de síntesis de voz del dispositivo.',
      kk:
          'Ағылшынша дыбыстау қолжетімсіз. Құрылғының мәтінді дыбыстау баптауларынан ағылшын тіліндегі дауысты орнат.',
    ),
    'es' => _text(
      en:
          'Spanish speech is unavailable. Install a local Spanish voice in your device’s text-to-speech settings.',
      ru:
          'Испанский голос недоступен. Установи испанский голос в настройках синтеза речи устройства.',
      es:
          'El audio en español no está disponible. Instala una voz en español en los ajustes de síntesis de voz del dispositivo.',
      kk:
          'Испанша дыбыстау қолжетімсіз. Құрылғының мәтінді дыбыстау баптауларынан испан тіліндегі дауысты орнат.',
    ),
    _ => _text(
      en:
          'Speech is unavailable. Install a voice for the course language in your device’s text-to-speech settings.',
      ru:
          'Озвучка недоступна. Установи голос для языка курса в настройках синтеза речи устройства.',
      es:
          'El audio no está disponible. Instala una voz en el idioma del curso en los ajustes de síntesis de voz del dispositivo.',
      kk:
          'Дыбыстау қолжетімсіз. Құрылғының мәтінді дыбыстау баптауларынан курс тіліне сәйкес дауысты орнат.',
    ),
  };
  String get speechFailed => _text(
    en: 'Couldn’t play the pronunciation. Try again.',
    ru: 'Не удалось произнести слово. Попробуй ещё раз.',
    es: 'No se pudo reproducir la pronunciación. Vuelve a intentarlo.',
    kk: 'Сөзді дыбыстау мүмкін болмады. Қайталап көр.',
  );
  String get listen =>
      _text(en: 'Listen', ru: 'Послушать', es: 'Escuchar', kk: 'Тыңдау');
  String get listenAgain => _text(
    en: 'Listen again',
    ru: 'Ещё раз',
    es: 'Escuchar de nuevo',
    kk: 'Қайта тыңдау',
  );
  String get openCampfire => _text(
    en: 'View the campfire',
    ru: 'Посмотреть костёр',
    es: 'Ver la hoguera',
    kk: 'Алауды көру',
  );
  String get replayCampfire => _text(
    en: 'Replay the campfire animation',
    ru: 'Повторить анимацию костра',
    es: 'Volver a ver la animación de la hoguera',
    kk: 'Алау анимациясын қайта көру',
  );

  String campfireStageName(CampfireStage stage) => switch (stage) {
    CampfireStage.smoke => _text(
      en: 'A wisp of smoke',
      ru: 'Дымок',
      es: 'Hilo de humo',
      kk: 'Жіңішке түтін',
    ),
    CampfireStage.ember => _text(
      en: 'Glowing ember',
      ru: 'Розжиг',
      es: 'Brasa encendida',
      kk: 'Қызара бастаған шоқ',
    ),
    CampfireStage.spark => _text(
      en: 'First spark',
      ru: 'Первая искра',
      es: 'Primera chispa',
      kk: 'Алғашқы ұшқын',
    ),
    CampfireStage.firstFlame => _text(
      en: 'First flame',
      ru: 'Первый огонёк',
      es: 'Primera llama',
      kk: 'Алғашқы жалын',
    ),
    CampfireStage.kindling => _text(
      en: 'The kindling catches',
      ru: 'Занялась растопка',
      es: 'La yesca prende',
      kk: 'Тұтатқы жанды',
    ),
    CampfireStage.campfire => _text(
      en: 'Campfire',
      ru: 'Походный костёр',
      es: 'Fogata',
      kk: 'Алау',
    ),
    CampfireStage.hotCoals => _text(
      en: 'Glowing coals',
      ru: 'Жаркие угли',
      es: 'Brasas vivas',
      kk: 'Қызған шоқ',
    ),
    CampfireStage.flyingSparks => _text(
      en: 'Sparks from the fire',
      ru: 'Костёр с искрами',
      es: 'Hoguera con chispas',
      kk: 'Шашыраған ұшқын',
    ),
    CampfireStage.kneeHighFlames => _text(
      en: 'Knee-high flames',
      ru: 'По колено',
      es: 'Llamas hasta las rodillas',
      kk: 'Тізеге жеткен жалын',
    ),
    CampfireStage.tallFlame => _text(
      en: 'Towering flame',
      ru: 'Высокое пламя',
      es: 'Llama alta',
      kk: 'Биік жалын',
    ),
    CampfireStage.fireWhirl => _text(
      en: 'Fire whirl',
      ru: 'Огненный вихрь',
      es: 'Remolino de fuego',
      kk: 'От құйыны',
    ),
    CampfireStage.forestEdge => _text(
      en: 'Firelight at the forest’s edge',
      ru: 'Жар у опушки',
      es: 'Resplandor al borde del bosque',
      kk: 'Орман шетіндегі от',
    ),
    CampfireStage.burningBranches => _text(
      en: 'Burning branches',
      ru: 'Огненные ветви',
      es: 'Ramas en llamas',
      kk: 'Жалын шарпыған бұтақтар',
    ),
    CampfireStage.blazingTree => _text(
      en: 'Blazing tree',
      ru: 'Пылающее дерево',
      es: 'Árbol en llamas',
      kk: 'Жалындаған ағаш',
    ),
    CampfireStage.burningTreetops => _text(
      en: 'Blazing treetops',
      ru: 'Огненные кроны',
      es: 'Copas en llamas',
      kk: 'Жанған ағаш ұштары',
    ),
    CampfireStage.ragingForest => _text(
      en: 'Forest ablaze',
      ru: 'Бушующий лес',
      es: 'Bosque en llamas',
      kk: 'Өрт шарпыған орман',
    ),
    CampfireStage.goldenRiver => _text(
      en: 'Golden river',
      ru: 'Золотая река',
      es: 'Río dorado',
      kk: 'Алтын өзен',
    ),
    CampfireStage.horizonLights => _text(
      en: 'Lights on the horizon',
      ru: 'Огни на горизонте',
      es: 'Luces en el horizonte',
      kk: 'Көкжиектегі оттар',
    ),
    CampfireStage.firefall => _text(
      en: 'Waterfall of fire',
      ru: 'Огненный водопад',
      es: 'Cascada de fuego',
      kk: 'От сарқырамасы',
    ),
    CampfireStage.flameCrown => _text(
      en: 'Crown of flame',
      ru: 'Корона пламени',
      es: 'Corona de fuego',
      kk: 'Жалын тәжі',
    ),
    CampfireStage.forestHeart => _text(
      en: 'Heart of the fiery forest',
      ru: 'Сердце огненного леса',
      es: 'Corazón del bosque de fuego',
      kk: 'Отты орманның жүрегі',
    ),
  };

  String get noStreak => _text(
    en: 'No streak yet',
    ru: 'Серии нет',
    es: 'Aún no tienes una racha',
    kk: 'Серия әлі жоқ',
  );
  String get startStreak => _text(
    en: 'Start your streak',
    ru: 'Начни свою серию',
    es: 'Empieza tu racha',
    kk: 'Серияны баста',
  );
  String get playedToday => _text(
    en: 'Played today',
    ru: 'Сегодня сыграно',
    es: 'Ya jugaste hoy',
    kk: 'Бүгін ойнадың',
  );
  String get notPlayedToday => _text(
    en: 'Not played today',
    ru: 'Сегодня ещё не сыграно',
    es: 'Aún no has jugado hoy',
    kk: 'Бүгін әлі ойнамадың',
  );
  String get continueStreak => _text(
    en: 'Keep your streak going',
    ru: 'Продолжить серию',
    es: 'Mantener la racha',
    kk: 'Серияны жалғастыру',
  );
  String get saveStreak => _text(
    en: 'Save your streak',
    ru: 'Спасти серию',
    es: 'Salvar la racha',
    kk: 'Серияны сақтап қалу',
  );
  String get playAnotherRound => _text(
    en: 'Play another round',
    ru: 'Сыграть ещё раз',
    es: 'Jugar otra ronda',
    kk: 'Тағы бір раунд ойнау',
  );
  String get freezeAvailable => _text(
    en: 'Streak Freeze available',
    ru: 'Заморозка в запасе',
    es: 'Protección de racha disponible',
    kk: 'Серия қорғанысы бар',
  );
  String get playedDay =>
      _text(en: 'played', ru: 'сыграно', es: 'día jugado', kk: 'ойналды');
  String get frozenDay => _text(
    en: 'streak frozen',
    ru: 'заморозка',
    es: 'racha protegida',
    kk: 'серия қорғалды',
  );
  String get missedDay => _text(
    en: 'missed',
    ru: 'пропущено',
    es: 'día sin jugar',
    kk: 'ойналмады',
  );
  String get pendingDay => _text(
    en: 'today, not played yet',
    ru: 'сегодня, ещё не сыграно',
    es: 'hoy, aún sin jugar',
    kk: 'бүгін әлі ойналмады',
  );
  String get futureDay => _text(
    en: 'upcoming',
    ru: 'ещё не наступил',
    es: 'día próximo',
    kk: 'алдағы күн',
  );
  String get reminderSavedByFreeze => _text(
    en: 'Play today. A Streak Freeze will cover the day you missed.',
    ru: 'Сыграй сегодня — заморозка прикроет вчерашний пропуск',
    es: 'Juega hoy. La protección de racha cubrirá el día que faltaste.',
    kk: 'Бүгін ойна. Серия қорғанысы өткізіп алған күніңнің орнын толтырады.',
  );
  String get oneRoundCounts => _text(
    en: 'One round is all it takes to count today.',
    ru: 'Одна партия — и день засчитан',
    es: 'Juega una ronda para sumar el día de hoy.',
    kk: 'Бүгінгі күн есептелуі үшін бір раунд ойнасаң жеткілікті.',
  );
  String get timeToReturn => _text(
    en: 'Ready to play again?',
    ru: 'Пора вернуться',
    es: '¿Todo listo para volver a jugar?',
    kk: 'Қайта ойнауға дайынсың ба?',
  );
  String get restartStreak => _text(
    en: 'Play one round to start a new streak.',
    ru: 'Одна партия, и серия начнётся заново',
    es: 'Juega una ronda para empezar una nueva racha.',
    kk: 'Жаңа серия бастау үшін бір раунд ойна.',
  );

  String courseName(StudyCourse course) {
    final study = languageName(course.studyLanguage);
    final translation = languageName(course.translationLanguage);
    final kazakhTranslation = switch (course.translationLanguage) {
      'en' => 'ағылшынша',
      'ru' => 'орысша',
      'es' => 'испанша',
      'kk' => 'қазақша',
      _ => translation.toLowerCase(),
    };
    return _text(
      en: '$study · $translation translations',
      ru: '$study · переводы на ${translation.toLowerCase()}',
      es: '$study · traducciones al ${translation.toLowerCase()}',
      kk: '$study · $kazakhTranslation аударма',
    );
  }

  String languageName(String tag) => switch (tag) {
    'en' => _text(
      en: 'English',
      ru: 'Английский',
      es: 'Inglés',
      kk: 'Ағылшын тілі',
    ),
    'ru' => _text(en: 'Russian', ru: 'Русский', es: 'Ruso', kk: 'Орыс тілі'),
    'es' => _text(
      en: 'Spanish',
      ru: 'Испанский',
      es: 'Español',
      kk: 'Испан тілі',
    ),
    'kk' => _text(
      en: 'Kazakh',
      ru: 'Казахский',
      es: 'Kazajo',
      kk: 'Қазақ тілі',
    ),
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
    kk: switch (tag) {
      'en' => 'Ағылшын тілінің деңгейі',
      'ru' => 'Орыс тілінің деңгейі',
      'es' => 'Испан тілінің деңгейі',
      'kk' => 'Қазақ тілінің деңгейі',
      _ => 'Тіл деңгейі',
    },
  );

  String weekday(int weekday, String russianLabel) => _text(
    en: const ['Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat', 'Sun'][weekday - 1],
    ru: russianLabel,
    es: const ['lun', 'mar', 'mié', 'jue', 'vie', 'sáb', 'dom'][weekday - 1],
    kk: const ['Дс', 'Сс', 'Ср', 'Бс', 'Жм', 'Сб', 'Жс'][weekday - 1],
  );

  String noWordsForLevel(String level) => _text(
    en: 'No $level words in this course yet',
    ru: 'Для $level пока нет слов',
    es: 'Aún no hay palabras de nivel $level en este curso',
    kk: 'Бұл курста $level деңгейінің сөздері әлі жоқ',
  );

  String level(String level) => _text(
    en: 'Level $level',
    ru: 'Уровень $level',
    es: 'Nivel $level',
    kk: '$level деңгейі',
  );

  String correctAnswers(int count, int total) => _text(
    en: 'Correct answers: $count of $total',
    ru: 'Верных ответов: $count из $total',
    es: 'Aciertos: $count de $total',
    kk: 'Дұрыс жауаптар: $count/$total',
  );

  String reviewMistakesCount(int count) => _text(
    en: 'Review mistakes ($count)',
    ru: 'Разобрать ошибки ($count)',
    es: 'Revisar errores ($count)',
    kk: 'Қателерді талдау ($count)',
  );

  String score(int value) => _text(
    en: 'Score: $value',
    ru: 'Счёт: $value',
    es: 'Puntos: $value',
    kk: 'Ұпай: $value',
  );

  String bestCombo(int value) => _text(
    en: 'Best combo: $value',
    ru: 'Лучшая серия: $value',
    es: 'Mejor combo: $value',
    kk: 'Үздік комбо: $value',
  );

  String lives(int value, int total) => _text(
    en: 'Lives: $value of $total',
    ru: 'Жизни: $value из $total',
    es: 'Vidas: $value de $total',
    kk: 'Өмір саны: $value/$total',
  );

  String wordNumber(int index, int total) => _text(
    en: 'Word $index of $total',
    ru: 'Слово $index из $total',
    es: 'Palabra $index de $total',
    kk: 'Сөз: $index/$total',
  );

  String lettersCollected(int count, int total) => _text(
    en: 'Letters collected: $count of $total',
    ru: 'Собрано букв: $count из $total',
    es: 'Letras atrapadas: $count de $total',
    kk: 'Жиналған әріп: $count/$total',
  );

  String letterMiss(String letter) => _text(
    en: 'Letter $letter doesn’t fit',
    ru: 'Буква $letter не подошла',
    es: 'La letra $letter no encaja',
    kk: '$letter әрпі сәйкес келмеді',
  );

  String capsule(String letter, {required bool hintShown}) => _text(
    en: hintShown ? 'Capsule $letter, hint' : 'Capsule $letter',
    ru: hintShown ? 'Капсула $letter, подсказка' : 'Капсула $letter',
    es:
        hintShown
            ? 'Cápsula con la letra $letter, pista'
            : 'Cápsula con la letra $letter',
    kk:
        hintShown
            ? '$letter әрпі бар капсула, көмек'
            : '$letter әрпі бар капсула',
  );

  String attemptCounts(int count, int mistakes) => _text(
    en: 'Attempts: $count · Mistakes: $mistakes',
    ru: 'Попыток: $count · Ошибок: $mistakes',
    es: 'Intentos: $count · Errores: $mistakes',
    kk: 'Әрекет: $count · Қате: $mistakes',
  );

  String answersForDay(String date, int count) => _text(
    en: '$date, $count ${count == 1 ? 'answer' : 'answers'}',
    ru: '$date, ответов $count',
    es: '$date, $count ${count == 1 ? 'respuesta' : 'respuestas'}',
    kk: '$date, $count жауап',
  );

  String pronounce(String word) => _text(
    en: 'Pronounce $word',
    ru: 'Произнести $word',
    es: 'Pronunciar $word',
    kk: '«$word» сөзін дыбыстау',
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
