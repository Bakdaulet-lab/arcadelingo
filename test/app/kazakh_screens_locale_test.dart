import 'package:arcadelingo/app/attribution_view.dart';
import 'package:arcadelingo/app/confused_words_view.dart';
import 'package:arcadelingo/app/daily_word_view.dart';
import 'package:arcadelingo/app/dictionary_view.dart';
import 'package:arcadelingo/app/learning_views.dart';
import 'package:arcadelingo/app/progress_view.dart';
import 'package:arcadelingo/app/story_views.dart';
import 'package:arcadelingo/app/word_sets_view.dart';
import 'package:arcadelingo/data/attribution_loader.dart';
import 'package:arcadelingo/data/dictionary/custom_words_prefs_store.dart';
import 'package:arcadelingo/data/dictionary/favorites_prefs_store.dart';
import 'package:arcadelingo/data/dictionary/word_sets_prefs_store.dart';
import 'package:arcadelingo/domain/learning/confused_words.dart';
import 'package:arcadelingo/domain/log/answer_record.dart';
import 'package:arcadelingo/domain/ports/word_speech.dart';
import 'package:arcadelingo/domain/review/review_contract.dart';
import 'package:arcadelingo/domain/review/study_course.dart';
import 'package:arcadelingo/domain/settings/app_settings.dart';
import 'package:arcadelingo/domain/srs/leitner.dart';
import 'package:arcadelingo/domain/srs/review_grade.dart';
import 'package:arcadelingo/domain/stories/situation_story.dart';
import 'package:arcadelingo/domain/streak/streak.dart';
import 'package:arcadelingo/features/recall/recall_screen.dart';
import 'package:arcadelingo/ui/app_strings.dart';
import 'package:arcadelingo/ui/theme.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../support/bundled_fonts.dart';
import '../support/daily_word_fixture.dart';
import '../support/fake_review_session.dart';
import '../support/in_memory_answer_log.dart';
import '../support/in_memory_stores.dart';

const _kk = AppStrings(InterfaceLanguage.kazakh);
const _spanishCourse = StudyCourse.spanishFromEnglish;
const _level = CefrLevel.a1;
const _ticket = Word(
  id: 'billete',
  text: 'billete',
  translation: 'ticket',
  partOfSpeech: 'noun',
);
const _platform = Word(
  id: 'anden',
  text: 'andén',
  translation: 'platform',
  partOfSpeech: 'noun',
);
const _detailedWord = Word(
  id: 'counterproductively',
  text: 'counterproductively',
  translation: 'в ущерб желаемому результату',
  partOfSpeech: 'adverb',
  example: 'They acted counterproductively.',
  level: CefrLevel.c2,
);
const _departure = SituationStory(
  situation: StorySituation.station,
  firstRound: [ReviewItem(word: _ticket)],
  secondRound: [ReviewItem(word: _platform)],
  clue: 'El tren sale del andén cuatro.',
  question: 'Which platform should you go to?',
  choices: ['Platform two', 'Platform four', 'Platform eight'],
  correctIndex: 1,
  explanation: 'The train leaves from platform four.',
);

Finder _key(String name) => find.byKey(ValueKey(name));

class _AttributionBundle extends CachingAssetBundle {
  _AttributionBundle(this.kazakh);

  final ByteData kazakh;

  @override
  Future<ByteData> load(String key) async {
    expect(key, kazakhAttributionAssetPath);
    return kazakh;
  }
}

void _phone(WidgetTester tester) {
  tester.view.physicalSize = const Size(360, 740);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.reset);
}

Future<void> _open(
  WidgetTester tester,
  Widget screen, {
  Brightness brightness = Brightness.dark,
}) async {
  await tester.pumpWidget(
    MaterialApp(
      locale: const Locale('kk', 'KZ'),
      supportedLocales: const [Locale('kk')],
      localizationsDelegates: const [
        AppStrings.delegate,
        ...GlobalMaterialLocalizations.delegates,
      ],
      theme: wordarcadeTheme(brightness: brightness),
      builder:
          (context, child) => MediaQuery(
            data: MediaQuery.of(
              context,
            ).copyWith(textScaler: const TextScaler.linear(1.25)),
            child: child!,
          ),
      home: screen,
    ),
  );
  await tester.pumpAndSettle();
}

