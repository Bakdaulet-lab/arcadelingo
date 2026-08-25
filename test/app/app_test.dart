// Проводка Гейта-0 (задача 0.8): композиционный корень, экран «Играть»,
// два экрана ошибок и строка итогов, которую считает хост.
//
// Сессия создаётся по тапу «Играть», а не при старте приложения: очередь
// собирается на `now()` и иначе протухает (0.6, docs/dev/context.md).
// Тест «очередь строится на момент тапа» двигает фейковые часы между
// pumpWidget и тапом — если перенести создание сессии в initState, он
// краснеет. Это же и есть его мутационная проверка.
//
// Время здесь такое же, как в тестах игры: только кадры. `pumpAndSettle`
// нельзя — он домотает падение до таймаута, поэтому переход маршрута
// проматывается явным `pump(Δ)`.

import 'dart:io';

import 'package:arcadelingo/app/app.dart';
import 'package:arcadelingo/app/app_ports.dart';
import 'package:arcadelingo/app/app_views.dart';
import 'package:arcadelingo/data/srs/leitner_codec.dart';
import 'package:arcadelingo/data/srs/leitner_prefs_store.dart';
import 'package:arcadelingo/data/streak/streak_prefs_store.dart';
import 'package:arcadelingo/domain/core/result.dart';
import 'package:arcadelingo/domain/review/review_contract.dart';
import 'package:arcadelingo/domain/srs/leitner.dart';
import 'package:arcadelingo/features/games/falling_words/falling_words_game.dart';
import 'package:arcadelingo/features/games/falling_words/falling_words_views.dart';
import 'package:arcadelingo/ui/streak_card.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../support/result.dart';

/// Ключ документа состояния — литералом, как в тесте стора: это контракт
/// персистентности, и переименование обязано сломать тест.
const String _key = 'leitner_state';

/// Момент, в который живут все тесты, кроме теста про протухшую очередь.
final DateTime _t0 = DateTime.utc(2026, 8, 23, 10);

/// id слова по номеру: w01, w02, … Он же текст падающего слова.
String _id(int i) => 'w${i.toString().padLeft(2, '0')}';

/// Верный вариант слова [i].
String _translation(int i) => 'перевод ${_id(i)}';

/// Обманка номер [d] у слова [i].
String _distractor(int i, int d) => 'обманка $d к ${_id(i)}';

ReviewItem _item(int i) => ReviewItem(
  word: Word(id: _id(i), text: _id(i), translation: _translation(i)),
  distractors: [for (var d = 1; d <= 3; d++) _distractor(i, d)],
);

/// Сид из [n] слов.
List<ReviewItem> _items(int n) => [for (var i = 1; i <= n; i++) _item(i)];

/// Приложение на телефонном экране; возвращает стор, по которому сверяют
/// запись. Сид приходит `Result`'ом, а не через `AssetBundle`: разбирать
/// ассет — работа `loadWordsSeed`, а здесь проверяется реакция хоста.
Future<LeitnerPrefsStore> _pumpApp(
  WidgetTester tester, {
  Map<String, Object> prefs = const {},
  Result<List<ReviewItem>>? seed,
  DateTime Function()? now,
}) async {
  SharedPreferences.setMockInitialValues(prefs);
  final instance = await SharedPreferences.getInstance();
  final store = LeitnerPrefsStore(instance);
  tester.view.physicalSize = const Size(1080, 2340);
  tester.view.devicePixelRatio = 3;
  addTearDown(tester.view.reset);
  await tester.pumpWidget(
    DefaultAssetBundle(
      bundle: _DiskBundle(),
      child: WordarcadeApp(
        ports: AppPorts(cards: store, streaks: StreakPrefsStore(instance)),
        seed: seed ?? Ok(_items(3)),
        now: now ?? () => _t0,
      ),
    ),
  );
  return store;
}

/// Документ серии из prefs; null — его ещё нет.
Future<String?> _streakDoc() async =>
    (await SharedPreferences.getInstance()).getString('streak_state');

