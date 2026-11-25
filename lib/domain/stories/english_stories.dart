part of 'situation_story.dart';

const _englishStories = <CefrLevel, List<_Scene>>{
  CefrLevel.a1: [
    _Scene(
      situation: StorySituation.breakfast,
      words: ['bread', 'milk', 'coffee', 'butter'],
      clue: 'Coffee with milk, please. And bread with butter.',
      readings: {
        'ru': _Reading(
          'Какой заказ принести гостю?',
          [
            'Кофе с молоком и хлеб с маслом',
            'Чёрный кофе и хлеб с маслом',
            'Кофе с молоком и хлеб без масла',
          ],
          'Кофе с молоком, пожалуйста. И хлеб с маслом.',
        ),
        'es': _Reading(
          '¿Qué pedido hay que servir?',
          [
            'Café con leche y pan con mantequilla',
            'Café solo y pan con mantequilla',
            'Café con leche y pan sin mantequilla',
          ],
          'Un café con leche, por favor. Y pan con mantequilla.',
        ),
      },
    ),
    _Scene(
      situation: StorySituation.hotel,
      words: ['key', 'bed', 'room', 'door'],
      clue:
          'Here is your room key. Open the blue door. Your bed is on the left.',
      readings: {
        'ru': _Reading(
          'Какую дверь открыть ключом?',
          ['Синюю', 'Белую', 'Красную'],
          'Вот ключ от твоего номера. Открой синюю дверь. Твоя кровать слева.',
        ),
        'es': _Reading(
          '¿Qué puerta tienes que abrir con la llave?',
          ['La azul', 'La blanca', 'La roja'],
          'Aquí tienes la llave de tu habitación. Abre la puerta azul. Tu cama está a la izquierda.',
        ),
      },
    ),
    _Scene(
      situation: StorySituation.station,
      words: ['train', 'bus', 'clock', 'leave'],
      clue:
          'Look at the clock. It is ten. The train leaves at ten. The bus leaves at eleven.',
      readings: {
        'ru': _Reading(
          'На чём можно уехать прямо сейчас?',
          ['На поезде', 'На автобусе', 'На метро'],
          'Посмотри на часы. Сейчас десять. Поезд отправляется в десять, автобус — в одиннадцать.',
        ),
        'es': _Reading(
          '¿Qué puedes tomar ahora mismo?',
          ['El tren', 'El autobús', 'El metro'],
          'Mira el reloj. Son las diez. El tren sale a las diez y el autobús sale a las once.',
        ),
      },
    ),
  ],
  CefrLevel.a2: [
    _Scene(
      situation: StorySituation.breakfast,
      words: ['menu', 'cereal', 'toast', 'honey'],
      clue:
          'The breakfast menu has cereal and toast. The honey is for the toast. Would you like milk with your cereal?',
      readings: {
        'ru': _Reading(
          'Гость выбрал тост и хочет сладкий завтрак. Что ему подать?',
          ['Тост с мёдом', 'Хлопья с молоком', 'Тост без добавок'],
          'В меню на завтрак хлопья и тост. Мёд подают к тосту. Хотите молоко к хлопьям?',
        ),
      },
    ),
    _Scene(
      situation: StorySituation.hotel,
      words: ['receptionist', 'single', 'double', 'suitcase'],
      clue:
          'The receptionist says, “Your single room is ready. Someone is still in the double room. You can take your suitcase upstairs now.”',
      readings: {
        'ru': _Reading(
          'Ты забронировал номер на одного. Куда нести чемодан?',
          [
            'Наверх, в готовый номер',
            'К стойке, чтобы ждать двухместный номер',
            'На улицу, чтобы ждать автобус',
          ],
          'Администратор говорит, что одноместный номер готов, а двухместный пока занят. Чемодан уже можно нести наверх.',
        ),
      },
    ),
    _Scene(
      situation: StorySituation.station,
      words: ['journey', 'passenger', 'delay', 'schedule'],
      clue:
          'The schedule says ten. There is a delay of half an hour. Passengers can start their journey at half past ten.',
      readings: {
        'ru': _Reading(
          'К какому времени вернуться на платформу?',
          ['К 10:30', 'К 10:00', 'К 11:30'],
          'По расписанию отправление в десять. Задержка на полчаса. Пассажиры смогут отправиться в половине одиннадцатого.',
        ),
      },
    ),
  ],
  CefrLevel.b1: [
    _Scene(
      situation: StorySituation.breakfast,
      words: ['ingredient', 'vegetarian', 'substitute', 'available'],
      clue:
          'You ask about the ingredients in the breakfast sandwich. It contains ham. A cheese sandwich is available as a substitute for vegetarians.',
      readings: {
        'ru': _Reading(
          'Какое блюдо заказать человеку, который не ест мясо?',
          [
            'Сэндвич с сыром',
            'Сэндвич с ветчиной',
            'Сэндвич с ветчиной и сыром',
          ],
          'Вы спрашиваете, из чего состоит сэндвич на завтрак. В нём есть ветчина. Вегетарианцы могут заказать вместо него сэндвич с сыром.',
        ),
      },
    ),
    _Scene(
      situation: StorySituation.hotel,
      words: ['booking', 'confirmation', 'deposit', 'reception'],
      clue:
          'Show your booking confirmation at reception. You can pay the room deposit by card when you collect your key.',
      readings: {
        'ru': _Reading(
          'Что подготовить для получения ключа?',
          [
            'Подтверждение брони и карту для залога',
            'Ключ и квитанцию об оплате завтрака',
            'Только номер комнаты',
          ],
          'Покажите подтверждение брони на стойке регистрации. При получении ключа залог за номер можно внести картой.',
        ),
      },
    ),
    _Scene(
      situation: StorySituation.station,
      words: ['platform', 'exit', 'departure', 'announcement'],
      clue:
          'A departure announcement says, “The train at platform six is going to York. For Leeds, go past the exit to platform two.”',
      readings: {
        'ru': _Reading(
          'Тебе нужно в Лидс. Куда идти?',
          [
            'Мимо выхода на вторую платформу',
            'К поезду на шестой платформе',
            'Через выход на улицу',
          ],
          'Объявляют отправление: поезд у шестой платформы идёт в Йорк. Чтобы уехать в Лидс, пройдите мимо выхода ко второй платформе.',
        ),
      },
    ),
  ],
  CefrLevel.b2: [
    _Scene(
      situation: StorySituation.breakfast,
      words: ['catering', 'contaminate', 'portion', 'label'],
      clue:
          'The catering team has set aside a portion for Maya. It has a green label. Please use the clean spoon so you do not contaminate her food.',
      readings: {
        'ru': _Reading(
          'Как подать Майе её завтрак?',
          [
            'Взять порцию с зелёной этикеткой и чистую ложку',
            'Взять любую порцию и переставить этикетку',
            'Взять порцию с зелёной этикеткой и ложку из общего блюда',
          ],
          'Команда, которая привезла завтрак, отложила для Майи порцию с зелёной этикеткой. Чтобы в еду ничего не попало, нужна чистая ложка.',
        ),
      },
    ),
    _Scene(
      situation: StorySituation.hotel,
      words: ['accommodation', 'vacant', 'lobby', 'incur'],
      clue:
          'Your accommodation is paid for, but the room is still being cleaned. Taking the vacant studio would incur a fee. You are welcome to wait in the lobby.',
      readings: {
        'ru': _Reading(
          'Как заселиться без доплаты?',
          [
            'Подождать в фойе, пока уберут свой номер',
            'Сразу занять свободную студию',
            'Оплатить студию за ночь и ждать в ней',
          ],
          'Проживание уже оплачено, но номер ещё убирают. За свободную студию придётся доплатить. Можно подождать в фойе.',
        ),
      },
    ),
    _Scene(
      situation: StorySituation.station,
      words: ['disrupt', 'route', 'replacement', 'temporarily'],
      clue:
          'Repairs have disrupted the coastal route. The last part of the journey is temporarily covered by a replacement bus. Your train ticket is valid on it.',
      readings: {
        'ru': _Reading(
          'Как закончить поездку по уже купленному билету?',
          [
            'Пересесть на автобус, заменяющий поезд',
            'Купить новый билет на тот же поезд',
            'Остаться в поезде до конца прибрежного маршрута',
          ],
          'Ремонт нарушил движение на прибрежном маршруте. Последний участок временно обслуживает автобус. В нём действует билет на поезд.',
        ),
      },
    ),
  ],
  CefrLevel.c1: [
    _Scene(
      situation: StorySituation.breakfast,
      words: ['complimentary', 'grapefruit', 'invoice', 'beforehand'],
      clue:
          'The breakfast tasting includes fresh grapefruit juice. It is complimentary for guests who book beforehand. If you turn up on the day, the tasting will appear on your invoice.',
      readings: {
        'ru': _Reading(
          'Что сделать, чтобы дегустацию завтрака не включили в счёт?',
          [
            'Забронировать дегустацию заранее',
            'Прийти на дегустацию без брони',
            'Отказаться от грейпфрутового сока и прийти без брони',
          ],
          'В дегустацию завтрака входит свежий грейпфрутовый сок. Для гостей, которые забронировали дегустацию заранее, она бесплатна. Если прийти без брони в тот же день, её включат в счёт.',
        ),
      },
    ),
    _Scene(
      situation: StorySituation.hotel,
      words: ['adjoining', 'unoccupied', 'refurbishment', 'premises'],
      clue:
          'Refurbishment starts tomorrow on the hotel premises. The two adjoining rooms in the east wing will remain unoccupied. We have reserved adjoining rooms in the west wing for your family.',
      readings: {
        'ru': _Reading(
          'Где семья сможет поселиться в соседних номерах?',
          [
            'В западном крыле',
            'В восточном крыле после начала ремонта',
            'По одному номеру в каждом крыле',
          ],
          'Завтра в отеле начнётся ремонт. Два смежных номера в восточном крыле останутся пустыми. Для семьи забронировали смежные номера в западном крыле.',
        ),
      },
    ),
    _Scene(
      situation: StorySituation.station,
      words: ['cessation', 'itinerary', 'transit', 'indefinitely'],
      clue:
          'Your itinerary includes a stop at West Quay. Following the cessation of ferry services, passengers in transit must take the tram there. The ferry terminal is closed indefinitely.',
      readings: {
        'ru': _Reading(
          'Как добраться до следующего пункта маршрута?',
          [
            'Пересесть на трамвай до Уэст-Ки',
            'Дождаться ближайшего парома у терминала',
            'Пропустить Уэст-Ки и остаться в терминале',
          ],
          'В вашем маршруте есть остановка в Уэст-Ки. Паромы перестали ходить, и транзитным пассажирам нужно ехать туда на трамвае. Паромный терминал закрыт на неопределённый срок.',
        ),
      },
    ),
  ],
  CefrLevel.c2: [
    _Scene(
      situation: StorySituation.breakfast,
      words: ['unadulterated', 'calorific', 'palatable', 'residue'],
      clue:
          'The cream blend is the more calorific of the two. The other bottle holds unadulterated orange juice. Stir the fine residue back in if you find the juice more palatable with pulp.',
      readings: {
        'ru': _Reading(
          'Ты хочешь менее калорийный напиток с мякотью. Что выбрать?',
          [
            'Чистый апельсиновый сок и размешать осадок',
            'Сливочную смесь и убрать мякоть',
            'Чистый сок и оставить осадок на дне',
          ],
          'Сливочная смесь калорийнее. Во второй бутылке чистый апельсиновый сок. Если сок с мякотью вам приятнее на вкус, размешайте осевшую мякоть.',
        ),
      },
    ),
    _Scene(
      situation: StorySituation.hotel,
      words: ['hotelier', 'contractual', 'stipulate', 'forfeiture'],
      clue:
          'The hotelier points to a contractual clause. It stipulates that arriving after midnight entails forfeiture of the room unless the guest has given written notice beforehand.',
      readings: {
        'ru': _Reading(
          'Ты приедешь в час ночи. Как сохранить право на номер?',
          [
            'Заранее письменно предупредить отель',
            'Объяснить опоздание уже при получении ключей',
            'Попросить устное подтверждение после полуночи',
          ],
          'Владелец отеля указывает на пункт договора. Если гость приезжает после полуночи без предварительного письменного уведомления, он теряет право на номер.',
        ),
      },
    ),
    _Scene(
      situation: StorySituation.station,
      words: ['reissue', 'vicinity', 'derelict', 'liaise'],
      clue:
          'The station guide was reissued after the old hall became derelict. Passengers needing assistance should liaise with staff in the vicinity of the new entrance, where the shuttle now stops.',
      readings: {
        'ru': _Reading(
          'Где договориться с сотрудником о помощи при посадке?',
          [
            'У нового входа, рядом с остановкой шаттла',
            'В заброшенном зале у старого входа',
            'В шаттле после отправления',
          ],
          'Путеводитель по вокзалу переиздали, когда старый зал обветшал и был заброшен. За помощью нужно обратиться к сотрудникам возле нового входа. Там теперь останавливается шаттл.',
        ),
      },
    ),
  ],
};
