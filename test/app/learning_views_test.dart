import 'dart:async';

import 'package:arcadelingo/app/learning_views.dart';
import 'package:arcadelingo/domain/ports/word_speech.dart';
import 'package:arcadelingo/domain/review/review_contract.dart';
import 'package:arcadelingo/ui/theme.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_test/flutter_test.dart';

import '../support/bundled_fonts.dart';

const _first = Word(
  id: 'b1.whisper',
  text: 'whisper',
  translation: 'шёпот',
  partOfSpeech: 'noun',
  example: 'She spoke in a whisper.',
  level: CefrLevel.b1,
);
const _second = Word(
  id: 'b1.journey',
  text: 'journey',
  translation: 'путешествие',
  level: CefrLevel.b1,
);
const _long = Word(
  id: 'c2.counterproductively',
  text: 'counterproductively',
  translation: 'в ущерб желаемому результату',
  partOfSpeech: 'adverb',
  level: CefrLevel.c2,
);

class _Speech implements WordSpeech {
  final spoken = <String>[];
  final events = <String>[];
  SpeechResult result = SpeechResult.completed;
  Completer<SpeechResult>? completion;
  Completer<void>? stopCompletion;
  int stops = 0;

  @override
  Future<SpeechResult> speak(String englishText) async {
    spoken.add(englishText);
    events.add('speak:$englishText');
    return completion?.future ?? result;
  }

  @override
  Future<void> stop() async {
    stops++;
    events.add('stop');
    await stopCompletion?.future;
  }
}

Future<void> _pump(
  WidgetTester tester,
  Widget screen, {
  double scale = 1,
}) async {
  tester.view.physicalSize = const Size(960, 1704);
  tester.view.devicePixelRatio = 3;
  tester.platformDispatcher.textScaleFactorTestValue = scale;
  addTearDown(tester.view.reset);
  addTearDown(tester.platformDispatcher.clearAllTestValues);
  await tester.pumpWidget(
    MaterialApp(
      theme: wordarcadeTheme(platform: TargetPlatform.android),
      home: Builder(
        builder:
            (context) => Scaffold(
              body: TextButton(
                onPressed:
                    () => Navigator.of(
                      context,
                    ).push(MaterialPageRoute<void>(builder: (_) => screen)),
                child: const Text('Открыть'),
              ),
            ),
      ),
    ),
  );
  await tester.tap(find.text('Открыть'));
  await tester.pumpAndSettle();
}

Future<void> _tap(WidgetTester tester, Key key) async {
  final finder = find.byKey(key);
  await tester.ensureVisible(finder);
  await tester.pumpAndSettle();
  await tester.tap(finder);
  await tester.pumpAndSettle();
}

