import 'dart:math';

import '../review/review_contract.dart';
import '../review/study_course.dart';

/// A recipient's identity stays the same when the rabbits change places.
class CandyOrder {
  const CandyOrder._({
    required this.courseId,
    required this.level,
    required this.phrase,
    required this.translation,
    required this.target,
    required this.rabbits,
  });

  final String courseId;
  final CefrLevel level;
  final String phrase;
  final String translation;
  final int target;
  final List<int> rabbits;
}

bool candyAvailableFor(StudyCourse course, CefrLevel level) {
  if (course.id != '${course.translationLanguage}-${course.studyLanguage}') {
    return false;
  }
  return switch (course.id) {
    'ru-en' => true,
    'es-en' => level == CefrLevel.a1,
    'ru-es' ||
    'en-es' ||
    'kk-ru' ||
    'kk-en' ||
    'kk-es' => level != CefrLevel.c2,
    _ when StudyCourse.germanCourses.any((entry) => entry.id == course.id) =>
      level != CefrLevel.c2,
    _ => false,
  };
}

List<CandyOrder> candyOrdersFor({
  required StudyCourse course,
  required CefrLevel level,
  required int seed,
}) {
  if (!candyAvailableFor(course, level)) return const [];
  final random = Random(seed);
  final targets = [_scarf, _sleep, _flower]..shuffle(random);
  final layouts = [..._layouts]..shuffle(random);
  final orders = <CandyOrder>[];
  for (final (index, target) in targets.indexed) {
    final options = _cues[level]!.where((cue) => cue.target == target).toList();
    final cue = options[random.nextInt(options.length)];
    orders.add(
      CandyOrder._(
        courseId: course.id,
        level: level,
        phrase: cue.inLanguage(course.studyLanguage),
        translation: cue.inLanguage(course.translationLanguage),
        target: target,
        rabbits: layouts[index],
      ),
    );
  }
  return List.unmodifiable(orders);
}

const _scarf = 0;
const _sleep = 1;
const _flower = 2;
const _layouts = [
  [_scarf, _sleep, _flower],
  [_scarf, _flower, _sleep],
  [_sleep, _scarf, _flower],
  [_sleep, _flower, _scarf],
  [_flower, _scarf, _sleep],
  [_flower, _sleep, _scarf],
];

class _Cue {
  const _Cue(this.target, this.en, this.ru, [this.es, this.kk, this.de]);
  final int target;
  final String en;
  final String ru;
  // The only C2 deck is Russian → English.
  final String? es;
  final String? kk;
  final String? de;

  String inLanguage(String language) => switch (language) {
    'en' => en,
    'ru' => ru,
    'es' => es!,
    'kk' => kk!,
    'de' => de!,
    _ => throw ArgumentError.value(language, 'language'),
  };
}