/// Партия целиком; возвращает число ответов.
///
/// Настоящий путь, а не вызов usecase'а напрямую: сценарии серии проверяются
/// там же, где живёт человек, — через тап «Играть» и настоящие prefs.
///
/// Отвечает на то слово, которое на экране, а не на i-е по счёту: очередь
/// собирает сессия, и какие слова в неё попадут во второй партии, тест знать
/// не обязан. Число ответов возвращается затем же, зачем в тестах usecase'а:
/// верный ответ уводит слово в третью коробку на трое суток, и партия на
/// коротком сиде оказывается пустой. Тест, который этого не заметит, будет
/// ложно-зелёным — «серия не изменилась» станет значить «отвечать было
/// нечего».
Future<int> _playRound(WidgetTester tester) async {
  await _tapAndSettleRoute(tester, AppKeys.play);
  var answered = 0;
  while (find.byKey(FallingWordsKeys.summary).evaluate().isEmpty) {
    if (find.byKey(FallingWordsKeys.nothingToday).evaluate().isNotEmpty) break;
    await tester.pump(const Duration(seconds: 1));
    final word = tester.widget<Text>(find.byKey(FallingWordsKeys.word)).data!;
    await tester.tap(find.text('перевод $word'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));
    answered++;
  }
  await _tapAndSettleRoute(tester, FallingWordsKeys.exit);
  return answered;
}

/// Сид, которого хватает на три партии по пятнадцать слов подряд.
List<ReviewItem> _longSeed() => _items(60);

/// Документ состояния из карточек по id слова.
String _stateOf(Map<String, LeitnerCard> cards) => encodeLeitnerState(cards);

/// Бандл, читающий ассеты прямо с диска.
///
/// Настоящий `rootBundle` в widget-тесте не годится: чтение ассета — это
/// настоящий ввод-вывод, а `pump()` его не дожидается, и экран остаётся
/// пустым. Подмена идёт через штатный `DefaultAssetBundle`, а содержимое
/// берётся то же самое — файл из репозитория, а не выдуманная строка.
class _DiskBundle extends CachingAssetBundle {
  @override
  Future<ByteData> load(String key) async {
    final bytes = File(key).readAsBytesSync();
    return ByteData.view(Uint8List.fromList(bytes).buffer);
  }
}

/// Весь текст, который сейчас нарисован на экране.
///
/// Через `RichText`, а не через `Text`: обычный `Text` собирает `RichText`
/// внутри себя, поэтому один обход ловит и простые строки, и размеченные.
/// Тесту не должно быть важно, каким из двух нарисован конкретный блок.
String _screenText(WidgetTester tester) => tester
    .widgetList<RichText>(find.byType(RichText))
    .map((widget) => widget.text.toPlainText())
    .join('\n');

/// Цитата CEFR-J, дословно.
///
/// Литералом и здесь, и в attribution_test.dart намеренно: это условие
/// чужой лицензии, а не наша строка. Две независимые копии ловят и правку
/// в файле, и правку в разборе; общая константа поймала бы только вторую.
const String _citation =
    'The CEFR-J Wordlist Version 1.5. Compiled by Yukio Tono, Tokyo '
    'University of Foreign Studies. Retrieved from '
    'http://www.cefr-j.org/download.html';

/// Тап по кнопке [key] и переход экрана.
///
/// Два пустых кадра: первый взводит анимацию перехода, дальше 500 мс —
/// с запасом над 300 мс `MaterialPageRoute`. Падение слова за это время
/// уходит на полсекунды из шести, до таймаута далеко.
Future<void> _tapAndSettleRoute(WidgetTester tester, Key key) async {
  await tester.tap(find.byKey(key));
  await tester.pump();
  await tester.pump(const Duration(milliseconds: 500));
}