void _expectFullText(WidgetTester tester, Key key) {
  final finder = find.byKey(key);
  final paragraph = tester.renderObject<RenderParagraph>(finder);
  expect(paragraph.didExceedMaxLines, isFalse);
  final bounds = tester.getRect(finder);
  expect(bounds.left, greaterThanOrEqualTo(0));
  expect(bounds.right, lessThanOrEqualTo(320.1));
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  setUpAll(loadBundledFonts);

  testWidgets('знакомство: выбранный уровень, перевод и пример до игры', (
    tester,
  ) async {
    var starts = 0;
    await _pump(
      tester,
      WordIntroductionScreen(
        words: const [_first, _second],
        level: CefrLevel.b1,
        speech: _Speech(),
        onStart: () => starts++,
      ),
    );
    expect(find.byKey(LearningKeys.introduction), findsOneWidget);
    expect(find.text('B1'), findsOneWidget);
    expect(find.text('whisper'), findsOneWidget);
    expect(find.text('шёпот'), findsOneWidget);
    expect(find.text('She spoke in a whisper.'), findsOneWidget);
    expect(find.text('journey'), findsNothing);
    expect(starts, 0);
  });

  testWidgets('знакомство: просмотр вперёд и назад не запускает игру', (
    tester,
  ) async {
    final speech = _Speech();
    var starts = 0;
    await _pump(
      tester,
      WordIntroductionScreen(
        words: const [_first, _second],
        level: CefrLevel.b1,
        speech: speech,
        onStart: () => starts++,
      ),
    );
    await _tap(tester, LearningKeys.next);
    expect(find.text('journey'), findsOneWidget);
    expect(find.text('whisper'), findsNothing);
    expect(speech.stops, greaterThanOrEqualTo(1));
    await _tap(tester, LearningKeys.previous);
    expect(find.text('whisper'), findsOneWidget);
    expect(starts, 0);
  });

  testWidgets('озвучивается английское слово текущей карточки', (tester) async {
    final speech = _Speech();
    final semantics = tester.ensureSemantics();
    addTearDown(semantics.dispose);
    await _pump(
      tester,
      WordIntroductionScreen(
        words: const [_first, _second],
        level: CefrLevel.b1,
        speech: speech,
        onStart: () {},
      ),
    );
    expect(find.bySemanticsLabel('Произнести whisper'), findsOneWidget);
    await _tap(tester, LearningKeys.speak);
    expect(speech.spoken, ['whisper']);
    await _tap(tester, LearningKeys.next);
    await _tap(tester, LearningKeys.speak);
    expect(speech.spoken, ['whisper', 'journey']);
    expect(
      speech.events.indexOf('stop'),
      lessThan(speech.events.lastIndexOf('speak:journey')),
    );
  });

  testWidgets('переход в игру ждёт остановки речи и выполняется один раз', (
    tester,
  ) async {
    final speech = _Speech()..stopCompletion = Completer<void>();
    var starts = 0;
    await _pump(
      tester,
      WordIntroductionScreen(
        words: const [_first],
        level: CefrLevel.b1,
        speech: speech,
        onStart: () => starts++,
      ),
    );
    await _tap(tester, LearningKeys.start);
    expect(starts, 0);
    await _tap(tester, LearningKeys.start);
    speech.stopCompletion!.complete();
    await tester.pumpAndSettle();
    expect(starts, 1);
  });

  testWidgets('пропуск знакомства запускает игру после остановки речи', (
    tester,
  ) async {
    final speech = _Speech();
    var starts = 0;
    await _pump(
      tester,
      WordIntroductionScreen(
        words: const [_first, _second],
        level: CefrLevel.b1,
        speech: speech,
        onStart: () => starts++,
      ),
    );
    await _tap(tester, LearningKeys.skip);
    expect(starts, 1);
    expect(speech.stops, greaterThanOrEqualTo(1));
  });

  testWidgets('при сворачивании и возврате назад речь останавливается', (
    tester,
  ) async {
    final speech = _Speech();
    await _pump(
      tester,
      WordIntroductionScreen(
        words: const [_first],
        level: CefrLevel.b1,
        speech: speech,
        onStart: () {},
      ),
    );
    await _tap(tester, LearningKeys.speak);
    final beforePause = speech.stops;
    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.paused);
    await tester.pump();
    expect(speech.stops, greaterThan(beforePause));
    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
    await tester.pump();
    final beforeBack = speech.stops;
    await tester.pageBack();
    await tester.pumpAndSettle();
    expect(speech.stops, greaterThan(beforeBack));
    expect(find.text('Открыть'), findsOneWidget);
  });

  for (final result in [SpeechResult.unavailable, SpeechResult.failed]) {
    testWidgets('ошибка речи $result видна и не мешает начать игру', (
      tester,
    ) async {
      final speech = _Speech()..result = result;
      var starts = 0;
      await _pump(
        tester,
        WordIntroductionScreen(
          words: const [_first],
          level: CefrLevel.b1,
          speech: speech,
          onStart: () => starts++,
        ),
      );
      await _tap(tester, LearningKeys.speak);
      expect(find.byKey(LearningKeys.speechMessage), findsOneWidget);
      final message = tester.widget<Text>(
        find.byKey(LearningKeys.speechMessage),
      );
      expect(message.data, isNotEmpty);
      if (result == SpeechResult.unavailable) {
        expect(message.data!.toLowerCase(), contains('английск'));
      }
      await _tap(tester, LearningKeys.start);
      expect(starts, 1);
      expect(tester.takeException(), isNull);
    });
  }

  testWidgets('запоздалый ответ озвучки после ухода не меняет закрытый экран', (
    tester,
  ) async {
    final speech = _Speech()..completion = Completer<SpeechResult>();
    await _pump(
      tester,
      WordIntroductionScreen(
        words: const [_first],
        level: CefrLevel.b1,
        speech: speech,
        onStart: () {},
      ),
    );
    await _tap(tester, LearningKeys.speak);
    await tester.pageBack();
    await tester.pumpAndSettle();
    speech.completion!.complete(SpeechResult.failed);
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);
    expect(find.byKey(LearningKeys.speechMessage), findsNothing);
  });

  testWidgets('отмена речи не показывается как ошибка', (tester) async {
    final speech = _Speech()..result = SpeechResult.cancelled;
    await _pump(
      tester,
      WordIntroductionScreen(
        words: const [_first],
        level: CefrLevel.b1,
        speech: speech,
        onStart: () {},
      ),
    );
    await _tap(tester, LearningKeys.speak);
    expect(find.byKey(LearningKeys.speechMessage), findsNothing);
  });

  testWidgets(
    'разбор ошибок листает только переданные слова и возвращает к итогам',
    (tester) async {
      final speech = _Speech();
      await _pump(
        tester,
        MistakesReviewScreen(
          words: const [_first, _second],
          level: CefrLevel.b1,
          speech: speech,
        ),
      );
      expect(find.byKey(LearningKeys.mistakes), findsOneWidget);
      expect(find.text('whisper'), findsOneWidget);
      await _tap(tester, LearningKeys.next);
      expect(find.text('journey'), findsOneWidget);
      expect(find.text('путешествие'), findsOneWidget);
      await _tap(tester, LearningKeys.speak);
      expect(speech.spoken, ['journey']);
      final beforeDone = speech.stops;
      await _tap(tester, LearningKeys.done);
      expect(speech.stops, greaterThan(beforeDone));
      expect(find.text('Открыть'), findsOneWidget);
    },
  );

  testWidgets('пустой разбор не придумывает слова', (tester) async {
    await _pump(
      tester,
      MistakesReviewScreen(
        words: const [],
        level: CefrLevel.b1,
        speech: _Speech(),
      ),
    );
    expect(find.byKey(LearningKeys.word), findsNothing);
    expect(find.byKey(LearningKeys.speak), findsNothing);
    await _tap(tester, LearningKeys.done);
    expect(find.text('Открыть'), findsOneWidget);
  });

  for (final mistakes in [false, true]) {
    testWidgets('длинное C2-слово, 320 dp / 2×, разбор=$mistakes', (
      tester,
    ) async {
      final speech = _Speech();
      await _pump(
        tester,
        mistakes
            ? MistakesReviewScreen(
              words: const [_long],
              level: CefrLevel.c2,
              speech: speech,
            )
            : WordIntroductionScreen(
              words: const [_long],
              level: CefrLevel.c2,
              speech: speech,
              onStart: () {},
            ),
        scale: 2,
      );
      expect(tester.takeException(), isNull);
      for (final key in [LearningKeys.word, LearningKeys.translation]) {
        await tester.ensureVisible(find.byKey(key));
        await tester.pumpAndSettle();
        _expectFullText(tester, key);
      }
      await _tap(tester, LearningKeys.speak);
      expect(speech.spoken, [_long.text]);
      await tester.ensureVisible(
        find.byKey(mistakes ? LearningKeys.done : LearningKeys.start),
      );
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);
    });
  }

  test('смешанные уровни не допускаются в знакомство и разбор', () {
    expect(
      () => WordIntroductionScreen(
        words: const [_first, _long],
        level: CefrLevel.b1,
        speech: _Speech(),
        onStart: () {},
      ),
      throwsArgumentError,
    );
    expect(
      () => MistakesReviewScreen(
        words: const [_first, _long],
        level: CefrLevel.b1,
        speech: _Speech(),
      ),
      throwsArgumentError,
    );
  });
}