// Each clue describes something visible on the illustrated rabbit, in any lane.
const _cues = {
  CefrLevel.a1: [
    _Cue(
      _scarf,
      'For the rabbit with the scarf.',
      'Для кролика в шарфе.',
      'Para el conejo con bufanda.',
      'Шарф таққан қоянға.',
      'Für das Kaninchen mit dem Schal.',
    ),
    _Cue(
      _scarf,
      'Look for a green scarf.',
      'Ищи зелёный шарф.',
      'Busca una bufanda verde.',
      'Жасыл шарфты ізде.',
      'Such den grünen Schal.',
    ),
    _Cue(
      _scarf,
      'Who has a scarf?',
      'У кого шарф?',
      '¿Quién tiene una bufanda?',
      'Шарф кімде?',
      'Wer hat einen Schal?',
    ),
    _Cue(
      _sleep,
      'For the sleeping rabbit.',
      'Для спящего кролика.',
      'Para el conejo dormido.',
      'Ұйықтап жатқан қоянға.',
      'Für das schlafende Kaninchen.',
    ),
    _Cue(
      _sleep,
      'Look for the blanket.',
      'Ищи одеяло.',
      'Busca la manta.',
      'Көрпені ізде.',
      'Such die Decke.',
    ),
    _Cue(
      _sleep,
      'Who is asleep?',
      'Кто спит?',
      '¿Quién está dormido?',
      'Кім ұйықтап жатыр?',
      'Wer schläft?',
    ),
    _Cue(
      _flower,
      'For the rabbit with the flower.',
      'Для кролика с цветком.',
      'Para el conejo con la flor.',
      'Гүлі бар қоянға.',
      'Für das Kaninchen mit der Blume.',
    ),
    _Cue(
      _flower,
      'Look for a pink flower.',
      'Ищи розовый цветок.',
      'Busca una flor rosa.',
      'Қызғылт гүлді ізде.',
      'Such die rosa Blume.',
    ),
    _Cue(
      _flower,
      'Who has a book?',
      'У кого книга?',
      '¿Quién tiene un libro?',
      'Кітап кімде?',
      'Wer hat ein Buch?',
    ),
  ],
  CefrLevel.a2: [
    _Cue(
      _scarf,
      'Give it to the rabbit in the green scarf.',
      'Отдай конфету кролику в зелёном шарфе.',
      'Dale el caramelo al conejo de la bufanda verde.',
      'Кәмпитті жасыл шарф таққан қоянға бер.',
      'Gib das Bonbon dem Kaninchen mit dem grünen Schal.',
    ),
    _Cue(
      _scarf,
      'One rabbit is wearing a scarf today. This is for him.',
      'Один кролик сегодня в шарфе. Это для него.',
      'Hoy uno de los conejos lleva bufanda. Esto es para él.',
      'Бүгін бір қоян шарф тағып алыпты. Кәмпит соған арналған.',
      'Ein Kaninchen trägt heute einen Schal. Für dieses Kaninchen ist das Bonbon.',
    ),
    _Cue(
      _scarf,
      'Which rabbit has a scarf around his neck?',
      'У какого кролика на шее шарф?',
      '¿Qué conejo tiene una bufanda al cuello?',
      'Қай қоянның мойнында шарф бар?',
      'Welches Kaninchen hat einen Schal um den Hals?',
    ),
    _Cue(
      _sleep,
      'For the rabbit who is sleeping.',
      'Для кролика, который спит.',
      'Para el conejo que duerme.',
      'Ұйықтап жатқан қоянға арналған.',
      'Für das Kaninchen, das gerade schläft.',
    ),
    _Cue(
      _sleep,
      'Leave it by the rabbit under the blanket.',
      'Оставь конфету рядом с кроликом под одеялом.',
      'Deja el caramelo al lado del conejo que está bajo la manta.',
      'Кәмпитті көрпенің астында жатқан қоянның жанына қалдыр.',
      'Ein Kaninchen liegt unter der Decke. Leg das Bonbon daneben.',
    ),
    _Cue(
      _sleep,
      'Can you find the rabbit with his eyes closed?',
      'Можешь найти кролика с закрытыми глазами?',
      '¿Puedes encontrar al conejo que tiene los ojos cerrados?',
      'Көзін жұмып жатқан қоянды таба аласың ба?',
      'Findest du das Kaninchen, das die Augen geschlossen hat?',
    ),
    _Cue(
      _flower,
      'Give it to the rabbit with a flower by his ear.',
      'Отдай конфету кролику с цветком у уха.',
      'Dale el caramelo al conejo que lleva una flor junto a la oreja.',
      'Кәмпитті құлағының тұсына гүл қыстырған қоянға бер.',
      'Gib das Bonbon dem Kaninchen mit der Blume am Ohr.',
    ),
    _Cue(
      _flower,
      'This rabbit has an open book. Find him.',
      'У этого кролика открытая книга. Найди его.',
      'Este conejo tiene un libro abierto. Búscalo.',
      'Бұл қоянның кітабы ашық. Сол қоянды тап.',
      'Ein Kaninchen hat ein offenes Buch vor sich. Such dieses Kaninchen.',
    ),
    _Cue(
      _flower,
      'Which rabbit is reading a book?',
      'Какой кролик читает книгу?',
      '¿Qué conejo está leyendo un libro?',
      'Қай қоян кітап оқып отыр?',
      'Welches Kaninchen liest gerade ein Buch?',
    ),
  ],
  CefrLevel.b1: [
    _Cue(
      _scarf,
      'The reader can wait. Look for the other rabbit who is still awake.',
      'Читатель может подождать. Ищи другого кролика, который ещё не спит.',
      'El lector puede esperar. Busca al otro conejo que sigue despierto.',
      'Кітап оқып отырған қоян күте тұрсын. Ояу отырған басқа қоянды ізде.',
      'Das lesende Kaninchen kann warten. Such das andere Kaninchen, das noch wach ist.',
    ),
    _Cue(
      _scarf,
      'Give it to the one who put on a scarf to keep warm.',
      'Отдай конфету тому, кто надел шарф, чтобы согреться.',
      'Dáselo al que se puso una bufanda para entrar en calor.',
      'Кәмпитті жылыну үшін шарф таққан қоянға бер.',
      'Gib das Bonbon dem Kaninchen, das sich einen Schal umgebunden hat, damit es nicht friert.',
    ),
    _Cue(
      _scarf,
      'You can tell which rabbit it is by the green scarf around his neck.',
      'Нужного кролика можно узнать по зелёному шарфу на шее.',
      'Puedes reconocer al conejo por la bufanda verde que lleva al cuello.',
      'Ол қоянды мойнындағы жасыл шарфынан танисың.',
      'Am grünen Schal um den Hals erkennst du das richtige Kaninchen.',
    ),
    _Cue(
      _sleep,
      'Leave it where the rabbit will find it when he wakes up.',
      'Оставь конфету там, где кролик найдёт её, когда проснётся.',
      'Déjalo donde el conejo lo encuentre al despertarse.',
      'Кәмпитті қоян оянғанда тауып алатындай жерге қалдыр.',
      'Leg das Bonbon so hin, dass das Kaninchen es nach dem Aufwachen findet.',
    ),
    _Cue(
      _sleep,
      'While the others are awake, this rabbit is having a nap.',
      'Пока остальные бодрствуют, этот кролик дремлет.',
      'Mientras los demás están despiertos, este conejo está echando una siesta.',
      'Басқалары ояу отырғанда, бұл қоян мызғып жатыр.',
      'Während die anderen wach sind, macht dieses Kaninchen ein Nickerchen.',
    ),
    _Cue(
      _sleep,
      'Put it next to the blanket so the sleeping rabbit can have it later.',
      'Положи конфету рядом с одеялом, чтобы спящий кролик мог съесть её потом.',
      'Déjalo junto a la manta para que el conejo dormido pueda comérselo después.',
      'Ұйықтап жатқан қоян кәмпитті кейін жесін десең, оны көрпенің жанына қой.',
      'Leg das Bonbon neben die Decke, damit das schlafende Kaninchen es später essen kann.',
    ),
    _Cue(
      _flower,
      'The rabbit this is for has a flower by his ear and a book in his paws.',
      'У кролика, которому предназначена конфета, цветок у уха и книга в лапах.',
      'El conejo al que va dirigido el caramelo tiene una flor junto a la oreja y un libro entre las patas.',
      'Кәмпит алатын қоянның құлағының тұсында гүл, ал табандарында кітап бар.',
      'Das Bonbon ist für das Kaninchen bestimmt, das eine Blume am Ohr und ein Buch in den Pfoten hat.',
    ),
    _Cue(
      _flower,
      'Take it to the reader before he turns the page.',
      'Отнеси конфету читателю, пока он не перевернул страницу.',
      'Llévaselo al lector antes de que pase la página.',
      'Кітап оқып отырған қоян парақты аудармай тұрып, кәмпитті соған апар.',
      'Bring das Bonbon dem lesenden Kaninchen, bevor es umblättert.',
    ),
    _Cue(
      _flower,
      'Look for the rabbit who has chosen to read instead of taking a nap.',
      'Ищи кролика, который решил почитать вместо того, чтобы вздремнуть.',
      'Busca al conejo que ha decidido leer en vez de echarse una siesta.',
      'Мызғып алудың орнына кітап оқуды таңдаған қоянды ізде.',
      'Such das Kaninchen, das lieber liest, als ein Nickerchen zu machen.',
    ),
  ],
  CefrLevel.b2: [
    _Cue(
      _scarf,
      'If you ruled out both the reader and the sleeper, who would be left?',
      'Если исключить и читателя, и соню, кто останется?',
      'Si descartaras tanto al lector como al que duerme, ¿quién quedaría?',
      'Кітап оқып отырған қоян мен ұйықтап жатқан қоянды есептемесек, кім қалады?',
      'Wenn du sowohl das lesende als auch das schlafende Kaninchen ausschließt, welches bleibt dann übrig?',
    ),
    _Cue(
      _scarf,
      'The candy was meant for the rabbit whose scarf is wrapped around his neck.',
      'Конфета предназначалась кролику, у которого шея укутана шарфом.',
      'El caramelo iba destinado al conejo que lleva la bufanda enrollada al cuello.',
      'Кәмпит мойнына шарф ораған қоянға арналған.',
      'Das Bonbon war für das Kaninchen bestimmt, das einen Schal um den Hals gewickelt hat.',
    ),
    _Cue(
      _scarf,
      'Of the two rabbits keeping warm, choose the one who is wide awake.',
      'Из двух кроликов, которые укутались от холода, выбери того, который совсем не сонный.',
      'De los dos conejos que se abrigan, elige al que está bien despierto.',
      'Жылы оранған екі қоянның ішінен көзі ашық, сергек отырғанын таңда.',
      'Von den beiden Kaninchen, die sich warm eingepackt haben, wähle dasjenige, das hellwach ist.',
    ),
    _Cue(
      _sleep,
      'Even if the rabbit never opens his eyes, leave the candy beside his blanket.',
      'Даже если кролик так и не откроет глаза, оставь конфету рядом с его одеялом.',
      'Aunque el conejo no abra los ojos en ningún momento, deja el caramelo junto a su manta.',
      'Қоян көзін ашпаса да, кәмпитті көрпесінің жанына қалдыр.',
      'Selbst wenn das Kaninchen die Augen gar nicht öffnet, lass das Bonbon neben seiner Decke liegen.',
    ),
    _Cue(
      _sleep,
      'The rabbit would see you coming if he weren’t fast asleep.',
      'Этот кролик увидел бы, как ты подходишь, если бы не спал так крепко.',
      'El conejo te vería venir si no estuviera profundamente dormido.',
      'Қоян қатты ұйықтамағанда, сенің келе жатқаныңды көрер еді.',
      'Das Kaninchen würde dich kommen sehen, wenn es nicht tief und fest schliefe.',
    ),
    _Cue(
      _sleep,
      'Choose the one who has drifted off while the other two are still awake.',
      'Выбери того, кто уже задремал, пока двое других ещё бодрствуют.',
      'Elige al que se ha quedado dormido mientras los otros dos siguen despiertos.',
      'Қалған екеуі әлі ояу отырғанда мызғып кеткен қоянды таңда.',
      'Wähle das Kaninchen, das eingenickt ist, während die anderen beiden noch wach sind.',
    ),
    _Cue(
      _flower,
      'Give it to whoever is reading, whether or not you can see the flower.',
      'Отдай конфету тому, кто читает, даже если ты не видишь цветка.',
      'Dáselo a quien esté leyendo, tanto si ves la flor como si no.',
      'Гүлді көрсең де, көрмесең де, кәмпитті кітап оқып отырған қоянға бер.',
      'Gib das Bonbon dem Kaninchen, das gerade liest, ganz gleich, ob du die Blume siehst oder nicht.',
    ),
    _Cue(
      _flower,
      'If the reader put his book down, you could still recognise him by his flower.',
      'Даже если бы читатель отложил книгу, его всё равно можно было бы узнать по цветку.',
      'Si el lector dejara el libro, aún podrías reconocerlo por la flor.',
      'Оқып отырған қоян кітабын қоя тұрса да, оны гүлінен тануға болады.',
      'Selbst wenn das lesende Kaninchen sein Buch weglegen würde, könntest du es noch an seiner Blume erkennen.',
    ),
    _Cue(
      _flower,
      'The rabbit you are looking for seems more interested in his book than in the candy.',
      'Кролика, которого ты ищешь, книга, похоже, интересует больше, чем конфета.',
      'Al conejo que buscas parece interesarle más el libro que el caramelo.',
      'Сен іздеген қоян кәмпиттен гөрі кітабына көбірек қызығатын сияқты.',
      'Das Kaninchen, das du suchst, scheint sich mehr für sein Buch als für das Bonbon zu interessieren.',
    ),
  ],
  CefrLevel.c1: [
    _Cue(
      _scarf,
      'Neither buried in a book nor tucked up under a blanket, the intended recipient is easy to spot.',
      'Адресата легко узнать по тому, что он не погрузился в книгу и не укутался в одеяло.',
      'Reconocerás enseguida al destinatario porque ni está enfrascado en un libro ni se ha arropado con una manta.',
      'Кәмпит алатын қоянды тану оңай: ол кітапқа үңіліп те, көрпеге оранып та отырған жоқ.',
      'Das gesuchte Kaninchen ist leicht auszumachen: Es hat sich weder in ein Buch vertieft noch unter eine Decke gekuschelt.',
    ),
    _Cue(
      _scarf,
      'Were it not for the scarf, you might overlook the one with nothing in his paws and his eyes wide open.',
      'Если бы не шарф, ты мог бы не заметить кролика с пустыми лапами и широко открытыми глазами.',
      'De no ser por la bufanda, quizá se te pasaría por alto el conejo que tiene las patas vacías y los ojos bien abiertos.',
      'Шарфы болмаса, көзі бақырайып ашық, қолында ештеңе жоқ қоянды байқамай қалуың мүмкін.',
      'Wäre da nicht der Schal, könntest du das Kaninchen mit leeren Pfoten und weit geöffneten Augen glatt übersehen.',
    ),
    _Cue(
      _scarf,
      'Should the book catch your eye, keep looking for the scarf that singles out the recipient.',
      'Даже если твой взгляд привлечёт книга, продолжай искать шарф, по которому можно узнать адресата.',
      'Si el libro te llama la atención, sigue buscando la bufanda que distingue al destinatario.',
      'Көзің кітапқа түссе де, кімге апару керегін білдіретін шарфты іздей бер.',
      'Sollte dir das Buch ins Auge fallen, halte dennoch nach dem Schal Ausschau. An ihm erkennst du, für wen das Bonbon bestimmt ist.',
    ),
    _Cue(
      _sleep,
      'Set it within reach of the one who, to judge by his closed eyes, is oblivious to your arrival.',
      'Положи конфету поближе к тому, кто, судя по закрытым глазам, не замечает твоего появления.',
      'Déjalo al alcance del que, a juzgar por sus ojos cerrados, no se ha percatado de tu llegada.',
      'Көзін жұмып жатқанына қарағанда, келгеніңді сезбеген қоянға кәмпитті қолы жететіндей жерге қой.',
      'Leg das Bonbon in Reichweite des Kaninchens, das, nach seinen geschlossenen Augen zu urteilen, von deiner Ankunft nichts mitbekommen hat.',
    ),
    _Cue(
      _sleep,
      'The reader may be absorbed in the story, but the rabbit you want is lost in a dream.',
      'Пусть читатель и поглощён историей, тебе нужен кролик, который погрузился в сон.',
      'Por muy absorto que esté el lector en la historia, el conejo que buscas está sumido en un sueño.',
      'Кітап оқып отырған қоян оқиғаға беріліп кетсе де, саған керегі — түс көріп жатқан қоян.',
      'Mag das lesende Kaninchen auch ganz in seine Geschichte vertieft sein, gesucht ist das Kaninchen, das gerade träumt.',
    ),
    _Cue(
      _sleep,
      'Deliver it discreetly, lest the rabbit curled up under the blanket should stir.',
      'Доставь конфету тихонько, как бы кролик, свернувшийся под одеялом, не проснулся.',
      'Entrégalo con sigilo, no sea que se despierte el conejo acurrucado bajo la manta.',
      'Көрпенің астында бүрісіп жатқан қоян оянып кетпесін, кәмпитті білдіртпей жеткіз.',
      'Liefere das Bonbon unauffällig, damit sich das unter der Decke zusammengerollte Kaninchen nicht regt.',
    ),
    _Cue(
      _flower,
      'Absorbed though he is in his reading, the rabbit with the flower is the one expecting a delivery.',
      'Хотя кролик с цветком и поглощён чтением, доставку ждёт именно он.',
      'Por muy enfrascado que esté en la lectura, es el conejo de la flor quien espera la entrega.',
      'Гүлі бар қоян кітапқа қанша беріліп кетсе де, кәмпитті күтіп отырған — сол.',
      'So vertieft das Kaninchen mit der Blume auch in seine Lektüre sein mag, genau dieses Kaninchen erwartet die Lieferung.',
    ),
    _Cue(
      _flower,
      'Let the open pages guide you, should the blossom by the reader’s ear escape your notice.',
      'Если ты не заметишь цветок у уха читателя, ориентируйся по раскрытым страницам.',
      'Guíate por las páginas abiertas en caso de que se te pase por alto la flor junto a la oreja del lector.',
      'Егер кітап оқып отырған қоянның құлағының тұсындағы гүлді байқамасаң, ашық беттерге қара.',
      'Solltest du die Blume am Ohr des lesenden Kaninchens übersehen, orientiere dich an den offenen Buchseiten.',
    ),
    _Cue(
      _flower,
      'The intended recipient has his paws full, quite literally, with a book.',
      'Лапы адресата в самом буквальном смысле заняты книгой.',
      'El destinatario tiene las patas ocupadas, en el sentido más literal, con un libro.',
      'Кәмпит алатын қоянның қолы бос емес деген осы: алдыңғы екі аяғымен кітап ұстап отыр.',
      'Das gesuchte Kaninchen hat im wahrsten Sinne des Wortes beide Pfoten voll: Es hält ein Buch.',
    ),
  ],
  CefrLevel.c2: [
    _Cue(
      _scarf,
      'Of the pair that haven’t nodded off, rule out the one lost between the covers of a book.',
      'Из двоих, кто ещё не задремал, исключи того, кто с головой ушёл в книгу.',
    ),
    _Cue(
      _scarf,
      'If the recipient’s identity is still in doubt, the way he has bundled up about the neck should give the game away.',
      'Если ты всё ещё сомневаешься, кому предназначена конфета, подсказкой послужит то, как тепло укутана его шея.',
    ),
    _Cue(
      _scarf,
      'Leave the reader to his chapter and the sleeper to his dream. It is their companion who is due a treat.',
      'Оставь читателя за книгой, а соню в мире снов. Угощение полагается их товарищу.',
    ),
    _Cue(
      _sleep,
      'By all means let sleeping rabbits lie. Just leave the candy within paw’s reach.',
      'Пусть спящий кролик и дальше себе спит. Просто положи конфету так, чтобы он мог до неё дотянуться.',
    ),
    _Cue(
      _sleep,
      'Deliver this one on tiptoe. A rustle too many and your recipient will be wide awake.',
      'С этим заказом ступай на цыпочках. Один лишний шорох — и сон адресата как рукой снимет.',
    ),
    _Cue(
      _sleep,
      'The intended recipient is wrapped up in dreams, much as another rabbit is wrapped up in a book.',
      'Адресат погрузился в сновидения так же глубоко, как другой кролик — в книгу.',
    ),
    _Cue(
      _flower,
      'Should the little bloom fail to give its wearer away, his appetite for a good yarn surely will.',
      'Если маленький цветок не выдаст того, кто его носит, то уж страсть к увлекательным историям выдаст наверняка.',
    ),
    _Cue(
      _flower,
      'The recipient has his nose in a book. Spare him the trouble of looking up from the page.',
      'Адресат с головой ушёл в книгу. Избавь его от необходимости отрываться от страницы.',
    ),
    _Cue(
      _flower,
      'The one engrossed in a tale, as opposed to the one dreaming one up, is due the next delivery.',
      'Следующая конфета полагается тому, кто увлечён историей из книги, а не тому, кто сочиняет её во сне.',
    ),
  ],
};
