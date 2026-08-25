// Экран прогресса: сходятся ли числа с тем, что записано.
//
// Первый потребитель журнала ответов, и проверяется он на настоящей БД:
// `totals()` и `perDay()` — это SQL, а SQL, проверенный только через фейк
// порта, не проверен вовсе (разбор в `context.md`, задача 3.3.1).
//
// Голдена у экрана нет намеренно: он собран из текста и прямоугольников, и
// всё, что на нём может сломаться, ловится числами. Эталон просил бы
// человека принимать картинку там, где картинка ничего не добавляет.

import 'package:arcadelingo/app/app.dart';
import 'package:arcadelingo/app/app_views.dart';
import 'package:arcadelingo/app/progress_view.dart';
import 'package:arcadelingo/data/log/drift_answer_log.dart';
import 'package:arcadelingo/data/log/history_database.dart';
import 'package:arcadelingo/data/srs/leitner_codec.dart';
import 'package:arcadelingo/data/srs/leitner_prefs_store.dart';
import 'package:arcadelingo/data/streak/streak_codec.dart';
import 'package:arcadelingo/data/streak/streak_prefs_store.dart';
import 'package:arcadelingo/domain/core/result.dart';
import 'package:arcadelingo/domain/log/answer_record.dart';
import 'package:arcadelingo/domain/srs/leitner.dart';
import 'package:arcadelingo/domain/srs/review_grade.dart';
import 'package:arcadelingo/domain/streak/streak.dart';
import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../support/review_items.dart';
import '../support/sqlite_for_tests.dart';

/// Среда, 26 августа 2026.
final DateTime _t0 = DateTime(2026, 8, 26, 10);

AnswerRecord _answer({
  required int day,
  required bool correct,
  String wordId = 'w01',
}) {
  final at = DateTime.utc(2026, 8, day, 12);
  return AnswerRecord(
    wordId: wordId,
    at: at,
    localDay: StreakDay(2026, 8, day),
    grade: correct ? ReviewGrade.good : ReviewGrade.again,
    correct: correct,
    responseTime: const Duration(seconds: 2),
    timeLimit: const Duration(seconds: 6),
    hintsUsed: 0,
    gameId: 'falling_words',
    sessionId: 'сессия-$day',
  );
}

