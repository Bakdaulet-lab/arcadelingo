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

import 'package:arcadelingo/app/app.dart';
import 'package:arcadelingo/app/app_views.dart';
import 'package:arcadelingo/data/srs/leitner_codec.dart';
import 'package:arcadelingo/data/srs/leitner_prefs_store.dart';
import 'package:arcadelingo/domain/core/result.dart';
import 'package:arcadelingo/domain/review/review_contract.dart';
import 'package:arcadelingo/domain/srs/leitner.dart';
import 'package:arcadelingo/features/games/falling_words/falling_words_game.dart';
import 'package:arcadelingo/features/games/falling_words/falling_words_views.dart';
import 'package:flutter/material.dart';
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
  final store = LeitnerPrefsStore(await SharedPreferences.getInstance());
  tester.view.physicalSize = const Size(1080, 2340);
  tester.view.devicePixelRatio = 3;
  addTearDown(tester.view.reset);
  await tester.pumpWidget(
    WordarcadeApp(
      store: store,
      seed: seed ?? Ok(_items(3)),
      now: now ?? () => _t0,
    ),
  );
  return store;
}

/// Документ состояния из карточек по id слова.
String _stateOf(Map<String, LeitnerCard> cards) => encodeLeitnerState(cards);

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
