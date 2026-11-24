part of 'situation_story.dart';

const _spanishStories = <CefrLevel, List<_Scene>>{
  CefrLevel.a1: [
    _Scene(
      situation: StorySituation.breakfast,
      words: ['pan', 'mantequilla', 'café', 'leche'],
      clue: 'Un café con leche y pan con mantequilla, por favor.',
      readings: {
        'ru': _Reading(
          'Как приготовить кофе для этого гостя?',
          ['С молоком', 'С маслом', 'Без молока'],
          'Кофе с молоком и хлеб с маслом, пожалуйста.',
        ),
        'en': _Reading(
          'How does the guest want their coffee?',
          ['With milk', 'With butter', 'Without milk'],
          'A coffee with milk and some bread with butter, please.',
        ),
      },
    ),
    _Scene(
      situation: StorySituation.hotel,
      words: ['habitación', 'puerta', 'llave', 'hotel'],
      clue:
          'Aquí tiene la llave de su habitación. En este hotel, su puerta es la azul.',
      readings: {
        'ru': _Reading(
          'Какую дверь открыть ключом?',
          ['Синюю', 'Красную', 'Белую'],
          'Вот ключ от вашего номера. В этой гостинице ваша дверь — синяя.',
        ),
        'en': _Reading(
          'Which door should you unlock?',
          ['The blue door', 'The red door', 'The white door'],
          'Here is your room key. Your door in this hotel is the blue one.',
        ),
      },
    ),
    _Scene(
      situation: StorySituation.station,
      words: ['tren', 'estación', 'cuatro', 'billete'],
      clue:
          'Estás en la estación. Mira tu billete. El tren sale del andén cuatro.',
      readings: {
        'ru': _Reading(
          'С какой платформы отправляется твой поезд?',
          ['С четвёртой', 'Со второй', 'С третьей'],
          'Ты на вокзале. Посмотри на билет. Поезд отправляется с четвёртой платформы.',
        ),
        'en': _Reading(
          'Which platform does your train leave from?',
          ['Platform four', 'Platform two', 'Platform three'],
          'You are at the station. Look at your ticket. The train leaves from platform four.',
        ),
      },
    ),
  ],
  CefrLevel.a2: [
    _Scene(
      situation: StorySituation.breakfast,
      words: ['menú', 'elegir', 'yogur', 'miel'],
      clue:
          'En el menú puedes elegir yogur con miel, yogur con fruta o yogur natural. Para mí, el natural, por favor.',
      readings: {
        'ru': _Reading(
          'Какой йогурт заказать для этого человека?',
          ['Натуральный, без добавок', 'С мёдом', 'С фруктами'],
          'В меню можно выбрать йогурт с мёдом, с фруктами или натуральный. Мне натуральный, пожалуйста.',
        ),
        'en': _Reading(
          'Which yoghurt should you order for this person?',
          ['Plain yoghurt', 'Honey yoghurt', 'Fruit yoghurt'],
          'The menu offers yoghurt with honey, yoghurt with fruit or plain yoghurt. Plain for me, please.',
        ),
      },
    ),
    _Scene(
      situation: StorySituation.hotel,
      words: ['reserva', 'confirmar', 'mostrador', 'ascensor'],
      clue:
          'Primero confirme su reserva en el mostrador. Después, tome el ascensor hasta la segunda planta.',
      readings: {
        'ru': _Reading(
          'Что сделать перед тем, как подняться в номер?',
          [
            'Подтвердить бронь у стойки',
            'Сначала подняться на второй этаж',
            'Отменить бронь у лифта',
          ],
          'Сначала подтвердите бронь у стойки. Затем поднимитесь на лифте на второй этаж.',
        ),
        'en': _Reading(
          'What should you do before going up to your room?',
          [
            'Confirm your reservation at the desk',
            'Go straight to the second floor',
            'Cancel your reservation by the lift',
          ],
          'First confirm your reservation at the desk. Then take the lift to the second floor.',
        ),
      },
    ),
    _Scene(
      situation: StorySituation.station,
      words: ['trayecto', 'destino', 'andén', 'retraso'],
      clue:
          'El tren con destino a León lleva diez minutos de retraso. El trayecto no cambia, pero hoy sale del andén dos.',
      readings: {
        'ru': _Reading(
          'Как теперь сесть на поезд до Леона?',
          [
            'Прийти ко второй платформе к новому времени отправления',
            'Ждать на прежней платформе без задержки',
            'Ехать в другой город со второй платформы',
          ],
          'Поезд до Леона опаздывает на десять минут. Маршрут прежний, но сегодня поезд отправляется со второй платформы.',
        ),
        'en': _Reading(
          'How should you catch the train to León?',
          [
            'Go to platform two for the new departure time',
            'Wait on the old platform for an on-time departure',
            'Take a train to a different city from platform two',
          ],
          'The train to León is ten minutes late. Its route is unchanged, but today it leaves from platform two.',
        ),
      },
    ),
  ],
  CefrLevel.b1: [
    _Scene(
      situation: StorySituation.breakfast,
      words: ['alérgico', 'evitar', 'etiqueta', 'envase'],
      clue:
          'La etiqueta del envase indica que este pan lleva nueces. Un cliente alérgico a las nueces quiere evitarlas. Ha pedido fruta en su lugar.',
      readings: {
        'ru': _Reading(
          'Что подать по просьбе клиента?',
          [
            'Фрукты вместо хлеба',
            'Хлеб из этой упаковки',
            'Фрукты вместе с этим хлебом',
          ],
          'На этикетке упаковки указано, что хлеб содержит грецкие орехи. У клиента аллергия на них, и он хочет их избежать. Вместо хлеба он попросил фрукты.',
        ),
        'en': _Reading(
          'What did the customer ask to be served?',
          [
            'Fruit instead of bread',
            'The bread from this packet',
            'Fruit together with this bread',
          ],
          'The label on the packet says the bread contains walnuts. A customer who is allergic to walnuts wants to avoid them and has asked for fruit instead.',
        ),
      },
    ),
    _Scene(
      situation: StorySituation.hotel,
      words: ['huésped', 'alojarse', 'recepción', 'sábanas'],
      clue:
          'Si va a alojarse con otro huésped, recoja las sábanas para la segunda cama en recepción antes de subir.',
      readings: {
        'ru': _Reading(
          'Что взять у стойки, если в номере будут жить двое?',
          [
            'Простыни для второй кровати',
            'Квитанцию за второй номер',
            'Подушку для первой кровати',
          ],
          'Если вы будете жить с другим гостем, перед подъёмом возьмите на стойке регистрации простыни для второй кровати.',
        ),
        'en': _Reading(
          'What should you collect if two guests are sharing the room?',
          [
            'Sheets for the second bed',
            'A receipt for a second room',
            'A pillow for the first bed',
          ],
          'If you are staying with another guest, collect the sheets for the second bed from reception before going upstairs.',
        ),
      },
    ),
    _Scene(
      situation: StorySituation.station,
      words: ['avería', 'desvío', 'retrasarse', 'comprobar'],
      clue:
          'Por una avería hay un desvío. Para no retrasarse, compruebe el nuevo punto de salida en la pantalla de la estación.',
      readings: {
        'ru': _Reading(
          'Как узнать, куда идти после изменения маршрута?',
          [
            'Проверить на табло новое место отправления',
            'Идти к привычной платформе без проверки',
            'Ждать ремонта у кассы',
          ],
          'Из-за поломки маршрут изменён. Чтобы не опоздать, проверьте новое место отправления на вокзальном табло.',
        ),
        'en': _Reading(
          'How can you find the departure point after the diversion?',
          [
            'Check the station display for the new departure point',
            'Go straight to the usual platform',
            'Wait for the repair at the ticket office',
          ],
          'There is a diversion due to a breakdown. To avoid being late, check the new departure point on the station display.',
        ),
      },
    ),
  ],
  CefrLevel.b2: [
    _Scene(
      situation: StorySituation.breakfast,
      words: ['proveedor', 'existencias', 'perecedero', 'almacenar'],
      clue:
          'El proveedor aún no ha entregado la fruta, así que no quedan existencias de zumo fresco. Sí hay zumo envasado, que podemos almacenar más tiempo que el producto perecedero.',
      readings: {
        'ru': _Reading(
          'Гость хочет сок прямо сейчас. Какой предложить?',
          [
            'Пакетированный сок',
            'Свежевыжатый сок из новой поставки',
            'Свежевыжатый сок из оставшихся фруктов',
          ],
          'Поставщик ещё не привёз фрукты, поэтому запас свежего сока закончился. Есть пакетированный сок, который хранится дольше скоропортящегося свежего.',
        ),
        'en': _Reading(
          'Which juice can you offer a guest right now?',
          [
            'Packaged juice',
            'Fresh juice from the new delivery',
            'Fresh juice made with the remaining fruit',
          ],
          'The supplier has not delivered the fruit yet, so there is no fresh juice left. There is packaged juice, which keeps longer than the perishable fresh product.',
        ),
      },
    ),
    _Scene(
      situation: StorySituation.hotel,
      words: ['anticipo', 'reembolsable', 'cláusula', 'recargo'],
      clue:
          'La cláusula de la reserva dice que el anticipo es reembolsable hasta el lunes. Después podrá cambiar las fechas, pero se aplicará un recargo.',
      readings: {
        'ru': _Reading(
          'Сегодня вторник. Гость хочет перенести поездку. Что позволит бронь?',
          [
            'Изменить даты с доплатой',
            'Вернуть аванс по условию, действовавшему до понедельника',
            'Перенести даты без доплаты',
          ],
          'По условиям брони аванс можно вернуть до понедельника. Позже даты можно изменить, но придётся доплатить.',
        ),
        'en': _Reading(
          'It is Tuesday and the guest wants to postpone the trip. What do the terms allow?',
          [
            'Change the dates for a fee',
            'Claim the refund that was available until Monday',
            'Move the dates at no extra cost',
          ],
          'The booking clause says the advance payment is refundable until Monday. After that, dates may still be changed, but a surcharge applies.',
        ),
      },
    ),
    _Scene(
      situation: StorySituation.station,
      words: ['demora', 'transbordo', 'provisional', 'señalizar'],
      clue:
          'Durante las obras, el transbordo se hace en una parada provisional. Para evitar demoras, siga el recorrido señalizado en azul hasta la parada.',
      readings: {
        'ru': _Reading(
          'Как успеть на пересадку во время ремонта?',
          [
            'По синим указателям пройти к временной остановке',
            'Пересесть у обычной остановки без указателей',
            'Дождаться окончания работ на прежнем месте',
          ],
          'Во время ремонта пересадку делают на временной остановке. Чтобы избежать задержек, идите к ней по маршруту с синими указателями.',
        ),
        'en': _Reading(
          'How do you make the connection during the works?',
          [
            'Follow the blue signs to the temporary stop',
            'Change at the usual stop without following the signs',
            'Wait at the old stop until the works finish',
          ],
          'During the works, passengers change at a temporary stop. To avoid delays, follow the route marked in blue to reach it.',
        ),
      },
    ),
  ],
  CefrLevel.c1: [
    _Scene(
      situation: StorySituation.breakfast,
      words: ['trazabilidad', 'omisión', 'consignar', 'corroborar'],
      clue:
          'La carta promete café de una sola finca, pero hay una omisión en la ficha de trazabilidad. Antes de anunciar el origen, hay que corroborarlo con el proveedor y consignar el dato en la ficha.',
      readings: {
        'ru': _Reading(
          'Что сделать, прежде чем сообщить гостю, с какой фермы кофе?',
          [
            'Уточнить происхождение у поставщика и записать его в карточку',
            'Назвать ферму по памяти и оставить карточку без изменений',
            'Принять обещание в меню за подтверждение происхождения',
          ],
          'В меню обещают кофе с одной фермы, но в карточке учёта происхождения есть пропуск. Прежде чем назвать ферму, нужно подтвердить данные у поставщика и внести их в карточку.',
        ),
        'en': _Reading(
          'What should you do before naming the farm to a guest?',
          [
            'Verify the origin with the supplier and record it on the sheet',
            'Name the farm from memory and leave the sheet unchanged',
            'Treat the promise on the menu as proof of origin',
          ],
          'The menu promises single-farm coffee, but the traceability record is incomplete. Before stating its origin, confirm it with the supplier and record the information.',
        ),
      },
    ),
    _Scene(
      situation: StorySituation.hotel,
      words: ['salvedad', 'sufragar', 'contratiempo', 'aplazar'],
      clue:
          'Si un contratiempo obliga a aplazar su llegada, el hotel sufragará el traslado. La única salvedad es que debe solicitarlo antes de que salga el último autobús.',
      readings: {
        'ru': _Reading(
          'Из-за задержки ты прибудешь позже. Как получить трансфер за счёт отеля?',
          [
            'Запросить его до отправления последнего автобуса',
            'Заказать его после того, как последний автобус уедет',
            'Заказать любой трансфер и показать чек на следующий день',
          ],
          'Если непредвиденная задержка вынуждает отложить приезд, отель покроет расходы на трансфер при условии, что его запросят до отправления последнего автобуса.',
        ),
        'en': _Reading(
          'A setback delays your arrival. How do you get the hotel to cover the transfer?',
          [
            'Request it before the last bus leaves',
            'Request it after the last bus has left',
            'Book any transfer and present the receipt the next day',
          ],
          'If a setback forces you to postpone your arrival, the hotel will cover the transfer provided you request it before the last bus departs.',
        ),
      },
    ),
    _Scene(
      situation: StorySituation.station,
      words: ['cotejar', 'errata', 'desfase', 'corroborar'],
      clue:
          'Al cotejar el billete con la pantalla, verá un desfase de veinte minutos. La taquilla ha corroborado que hay una errata en el billete y que la hora correcta es la de la pantalla.',
      readings: {
        'ru': _Reading(
          'Время на билете и на табло различается. На какое ориентироваться?',
          [
            'На время на табло, подтверждённое кассой',
            'На время в билете, несмотря на опечатку',
            'На время в билете плюс час',
          ],
          'При сравнении билета с табло обнаружится расхождение в двадцать минут. В кассе подтвердили опечатку в билете. Верное время указано на табло.',
        ),
        'en': _Reading(
          'The ticket and the display show different times. Which should you use?',
          [
            'The time on the display, as confirmed by the ticket office',
            'The time on the ticket despite the misprint',
            'The time on the ticket plus one hour',
          ],
          'Comparing the ticket with the display reveals a twenty-minute discrepancy. The ticket office has confirmed a misprint on the ticket. The time on the display is correct.',
        ),
      },
    ),
  ],
};
