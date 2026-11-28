@Tags(['peek'])
library;

import 'package:arcadelingo/app/word_sets_view.dart';
import 'package:arcadelingo/data/dictionary/word_sets_prefs_store.dart';
import 'package:arcadelingo/domain/review/review_contract.dart';
import 'package:arcadelingo/domain/review/study_course.dart';
import 'package:arcadelingo/ui/theme.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'peek_harness.dart';

void main() {
  for (final brightness in Brightness.values) {
    testWidgets('Список и выбор слов в теме ${brightness.name}', (
      tester,
    ) async {
      tester.view.physicalSize = peekPhysicalSize;
      tester.view.devicePixelRatio = peekDevicePixelRatio;
      addTearDown(tester.view.reset);
      SharedPreferences.setMockInitialValues({});
      const course = StudyCourse.spanishFromRussian;
      final store = WordSetsPrefsStore(
        await SharedPreferences.getInstance(),
        courseId: course.id,
      );
      const vocabulary = [
        Word(id: 'calle', text: 'calle', translation: 'улица'),
        Word(id: 'mapa', text: 'mapa', translation: 'карта'),
        Word(id: 'tren', text: 'tren', translation: 'поезд'),
        Word(id: 'cuenta', text: 'cuenta', translation: 'счёт'),
        Word(id: 'pan', text: 'pan', translation: 'хлеб'),
        Word(id: 'café', text: 'café', translation: 'кофе'),
      ];
      await store.save(
        level: CefrLevel.a1,
        name: 'В городе',
        wordIds: {'calle', 'mapa', 'tren'},
      );
      await store.save(
        level: CefrLevel.a1,
        name: 'В кафе',
        wordIds: {'café', 'cuenta', 'pan'},
      );
      await tester.pumpWidget(
        MaterialApp(
          debugShowCheckedModeBanner: false,
          theme: wordarcadeTheme(
            brightness: brightness,
            platform: TargetPlatform.android,
          ),
          home: Builder(
            builder:
                (context) => Scaffold(
                  body: Center(
                    child: TextButton(
                      onPressed:
                          () => Navigator.of(context).push(
                            MaterialPageRoute<void>(
                              builder:
                                  (_) => WordSetsScreen(
                                    store: store,
                                    course: course,
                                    level: CefrLevel.a1,
                                    vocabulary: vocabulary,
                                    onPlay: (_) async {},
                                  ),
                            ),
                          ),
                      child: const Text('Открыть'),
                    ),
                  ),
                ),
          ),
        ),
      );
      await tester.tap(find.text('Открыть'));
      await tester.pumpAndSettle();
      await peek(tester, 'word_sets_${brightness.name}');
      final city = store
          .load(CefrLevel.a1)
          .singleWhere((set) => set.name == 'В городе');
      await tester.tap(find.byKey(ValueKey('wordSets.menu.${city.id}')));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Изменить'));
      await tester.pumpAndSettle();
      await peek(tester, 'word_set_editor_${brightness.name}');
    });
  }
}