/// Верный ответ на слово [i] через секунду и промотанная подсветка.
Future<void> _answerCorrectly(WidgetTester tester, int i) async {
  await tester.pump(const Duration(seconds: 1));
  await tester.tap(find.text(_translation(i)));
  await tester.pump();
  await tester.pump(const Duration(milliseconds: 300));
}

/// Промах по слову [i] через секунду и промотанная подсветка.
Future<void> _answerWrongly(WidgetTester tester, int i) async {
  await tester.pump(const Duration(seconds: 1));
  await tester.tap(find.text(_distractor(i, 1)));
  await tester.pump();
  await tester.pump(const Duration(milliseconds: 800));
}

void main() {
  group('Ошибка состояния', () {
    testWidgets('битый документ → текст Failure и кнопка сброса', (
      tester,
    ) async {
      await _pumpApp(tester, prefs: const {_key: 'это не json'});

      await tester.tap(find.byKey(AppKeys.play));
      await tester.pump();

      expect(find.byKey(AppKeys.stateError), findsOneWidget);
      expect(
        find.textContaining('невалидный JSON'),
        findsOneWidget,
        reason: 'на экране причина из Failure, а не «что-то пошло не так»',
      );
      expect(find.byKey(AppKeys.reset), findsOneWidget);
      expect(
        find.byType(FallingWordsGame),
        findsNothing,
        reason: 'играть на битом состоянии нельзя',
      );
    });

    testWidgets('«Сбросить прогресс» → документ удалён, партия началась', (
      tester,
    ) async {
      final store = await _pumpApp(
        tester,
        prefs: const {_key: 'это не json'},
        seed: Ok(_items(2)),
      );
      await tester.tap(find.byKey(AppKeys.play));
      await tester.pump();

      await tester.tap(find.byKey(AppKeys.reset));
      await tester.pump();
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 500));

      expect(
        ok(store.load()),
        isEmpty,
        reason:
            'битого документа больше нет — следующий load это первый запуск',
      );
      expect(
        find.byType(FallingWordsGame),
        findsOneWidget,
        reason: 'сброс ведёт в игру сразу, повторный тап «Играть» не нужен',
      );
      expect(find.byKey(AppKeys.stateError), findsNothing);
    });
  });

  group('Ошибка сида', () {
    testWidgets('битый сид → текст Failure, кнопки сброса нет', (tester) async {
      await _pumpApp(
        tester,
        seed: const Err(Failure('сид слов: слово "apple": text отсутствует')),
      );

      expect(find.byKey(AppKeys.seedError), findsOneWidget);
      expect(find.textContaining('слово "apple"'), findsOneWidget);
      expect(
        find.byKey(AppKeys.reset),
        findsNothing,
        reason: 'дефект сборки: сбрасывать нечего',
      );
      expect(
        find.byKey(AppKeys.play),
        findsNothing,
        reason: 'играть нечем, кнопку показывать незачем',
      );
    });
  });

  group('Серия дней', () {
    testWidgets('до первой партии строки серии нет', (tester) async {
      await _pumpApp(tester);

      expect(find.byKey(AppKeys.streak), findsNothing);
      expect(await _streakDoc(), isNull);
    });

    testWidgets('партия сегодня → документ с сегодняшней датой', (
      tester,
    ) async {
      await _pumpApp(tester);

      await _playRound(tester);

      final doc = await _streakDoc();
      expect(doc, isNotNull);
      expect(doc, contains('"last_day":"2026-08-23"'));
      expect(doc, contains('"current":1'));
    });

    testWidgets('вторая партия в тот же день ничего не меняет', (tester) async {
      await _pumpApp(tester, seed: Ok(_longSeed()));
      await _playRound(tester);
      final afterFirst = await _streakDoc();

      final second = await _playRound(tester);

      expect(
        second,
        greaterThan(0),
        reason: 'иначе тест зелен оттого, что отвечать было нечего',
      );

      expect(
        await _streakDoc(),
        afterFirst,
        reason: 'вторая партия за день — не второй день серии',
      );
    });

    // «Завтра» — присваивание, а не сутки ожидания: часы приходят в приложение
    // функцией, и тест их подменяет.
    testWidgets('партия назавтра продлевает серию', (tester) async {
      var clock = _t0;
      await _pumpApp(tester, seed: Ok(_longSeed()), now: () => clock);
      await _playRound(tester);

      clock = _t0.add(const Duration(days: 1));
      final second = await _playRound(tester);

      expect(second, greaterThan(0));
      final doc = await _streakDoc();
      expect(doc, contains('"current":2'));
      expect(doc, contains('"best":2'));
      expect(doc, contains('"last_day":"2026-08-24"'));
    });

    testWidgets('пропущенный день обрывает серию, рекорд остаётся', (
      tester,
    ) async {
      var clock = _t0;
      await _pumpApp(tester, seed: Ok(_longSeed()), now: () => clock);
      for (final shift in [0, 1, 3]) {
        clock = _t0.add(Duration(days: shift));
        final answered = await _playRound(tester);
        expect(answered, greaterThan(0), reason: 'день $shift: партия пустая');
      }

      final doc = await _streakDoc();
      expect(doc, contains('"current":1'));
      expect(doc, contains('"best":2'));
    });

    testWidgets('после партии домашний экран показывает серию', (tester) async {
      await _pumpApp(tester);

      await _playRound(tester);

      expect(find.byKey(AppKeys.streak), findsOneWidget);
      // Число стоит в пламени, подпись его не повторяет (задача 3.3.1).
      expect(
        tester.widget<Text>(find.byKey(AppKeys.streak)).data,
        'день подряд',
      );
      expect(tester.widget<Text>(find.byKey(flameDigitKey)).data, '1');
    });

    testWidgets('«Сбросить прогресс» убирает и серию тоже', (tester) async {
      // Серия обязана существовать ДО сброса, иначе тест проходит оттого,
      // что удалять было нечего. На этом он уже один раз оказался
      // ложно-зелёным — поймано мутацией «сброс не трогает серию».
      await _pumpApp(
        tester,
        prefs: {
          _key: 'битый документ',
          'streak_state':
              '{"version":1,"current":4,"best":9,"last_day":"2026-08-20"}',
        },
      );
      expect(await _streakDoc(), isNotNull);

      await _tapAndSettleRoute(tester, AppKeys.play);
      expect(find.byKey(AppKeys.stateError), findsOneWidget);
      await _tapAndSettleRoute(tester, AppKeys.reset);

      expect(
        await _streakDoc(),
        isNull,
        reason:
            'серия — это прогресс, и «сбросить прогресс» её тоже сбрасывает',
      );
    });

    testWidgets('битый документ серии тоже даёт экран ошибки', (tester) async {
      await _pumpApp(tester, prefs: {'streak_state': 'битый документ'});

      await _tapAndSettleRoute(tester, AppKeys.play);

      expect(
        find.byKey(AppKeys.stateError),
        findsOneWidget,
        reason: 'молчаливого сброса нет ни у карточек, ни у серии',
      );
      expect(find.byType(FallingWordsGame), findsNothing);
    });
  });

  group('Источники', () {
    // Экран читает assets/ATTRIBUTION.md через rootBundle, а не через
    // подсунутую строку: смысл задачи в том, что в продукте показан тот же
    // файл, который лежит в репозитории. Подмена сделала бы тест зелёным
    // при любом содержимом ассета.
    testWidgets('вход с домашнего экрана открывает «Источники»', (
      tester,
    ) async {
      await _pumpApp(tester);
      expect(find.byKey(AppKeys.sourcesView), findsNothing);

      await _tapAndSettleRoute(tester, AppKeys.sources);

      expect(find.byKey(AppKeys.sourcesView), findsOneWidget);
    });

    testWidgets('с «Источников» есть возврат на домашний экран', (
      tester,
    ) async {
      await _pumpApp(tester);
      await _tapAndSettleRoute(tester, AppKeys.sources);

      await tester.tap(find.byTooltip('Back'));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 500));

      expect(
        find.byKey(AppKeys.play),
        findsOneWidget,
        reason: 'застрять на «Источниках» игрок не должен',
      );
      expect(find.byKey(AppKeys.sourcesView), findsNothing);
    });

    testWidgets('цитата CEFR-J показана дословно', (tester) async {
      await _pumpApp(tester);
      await _tapAndSettleRoute(tester, AppKeys.sources);

      expect(
        _screenText(tester),
        contains(_citation),
        reason:
            'условие лицензии CEFR-J — «cite properly», и адресовано оно '
            'пользователю: репозитория он не видит',
      );
    });

    testWidgets('условия использования показаны целиком', (tester) async {
      await _pumpApp(tester);
      await _tapAndSettleRoute(tester, AppKeys.sources);
      final text = _screenText(tester);

      expect(
        text,
        contains('CEFR-J vocabulary and grammar profile datasets can be used'),
      );
      expect(
        text,
        contains('any damage resulting from using the dataset.'),
        reason: 'обрезанные условия хуже отсутствующих: они выглядят полными',
      );
    });

    testWidgets('разметка съедена, а не показана', (tester) async {
      await _pumpApp(tester);
      await _tapAndSettleRoute(tester, AppKeys.sources);
      final text = _screenText(tester);

      expect(text, isNot(contains('**')), reason: 'жирный');
      expect(text, isNot(contains('##')), reason: 'заголовок');
      expect(text, isNot(contains('`')), reason: 'код');
      expect(
        text,
        isNot(contains('<https://')),
        reason: 'угловые скобки автоссылки',
      );
    });

    testWidgets('шрифт назван: без этого OFL не соблюдён', (tester) async {
      await _pumpApp(tester);
      await _tapAndSettleRoute(tester, AppKeys.sources);

      expect(_screenText(tester), contains('Rubik'));
    });

    testWidgets('«Полные тексты лицензий» открывают штатный экран', (
      tester,
    ) async {
      await _pumpApp(tester);
      await _tapAndSettleRoute(tester, AppKeys.sources);

      // Кнопка внизу документа, на телефонный экран сразу не попадает.
      await tester.ensureVisible(find.byKey(AppKeys.licenses));
      await tester.pump();
      await _tapAndSettleRoute(tester, AppKeys.licenses);

      expect(
        find.byType(LicensePage),
        findsOneWidget,
        reason:
            'четыре килобайта OFL — юридическое приложение, ему место на '
            'штатном экране, а не в цитировании',
      );
    });
  });

  group('Сессия по тапу', () {
    testWidgets('debug-баннера нет: он перекрывает счёт (задача 0.9)', (
      tester,
    ) async {
      await _pumpApp(tester);

      expect(
        tester
            .widget<MaterialApp>(find.byType(MaterialApp))
            .debugShowCheckedModeBanner,
        isFalse,
        reason:
            'баннер садится в верхний правый угол — ровно туда, где HUD '
            'держит счёт; голдены его отключают у себя, а приложение — тут',
      );
    });

    testWidgets('до тапа «Играть» игры нет', (tester) async {
      await _pumpApp(tester);

      expect(find.byKey(AppKeys.play), findsOneWidget);
      expect(find.byType(FallingWordsGame), findsNothing);
    });

    testWidgets('очередь строится на момент тапа, а не при старте', (
      tester,
    ) async {
      // w01 станет готовым в 12:00, w02 — новое слово без карточки.
      var clock = DateTime.utc(2026, 8, 23, 11);
      await _pumpApp(
        tester,
        prefs: {
          _key: _stateOf({
            _id(1): LeitnerCard(box: 2, due: DateTime.utc(2026, 8, 23, 12)),
          }),
        },
        seed: Ok(_items(2)),
        now: () => clock,
      );

      clock = DateTime.utc(2026, 8, 23, 13);
      await _tapAndSettleRoute(tester, AppKeys.play);

      expect(
        find.text(_id(1)),
        findsOneWidget,
        reason:
            'готовое слово идёт впереди нового; сессия, созданная на старте '
            'приложения, в 11:00 сочла бы w01 несозревшим и начала с w02',
      );
    });

    testWidgets('ответ уходит в хранилище через onCardsChanged', (
      tester,
    ) async {
      final store = await _pumpApp(tester, seed: Ok(_items(2)));

      await _tapAndSettleRoute(tester, AppKeys.play);
      await _answerCorrectly(tester, 1);

      expect(
        ok(store.load()).keys,
        contains(_id(1)),
        reason: 'без unawaited(store.save(cards)) прогресс не переживёт выход',
      );
    });
  });

  group('Кнопки итогов', () {
    testWidgets('«Выйти» возвращает на экран «Играть»', (tester) async {
      await _pumpApp(tester, seed: Ok(_items(1)));
      await _tapAndSettleRoute(tester, AppKeys.play);
      await _answerCorrectly(tester, 1);
      expect(find.byKey(FallingWordsKeys.summary), findsOneWidget);

      await _tapAndSettleRoute(tester, FallingWordsKeys.exit);

      expect(find.byKey(AppKeys.play), findsOneWidget);
      expect(find.byType(FallingWordsGame), findsNothing);
    });

    testWidgets('«Ещё раз» начинает новую партию', (tester) async {
      await _pumpApp(tester, seed: Ok(_items(2)));
      await _tapAndSettleRoute(tester, AppKeys.play);
      await _answerWrongly(tester, 1);
      await _answerWrongly(tester, 2);
      expect(find.byKey(FallingWordsKeys.summary), findsOneWidget);

      await _tapAndSettleRoute(tester, FallingWordsKeys.playAgain);

      expect(
        find.text(_id(1)),
        findsOneWidget,
        reason: 'промахнутые слова в коробке 1 готовы прямо сейчас',
      );
      expect(
        find.byIcon(Icons.favorite),
        findsNWidgets(3),
        reason: 'партия новая: жизни целы',
      );
    });
  });

  group('Строка итогов', () {
    testWidgets('промахнулся → «Ещё есть слова»', (tester) async {
      await _pumpApp(tester, seed: Ok(_items(1)));

      await _tapAndSettleRoute(tester, AppKeys.play);
      await _answerWrongly(tester, 1);

      expect(
        find.text('Ещё есть слова — сыграй ещё раунд'),
        findsOneWidget,
        reason:
            'промах отправил слово в коробку 1 с due == now: оно готово '
            'прямо сейчас, и «Ещё раз» его реально покажет',
      );
    });

    testWidgets(
      'всё верно, но сид не кончился → «Слова на сегодня кончились»',
      (tester) async {
        // Шестнадцать слов при цели в пятнадцать: одно в раунд не попадёт.
        await _pumpApp(tester, seed: Ok(_items(16)));

        await _tapAndSettleRoute(tester, AppKeys.play);
        for (var i = 1; i <= 15; i++) {
          await _answerCorrectly(tester, i);
        }

        expect(find.byKey(FallingWordsKeys.summary), findsOneWidget);
        expect(
          find.text('Слова на сегодня кончились'),
          findsOneWidget,
          reason: 'готовых нет, но неначатые слова в сиде остались',
        );
      },
    );

    testWidgets('всё верно и сид кончился → «Возвращайся завтра»', (
      tester,
    ) async {
      await _pumpApp(tester, seed: Ok(_items(2)));

      await _tapAndSettleRoute(tester, AppKeys.play);
      await _answerCorrectly(tester, 1);
      await _answerCorrectly(tester, 2);

      expect(find.byKey(FallingWordsKeys.summary), findsOneWidget);
      expect(find.text('Возвращайся завтра'), findsOneWidget);
    });
  });
}
