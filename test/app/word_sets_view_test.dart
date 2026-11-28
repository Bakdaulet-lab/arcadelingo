import 'package:arcadelingo/app/word_sets_view.dart';
import 'package:arcadelingo/data/dictionary/word_sets_prefs_store.dart';
import 'package:arcadelingo/domain/ports/word_sets_store.dart';
import 'package:arcadelingo/domain/review/review_contract.dart';
import 'package:arcadelingo/domain/review/study_course.dart';
import 'package:arcadelingo/ui/app_strings.dart';
import 'package:arcadelingo/ui/theme.dart';
import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

const _words = [
  Word(id: 'tren', text: 'tren', translation: 'поезд'),
  Word(id: 'custom:andén', text: 'andén', translation: 'платформа'),
  Word(id: 'salir', text: 'salir', translation: 'выходить'),
  Word(
    id: 'hidden',
    text: 'viajero',
    translation: 'путешественник',
    level: CefrLevel.b1,
  ),
];
const _course = StudyCourse.spanishFromRussian;
Finder _key(String suffix) => find.byKey(ValueKey('wordSets.$suffix'));

Future<void> _tap(WidgetTester tester, Finder finder) async {
  await tester.ensureVisible(finder);
  await tester.pumpAndSettle();
  await tester.tap(finder);
  await tester.pumpAndSettle();
}

Future<void> _show(
  WidgetTester tester,
  WordSetsStore store,
  List<WordSet> played, {
  String language = 'ru',
}) async {
  await tester.pumpWidget(
    MaterialApp(
      theme: wordarcadeTheme(),
      locale: Locale(language),
      supportedLocales: const [Locale('en'), Locale('ru'), Locale('es')],
      localizationsDelegates: const [
        AppStrings.delegate,
        ...GlobalMaterialLocalizations.delegates,
      ],
      home: WordSetsScreen(
        store: store,
        vocabulary: _words,
        course: _course,
        level: CefrLevel.a1,
        onPlay: (set) async => played.add(set),
      ),
    ),
  );
  await tester.pumpAndSettle();
}

void main() {
  setUp(() => SharedPreferences.setMockInitialValues({}));

  testWidgets(
    'create and play one personal word, edit membership and name, confirm deletion',
    (tester) async {
      final store = WordSetsPrefsStore(
        await SharedPreferences.getInstance(),
        courseId: _course.id,
      );
      final played = <WordSet>[];
      await _show(tester, store, played);
      expect(find.text('Мои наборы'), findsOneWidget);
      await _tap(tester, _key('create'));
      expect(_key('word.hidden'), findsNothing);
      await tester.enterText(_key('name'), 'На вокзале');
      await tester.enterText(_key('search'), 'ПЛАТФОРМА');
      await tester.pumpAndSettle();
      expect(_key('word.tren'), findsNothing);
      await _tap(tester, _key('word.custom:andén'));
      await _tap(tester, _key('save'));
      final id = store.load(CefrLevel.a1).single.id;
      expect(find.text('На вокзале'), findsOneWidget);
      await _tap(tester, _key('play.$id'));
      expect(played.single.wordIds, {'custom:andén'});
      await _tap(tester, _key('menu.$id'));
      await _tap(tester, find.text('Изменить'));
      await tester.enterText(_key('name'), 'В поездке');
      await tester.enterText(_key('search'), 'TrE');
      await tester.pumpAndSettle();
      await _tap(tester, _key('word.tren'));
      await tester.enterText(_key('search'), '');
      await tester.pumpAndSettle();
      await _tap(tester, _key('selected'));
      expect(_key('word.salir'), findsNothing);
      await _tap(tester, _key('word.custom:andén'));
      await _tap(tester, _key('save'));
      expect(store.load(CefrLevel.a1).single.wordIds, {'tren'});
      expect(find.text('В поездке'), findsOneWidget);

      Future<void> openDelete() async {
        await _tap(tester, _key('menu.$id'));
        await _tap(tester, find.text('Удалить'));
        expect(find.textContaining('В поездке'), findsAtLeastNWidgets(2));
      }

      await openDelete();
      await _tap(tester, find.text('Отмена'));
      expect(store.load(CefrLevel.a1), hasLength(1));
      await openDelete();
      await _tap(tester, _key('confirmDelete'));
      expect(store.load(CefrLevel.a1), isEmpty);
      expect(find.text('В поездке'), findsNothing);
      expect(tester.takeException(), isNull);
    },
  );

  for (final (language, title, nameLabel) in [
    ('es', 'Mis listas', 'Nombre de la lista'),
    ('en', 'My word sets', 'Set name'),
  ]) {
    testWidgets(
      '$language UI, empty and unavailable sets cannot start a game',
      (tester) async {
        final store = WordSetsPrefsStore(
          await SharedPreferences.getInstance(),
          courseId: _course.id,
        );
        await store.save(
          level: CefrLevel.a1,
          name: 'Old',
          wordIds: {'hidden', 'removed'},
        );
        final played = <WordSet>[];
        await _show(tester, store, played, language: language);
        expect(find.text(title), findsOneWidget);
        final old = store.load(CefrLevel.a1).single;
        await _tap(tester, _key('play.${old.id}'));
        expect(played, isEmpty);
        await _tap(tester, _key('create'));
        expect(find.text(nameLabel), findsOneWidget);
        await tester.enterText(_key('name'), 'Draft');
        await _tap(tester, _key('save'));
        final draft = store
            .load(CefrLevel.a1)
            .firstWhere((set) => set.name == 'Draft');
        expect(draft.wordIds, isEmpty);
        await _tap(tester, _key('play.${draft.id}'));
        expect(played, isEmpty);
      },
    );
  }
}