Future<void> _tap(WidgetTester tester, Finder target) async {
  await tester.ensureVisible(target);
  await tester.pumpAndSettle();
  await tester.tap(target);
  await tester.pumpAndSettle();
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  setUpAll(loadBundledFonts);

  testWidgets('Kazakh introduction and review retain the course content', (
    tester,
  ) async {
    _phone(tester);
    await _open(
      tester,
      WordIntroductionScreen(
        words: const [_detailedWord],
        level: CefrLevel.c2,
        speech: const NoopWordSpeech(),
        onStart: () {},
      ),
    );
    expect(find.byKey(LearningKeys.introduction), findsOneWidget);
    expect(find.text(_kk.wordPreview), findsOneWidget);
    expect(find.text(_kk.readAndListen), findsOneWidget);
    expect(find.text(_detailedWord.text), findsOneWidget);
    expect(find.text(_detailedWord.translation), findsOneWidget);
    expect(find.text(_detailedWord.example!), findsOneWidget);
    final introduction = tester.element(find.byType(WordIntroductionScreen));
    expect(MaterialLocalizations.of(introduction).backButtonTooltip, 'Артқа');

    await _open(
      tester,
      MistakesReviewScreen(
        words: const [_detailedWord],
        level: CefrLevel.c2,
        speech: const NoopWordSpeech(),
        outcomes: const {
          'counterproductively': ReviewOutcome(
            correct: false,
            responseTime: Duration(seconds: 2),
            timeLimit: Duration(seconds: 5),
            selectedAnswer: 'с пользой для дела',
          ),
        },
      ),
      brightness: Brightness.light,
    );
    expect(find.byKey(LearningKeys.mistakes), findsOneWidget);
    expect(find.text('Қателерді талдау'), findsOneWidget);
    expect(find.text(_kk.correctTranslation), findsOneWidget);
    expect(find.text(_kk.yourAnswer), findsOneWidget);
    expect(find.text('с пользой для дела'), findsOneWidget);
    expect(find.text(_detailedWord.translation), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('Kazakh progress opens its localized dictionary action', (
    tester,
  ) async {
    _phone(tester);
    final date = DateTime.utc(2026, 11, 28, 12);
    final history =
        InMemoryAnswerLog()
          ..records.add(
            AnswerRecord(
              wordId: _ticket.id,
              at: date,
              localDay: StreakDay.of(date),
              grade: ReviewGrade.good,
              correct: true,
              responseTime: const Duration(seconds: 1),
              timeLimit: const Duration(seconds: 6),
              hintsUsed: 0,
              gameId: 'falling_words',
              sessionId: 'kazakh-progress',
            ),
          );
    var openedDictionary = 0;
    await _open(
      tester,
      ProgressScreen(
        answers: history,
        cards: InMemoryCardStore({_ticket.id: LeitnerCard(box: 3, due: date)}),
        streaks: InMemoryStreakStore(),
        now: () => date,
        onDictionary: () => openedDictionary++,
      ),
    );
    expect(find.text('Ілгерілеу'), findsOneWidget);
    expect(find.text(_kk.learned), findsOneWidget);
    expect(find.text(_kk.answersByDay), findsOneWidget);
    await _tap(tester, find.text(_kk.personalDictionary));
    expect(openedDictionary, 1);
    expect(tester.takeException(), isNull);
  });

  testWidgets(
    'Kazakh dictionary form saves Spanish and English text as entered',
    (tester) async {
      _phone(tester);
      SharedPreferences.setMockInitialValues({});
      final prefs = await SharedPreferences.getInstance();
      final store = CustomWordsPrefsStore(prefs, courseId: _spanishCourse.id);
      await _open(
        tester,
        DictionaryScreen(
          course: _spanishCourse,
          level: _level,
          items: const [],
          answers: InMemoryAnswerLog(),
          favorites: FavoritesPrefsStore(prefs, courseId: _spanishCourse.id),
          speech: const NoopWordSpeech(),
          gameTitles: const {},
          customWords: store,
        ),
      );
      expect(find.text(_kk.personalDictionary), findsOneWidget);
      await _tap(tester, _key('dictionary.add-word'));
      expect(find.text('Сөз немесе тіркес (Испан тілі)'), findsOneWidget);
      expect(find.text(_kk.customTranslationLabel('en')), findsOneWidget);
      await _tap(tester, find.text(_kk.save));
      expect(find.text(_kk.enterWord), findsOneWidget);
      await tester.enterText(_key('customWord.text'), 'la cuenta');
      await tester.enterText(_key('customWord.translation'), 'the bill');
      await _tap(tester, find.text(_kk.save));
      final saved = store.load(_level).single;
      expect(saved.text, 'la cuenta');
      expect(saved.translation, 'the bill');
      await _tap(tester, find.text(saved.text));
      expect(find.text(_kk.answerHistory), findsOneWidget);
      expect(find.byTooltip('Артқа'), findsOneWidget);
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets('word sets show Kazakh edit controls and keep the chosen words', (
    tester,
  ) async {
    _phone(tester);
    SharedPreferences.setMockInitialValues({});
    final store = WordSetsPrefsStore(
      await SharedPreferences.getInstance(),
      courseId: _spanishCourse.id,
    );
    await _open(
      tester,
      WordSetsScreen(
        course: _spanishCourse,
        level: _level,
        vocabulary: const [_ticket, _platform],
        store: store,
        onPlay: (_) async {},
      ),
      brightness: Brightness.light,
    );
    expect(find.text(_kk.wordSets), findsOneWidget);
    await _tap(tester, _key('wordSets.create'));
    expect(find.text(_kk.wordSetName), findsOneWidget);
    expect(find.text(_kk.wordSetSearch), findsOneWidget);
    await tester.enterText(_key('wordSets.name'), 'Сапар');
    await _tap(tester, _key('wordSets.word.billete'));
    await _tap(tester, _key('wordSets.save'));
    final saved = store.load(_level).single;
    expect(saved.wordIds, {_ticket.id});
    await _tap(tester, _key('wordSets.menu.${saved.id}'));
    await _tap(tester, find.text(_kk.edit));
    expect(find.text(_kk.editWordSet), findsOneWidget);
    expect(find.text('Сапар'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('word-pair directions are Kazakh in a Russian-source course', (
    tester,
  ) async {
    _phone(tester);
    const first = Word(id: 'whisper', text: 'whisper', translation: 'шёпот');
    const second = Word(
      id: 'murmur',
      text: 'murmur',
      translation: 'бормотание',
    );
    await _open(
      tester,
      ConfusedWordsScreen(
        course: StudyCourse.englishFromRussian,
        level: _level,
        answers: InMemoryAnswerLog(),
        vocabulary: const [first, second],
        initialPairs: Future.value([
          ConfusedWordPair(
            first: first,
            second: second,
            mistakes: 2,
            lastMistakeAt: DateTime.utc(2026, 11, 28),
          ),
        ]),
      ),
    );
    expect(find.text('Шатастыратын сөздерім'), findsOneWidget);
    await _tap(tester, find.text(_kk.practisePair));
    expect(find.text(_kk.pickByMeaning), findsOneWidget);
    expect(find.textContaining('В разговоре'), findsNothing);
    Finder prompt(Word word, {required bool inMessage}) => find.text(
      _kk.confusionMeaningPrompt(word.translation, inMessage: inMessage),
    );
    final current = [first, second].singleWhere(
      (word) => prompt(word, inMessage: false).evaluate().isNotEmpty,
    );
    final other = current == first ? second : first;
    await _tap(tester, find.text(current.text));
    expect(
      find.text('${current.text} — ${current.translation}'),
      findsOneWidget,
    );
    await _tap(tester, _key('confusions.next'));
    expect(prompt(other, inMessage: true), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets(
    'Kazakh recall keeps the meaning and answer in course languages',
    (tester) async {
      _phone(tester);
      final session = FakeReviewSession(const [ReviewItem(word: _ticket)]);
      await _open(
        tester,
        RecallScreen(
          session: session,
          vocabulary: const [_ticket, _platform],
          course: _spanishCourse,
          level: _level,
          seed: 7,
          onComplete: () {},
          onExit: () {},
        ),
      );
      expect(find.text('Сөзді еске түсір'), findsOneWidget);
      expect(find.text('Мұны испанша қалай айтады?'), findsOneWidget);
      expect(find.text(_ticket.translation), findsOneWidget);
      await _tap(tester, _key('recall.options'));
      await _tap(tester, find.text(_ticket.text));
      expect(session.reports.single.outcome.correct, isTrue);
      await _tap(tester, _key('recall.next'));
      expect(_key('recall.summary'), findsOneWidget);
      expect(find.text(_kk.recallWithHelp), findsOneWidget);
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets('Kazakh stories localize actions without translating exercises', (
    tester,
  ) async {
    _phone(tester);
    await _open(
      tester,
      SituationStoriesScreen(
        course: _spanishCourse,
        level: _level,
        stories: const [_departure],
        playStage: (_, _) async => true,
      ),
      brightness: Brightness.light,
    );
    expect(find.text('Үйге қайтар жолда'), findsOneWidget);
    await _tap(tester, _key('story.station'));
    expect(find.text(_kk.storyRound(1)), findsOneWidget);
    expect(find.text(_kk.startStoryRound), findsOneWidget);
    await _tap(tester, _key('story.play'));
    await _tap(tester, _key('story.play'));
    expect(find.text(_kk.storyFinal), findsOneWidget);
    expect(find.text(_departure.clue), findsOneWidget);
    expect(find.text(_departure.question), findsOneWidget);
    await _tap(tester, _key('story.answer.0'));
    expect(find.text(_kk.tryStoryAnswerAgain), findsOneWidget);
    await _tap(tester, _key('story.answer.1'));
    expect(find.text(_kk.storyComplete), findsOneWidget);
    expect(find.text(_departure.explanation), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('Kazakh word of the day validates, saves and shares a win', (
    tester,
  ) async {
    _phone(tester);
    final store = MemoryDailyStore();
    String? shared;
    await _open(
      tester,
      DailyWordScreen(
        puzzle: dailyFixture(),
        store: store,
        onShare: (payload) async => shared = payload,
      ),
    );
    expect(find.text('Күн сөзі'), findsOneWidget);
    expect(find.text('пляж'), findsOneWidget);
    final input = _key('dailyWord.input');
    await tester.ensureVisible(input);
    await tester.enterText(input, 'zzzzz');
    await _tap(tester, _key('dailyWord.submit'));
    expect(find.text(_kk.dailyWordUnknown), findsOneWidget);
    await tester.enterText(input, 'playa');
    await _tap(tester, _key('dailyWord.submit'));
    expect(store.record!.guesses, ['playa']);
    expect(find.text('Сөзді таптың!'), findsOneWidget);
    await _tap(tester, _key('dailyWord.share'));
    expect(shared, contains('Күн сөзі'));
    expect(shared, isNot(contains('playa')));
    expect(tester.takeException(), isNull);
  });

  testWidgets('Kazakh sources show the bundled Kazakh credits and licenses', (
    tester,
  ) async {
    _phone(tester);
    final data = await tester.runAsync(
      () => rootBundle.load(kazakhAttributionAssetPath),
    );
    await _open(tester, AttributionScreen(bundle: _AttributionBundle(data!)));
    expect(find.text('Дереккөздер'), findsOneWidget);
    expect(find.byType(AttributionView), findsOneWidget);
    final document = tester.widget<AttributionView>(
      find.byType(AttributionView),
    );
    expect(
      find.text('Дереккөздер және үшінші тарап материалдары'),
      findsOneWidget,
    );
    expect(document.source, contains('CEFR-J'));
    expect(document.source, contains(RegExp('[ӘәҚқҢңҮүҰұІіҒғӨө]')));
    expect(find.text(_kk.licenses), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
}
