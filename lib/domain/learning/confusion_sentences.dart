part of 'confusion_practice.dart';

// Each gap accepts the exact displayed form. Approved glosses bind the
// sentence to a sense (e.g. mañana "tomorrow", not mañana "morning").
typedef _Sentence = ({String gap, String russian, String other});

const _spanishSentences = <String, _Sentence>{
  'traer': (
    gap: '¿Puedes ___ mis gafas cuando vengas a mi casa?',
    russian: 'приносить|принести',
    other: 'bring|to bring',
  ),
  'tomar': (
    gap: 'Al entrar, puedes ___ un número de la máquina y esperar tu turno.',
    russian: 'брать|взять',
    other: 'take|to take',
  ),
  'comprar': (
    gap: 'Quiero ___ ese libro. ¿Cuánto cuesta?',
    russian: 'покупать|купить',
    other: 'buy|to buy',
  ),
  'vender': (
    gap: 'Ya no uso mi bici y la quiero ___ por cien euros.',
    russian: 'продавать|продать',
    other: 'sell|to sell',
  ),
  'hoy': (
    gap: 'El examen es ___, dentro de diez minutos.',
    russian: 'сегодня',
    other: 'today',
  ),
  'ayer': (
    gap: 'Es martes. Vi a Marta ___, el lunes.',
    russian: 'вчера',
    other: 'yesterday',
  ),
  'mañana': (
    gap: 'Es martes. Te llamaré ___, el miércoles.',
    russian: 'завтра',
    other: 'tomorrow',
  ),
  'autobús': (
    gap: 'El ___ de la línea 12 para en esta calle.',
    russian: 'автобус',
    other: 'bus',
  ),
  'tren': (
    gap: 'El ___ tiene seis vagones y circula sobre raíles.',
    russian: 'поезд',
    other: 'train',
  ),
  'llave': (
    gap: 'Meto la ___ en la cerradura y la giro.',
    russian: 'ключ',
    other: 'key',
  ),
  'puerta': (
    gap: 'Antes de entrar, llama a la ___.',
    russian: 'дверь',
    other: 'door',
  ),
  'agua': (
    gap: 'Tengo sed. ¿Me das un vaso de ___ del grifo?',
    russian: 'вода',
    other: 'water',
  ),
  'leche': (
    gap: 'Esta vaca da diez litros de ___ al día.',
    russian: 'молоко',
    other: 'milk',
  ),
  'zumo': (
    gap: 'Exprime dos naranjas y sirve el ___ en un vaso.',
    russian: 'сок',
    other: 'juice',
  ),
  'café': (
    gap: 'Para hacer ___, primero muelo los granos tostados.',
    russian: 'кофе',
    other: 'coffee',
  ),
  'té': (
    gap: 'Dejo las hojas de ___ en agua caliente tres minutos.',
    russian: 'чай',
    other: 'tea',
  ),
  'escuchar': (
    gap: 'Me pongo los auriculares para ___ mi canción favorita.',
    russian: 'слушать',
    other: 'listen|to listen',
  ),
  'oír': (
    gap: 'Habla más alto. Con tanto ruido apenas te puedo ___.',
    russian: 'слышать|услышать',
    other: 'hear|to hear',
  ),
  'descuento': (
    gap: 'Con este ___ del diez por ciento, pagas menos.',
    russian: 'скидка',
    other: 'discount',
  ),
  'recibo': (
    gap: 'Ya he pagado. ¿Me da el ___ como justificante?',
    russian: 'чек|квитанция',
    other: 'receipt',
  ),
  'despegar': (
    gap: 'El avión espera en la pista, listo para ___ rumbo a Lima.',
    russian: 'взлетать|взлететь',
    other: 'take off|to take off',
  ),
  'aterrizar': (
    gap: 'Ya se ve la pista desde el aire. Vamos a ___ en Lima.',
    russian: 'приземляться|приземлиться',
    other: 'land|to land',
  ),
  'matiz': (
    gap: '«Cansado» y «agotado» se parecen, pero hay un ___ de intensidad.',
    russian: 'оттенок смысла',
    other: 'nuance',
  ),
  'premisa': (
    gap: 'Este argumento parte de una ___ falsa y por eso no me convence.',
    russian: 'исходная посылка',
    other: 'premise',
  ),
  'falacia': (
    gap: 'Decir que algo es cierto solo porque lo cree mucha gente es una ___.',
    russian: 'логическая ошибка',
    other: 'fallacy',
  ),
  'corolario': (
    gap: 'Este resultado se deduce directamente del teorema: es un ___ suyo.',
    russian: 'логическое следствие',
    other: 'corollary',
  ),
};