void main() {
  setUpAll(useTestSqlite);

  late HistoryDatabase db;
  late DriftAnswerLog log;

  setUp(() {
    db = HistoryDatabase(NativeDatabase.memory());
    log = DriftAnswerLog(db);
  });

  tearDown(() => db.close());

  /// Экран сам по себе, на настоящем журнале и настоящих сторах prefs.
  Future<void> pumpScreen(
    WidgetTester tester, {
    Map<String, Object> prefs = const {},
  }) async {
    SharedPreferences.setMockInitialValues(prefs);
    final instance = await SharedPreferences.getInstance();
    tester.view.physicalSize = const Size(1080, 2340);
    tester.view.devicePixelRatio = 3;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(
      MaterialApp(
        home: ProgressScreen(
          answers: log,
          cards: LeitnerPrefsStore(instance),
          streaks: StreakPrefsStore(instance),
          now: () => _t0,
        ),
      ),
    );
    // Три запроса к БД — настоящий ввод-вывод: `pump()` его не дожидается.
    await tester.pumpAndSettle();
  }

  /// Значение в строке блока: текст справа от подписи.
  String valueOf(WidgetTester tester, Key block, String label) {
    final row = find.ancestor(of: find.text(label), matching: find.byType(Row));
    final texts =
        tester
            .widgetList<Text>(
              find.descendant(of: row.first, matching: find.byType(Text)),
            )
            .map((t) => t.data)
            .toList();
    return texts.last!;
  }

  group('Пустое состояние', () {
    testWidgets('журнал пуст — приглашение, а не четыре нуля', (tester) async {
      await pumpScreen(tester);

      expect(find.byKey(ProgressKeys.empty), findsOneWidget);
      expect(find.byKey(ProgressKeys.view), findsNothing);
      expect(find.textContaining('Сыграй первую партию'), findsOneWidget);
    });

    testWidgets('карточки есть, ответов нет — всё равно приглашение', (
      tester,
    ) async {
      await pumpScreen(
        tester,
        prefs: {
          LeitnerPrefsStore.key: encodeLeitnerState({
            'w01': LeitnerCard(box: 5, due: DateTime.utc(2026, 9, 20)),
          }),
        },
      );

      expect(
        find.byKey(ProgressKeys.empty),
        findsOneWidget,
        reason: 'прогресс меряется ответами, а не наличием документа',
      );
    });
  });

  group('Числа сходятся с записанным', () {
    testWidgets('слова разложены по трём группам', (tester) async {
      await log.append(_answer(day: 26, correct: true));
      await pumpScreen(
        tester,
        prefs: {
          LeitnerPrefsStore.key: encodeLeitnerState({
            'w01': LeitnerCard(box: 1, due: _t0),
            'w02': LeitnerCard(box: 3, due: _t0),
            'w03': LeitnerCard(box: 4, due: _t0),
            'w04': LeitnerCard(box: 5, due: _t0),
            'w05': LeitnerCard(box: 5, due: _t0),
          }),
        },
      );

      expect(valueOf(tester, ProgressKeys.words, 'Выучено'), '2');
      expect(valueOf(tester, ProgressKeys.words, 'В работе'), '2');
      expect(valueOf(tester, ProgressKeys.words, 'Трудные'), '1');
    });

    testWidgets('ответы и доля верных — из журнала', (tester) async {
      for (final correct in [true, true, false]) {
        await log.append(_answer(day: 26, correct: correct));
      }

      await pumpScreen(tester);

      expect(valueOf(tester, ProgressKeys.answers, 'Всего'), '3');
      expect(
        valueOf(tester, ProgressKeys.answers, 'Верных'),
        '66%',
        reason: 'два из трёх — 66, а не 67: делим, а не округляем',
      );
    });

    testWidgets('дней с ответами — сколько разных, а не сколько ответов', (
      tester,
    ) async {
      await log.append(_answer(day: 24, correct: true));
      await log.append(_answer(day: 24, correct: true));
      await log.append(_answer(day: 26, correct: true));

      await pumpScreen(tester);

      expect(valueOf(tester, ProgressKeys.days, 'С ответами'), '2');
    });

    testWidgets('лучшая серия — из документа серии, с русским счётом', (
      tester,
    ) async {
      await log.append(_answer(day: 26, correct: true));

      await pumpScreen(
        tester,
        prefs: {
          StreakPrefsStore.key: encodeStreakState(
            StreakState(current: 2, best: 21, lastDay: StreakDay(2026, 8, 26)),
          ),
        },
      );

      expect(valueOf(tester, ProgressKeys.days, 'Лучшая серия'), '21 день');
    });
  });

  group('Полоса за две недели', () {
    /// Столбики полосы по порядку.
    List<SeriesBar> bars(WidgetTester tester) =>
        tester.widgetList<SeriesBar>(find.byType(SeriesBar)).toList();

    // Литерал, а не `progressDays`: тест, сверяющийся с той же константой,
    // которую проверяет, зелен при любом её значении. Мутация «сократить
    // отрезок до недели» ловится только числом из SPEC.
    testWidgets('ровно четырнадцать столбиков', (tester) async {
      await log.append(_answer(day: 26, correct: true));

      await pumpScreen(tester);

      expect(bars(tester), hasLength(14));
    });

    testWidgets('столбики стоят в календарном порядке, последний — сегодня', (
      tester,
    ) async {
      await log.append(_answer(day: 26, correct: true));

      await pumpScreen(tester);

      final days = bars(tester).map((b) => b.day.day).toList();
      expect(days.last, StreakDay(2026, 8, 26));
      expect(days.first, StreakDay(2026, 8, 13));
      for (var i = 1; i < days.length; i++) {
        expect(days[i], days[i - 1].next, reason: 'дырка на позиции $i');
      }
    });

    // Мутация «полоса берёт пустые сводки» ловится только сверкой чисел:
    // четырнадцать столбиков нарисуются и без единого ответа.
    testWidgets('числа столбиков — это ответы тех дней', (tester) async {
      await log.append(_answer(day: 24, correct: true));
      await log.append(_answer(day: 24, correct: false));
      await log.append(_answer(day: 26, correct: true));

      await pumpScreen(tester);

      final byDay = {
        for (final bar in bars(tester)) bar.day.day: bar.day.answers,
      };
      expect(byDay[StreakDay(2026, 8, 24)], 2);
      expect(byDay[StreakDay(2026, 8, 25)], 0);
      expect(byDay[StreakDay(2026, 8, 26)], 1);
    });

    testWidgets('день с одним ответом виден, день без ответов — нет', (
      tester,
    ) async {
      await log.append(_answer(day: 26, correct: true));
      for (var i = 0; i < 40; i++) {
        await log.append(_answer(day: 25, correct: true));
      }

      await pumpScreen(tester);

      final byDay = {for (final bar in bars(tester)) bar.day.day: bar};
      final lonely = byDay[StreakDay(2026, 8, 26)]!;
      final empty = byDay[StreakDay(2026, 8, 23)]!;
      final peak = lonely.peak;

      expect(
        barHeight(answers: lonely.day.answers, peak: peak),
        greaterThanOrEqualTo(seriesMinBar),
        reason: 'один ответ из сорока — всё равно видимый столбик',
      );
      expect(empty.day.answers, 0);
    });

    testWidgets('день вне отрезка полосу не растит', (tester) async {
      // 1 августа — на 25 дней раньше сегодняшнего, вне двух недель.
      await log.append(_answer(day: 1, correct: true));
      await log.append(_answer(day: 26, correct: true));

      await pumpScreen(tester);

      expect(bars(tester), hasLength(14));
      expect(
        valueOf(tester, ProgressKeys.answers, 'Всего'),
        '2',
        reason: 'в итогах он есть — итоги за всё время, а не за две недели',
      );
    });

    testWidgets('системный шрифт 2× полосу не ломает', (tester) async {
      for (var day = 14; day <= 26; day++) {
        await log.append(_answer(day: day, correct: true));
      }

      SharedPreferences.setMockInitialValues(const {});
      final instance = await SharedPreferences.getInstance();
      tester.view.physicalSize = const Size(1080, 2340);
      tester.view.devicePixelRatio = 3;
      addTearDown(tester.view.reset);
      await tester.pumpWidget(
        MaterialApp(
          home: MediaQuery(
            data: const MediaQueryData(textScaler: TextScaler.linear(2)),
            child: ProgressScreen(
              answers: log,
              cards: LeitnerPrefsStore(instance),
              streaks: StreakPrefsStore(instance),
              now: () => _t0,
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(tester.takeException(), isNull);
    });
  });

  // Высота столбика — чистая арифметика, и проверяется как арифметика.
  // Через виджет её видно только косвенно: мутация «всегда во всю высоту»
  // оставалась зелёной, потому что ни один тест не сравнивал столбики между
  // собой.
  group('Высота столбика', () {
    test('день без ответов — дорожка во всю высоту', () {
      expect(barHeight(answers: 0, peak: 40), seriesHeight);
    });

    test('самый высокий день занимает всю высоту', () {
      expect(barHeight(answers: 40, peak: 40), seriesHeight);
    });

    test('половина пика — половина высоты', () {
      expect(barHeight(answers: 20, peak: 40), seriesHeight / 2);
    });

    test('маленький день строго ниже пика', () {
      expect(
        barHeight(answers: 1, peak: 40),
        lessThan(barHeight(answers: 40, peak: 40)),
        reason: 'иначе полоса перестаёт быть полосой',
      );
    });

    test('один ответ из сорока всё равно виден', () {
      expect(
        barHeight(answers: 1, peak: 40),
        greaterThanOrEqualTo(seriesMinBar),
      );
    });

    test('день с ответом и день без отличаются высотой', () {
      expect(
        barHeight(answers: 1, peak: 40),
        isNot(barHeight(answers: 0, peak: 40)),
      );
    });
  });

  group('Вход с домашнего экрана', () {
    testWidgets('кнопка «Прогресс» открывает экран и с него можно уйти', (
      tester,
    ) async {
      SharedPreferences.setMockInitialValues(const {});
      final instance = await SharedPreferences.getInstance();
      tester.view.physicalSize = const Size(1080, 2340);
      tester.view.devicePixelRatio = 3;
      addTearDown(tester.view.reset);
      await tester.pumpWidget(
        WordarcadeApp(
          store: LeitnerPrefsStore(instance),
          streakStore: StreakPrefsStore(instance),
          seed: Ok(wordItems(3)),
          now: () => _t0,
          answerLog: log,
        ),
      );

      expect(find.byKey(ProgressKeys.empty), findsNothing);

      await tester.tap(find.byKey(AppKeys.progress));
      await tester.pumpAndSettle();

      // По ключу экрана, а не по тексту «Прогресс»: так называется и кнопка
      // на домашнем, и тест проходил бы, никуда не перейдя.
      expect(find.byKey(ProgressKeys.empty), findsOneWidget);

      await tester.binding.handlePopRoute();
      await tester.pumpAndSettle();

      expect(find.byKey(AppKeys.play), findsOneWidget);
    });
  });
}