const _englishSentences = <String, _Sentence>{
  'bring': (
    gap: 'Can you ___ me my glasses? They are on your desk.',
    russian: 'приносить|принести',
    other: 'traer',
  ),
  'take': (
    gap: 'You can ___ a free map from the box.',
    russian: 'брать|взять',
    other: 'tomar',
  ),
  'buy': (
    gap: 'I want to ___ this jacket. How much does it cost?',
    russian: 'покупать|купить',
    other: 'comprar',
  ),
  'sell': (
    gap: 'I no longer use my bike. I want to ___ it for fifty dollars.',
    russian: 'продавать|продать',
    other: 'vender',
  ),
  'today': (
    gap: 'The concert is ___, in just ten minutes.',
    russian: 'сегодня',
    other: 'hoy',
  ),
  'yesterday': (
    gap: 'It is Friday. I met Sam ___, on Thursday.',
    russian: 'вчера',
    other: 'ayer',
  ),
  'tomorrow': (
    gap: 'It is Friday. I will see Sam ___, on Saturday.',
    russian: 'завтра',
    other: 'mañana',
  ),
  'train': (
    gap: 'Our ___ has six carriages and runs on rails.',
    russian: 'поезд',
    other: 'tren',
  ),
  'bus': (
    gap: 'The school ___ stops outside our house to pick us up.',
    russian: 'автобус',
    other: 'autobús',
  ),
  'key': (
    gap: 'I put my ___ in the lock and turn it.',
    russian: 'ключ',
    other: 'llave',
  ),
  'door': (
    gap: 'Please knock on the ___ before you come in.',
    russian: 'дверь',
    other: 'puerta',
  ),
  'listen': (
    gap: 'Put your headphones on and ___ to this song.',
    russian: 'слушать',
    other: 'escuchar',
  ),
  'hear': (
    gap: 'Can you speak louder? I can hardly ___ you.',
    russian: 'слышать|услышать',
    other: 'oír',
  ),
  'water': (
    gap: 'I filled my glass with cold ___ from the tap.',
    russian: 'вода',
    other: 'agua',
  ),
  'milk': (
    gap: 'This cow gives ten litres of ___ a day.',
    russian: 'молоко',
    other: 'leche',
  ),
  'juice': (
    gap: 'Squeeze two oranges and pour the ___ into a glass.',
    russian: 'сок',
    other: 'jugo|zumo',
  ),
  'coffee': (
    gap: 'I grind roasted beans to make my morning ___.',
    russian: 'кофе',
    other: 'café',
  ),
  'tea': (
    gap: 'Let the ___ leaves sit in hot water for three minutes.',
    russian: 'чай',
    other: 'té',
  ),
  'spoon': (gap: 'I eat soup with a ___.', russian: 'ложка', other: 'cuchara'),
  'fork': (
    gap: 'Use the four points of your ___ to pick up the potato.',
    russian: 'вилка',
    other: 'tenedor',
  ),
  'satellite': (
    gap: 'The Moon is a natural ___ of the Earth.',
    russian: 'спутник',
    other: 'satélite',
  ),
  'comet': (
    gap: 'We saw a ___ with a long, bright tail in the night sky.',
    russian: 'комета',
    other: 'cometa',
  ),
  'insufficient': (
    gap: 'The evidence was ___ to prove the case, so we needed more.',
    russian: 'недостаточный',
    other: 'insuficiente',
  ),
  'redundant': (
    gap:
        'The final sentence is ___. It repeats the previous one word for word.',
    russian: 'избыточный',
    other: 'redundante',
  ),
  'manicure': (
    gap: 'I booked a ___ to have my fingernails shaped and polished.',
    russian: 'маникюр',
    other: 'manicura',
  ),
  'pedicure': (
    gap: 'I booked a ___ to have my toenails trimmed.',
    russian: 'педикюр',
    other: 'pedicura',
  ),
  'jarring': (
    gap: 'The sudden screech was so ___ that everyone covered their ears.',
    russian: 'режущий слух',
    other: 'estridente',
  ),
  'melodious': (
    gap: 'Her ___ voice made even a simple scale sound like a song.',
    russian: 'мелодичный',
    other: 'melodioso',
  ),
};
