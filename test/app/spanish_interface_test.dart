import 'package:arcadelingo/app/app.dart';
import 'package:arcadelingo/app/app_ports.dart';
import 'package:arcadelingo/app/app_views.dart';
import 'package:arcadelingo/app/courses.dart';
import 'package:arcadelingo/app/learning_views.dart';
import 'package:arcadelingo/app/settings_view.dart';
import 'package:arcadelingo/data/dictionary/favorites_prefs_store.dart';
import 'package:arcadelingo/data/settings/settings_prefs_store.dart';
import 'package:arcadelingo/domain/core/result.dart';
import 'package:arcadelingo/domain/log/answer_record.dart';
import 'package:arcadelingo/domain/review/review_contract.dart';
import 'package:arcadelingo/domain/review/study_course.dart';
import 'package:arcadelingo/domain/srs/review_grade.dart';
import 'package:arcadelingo/domain/streak/streak.dart';
import 'package:arcadelingo/features/games/claw_machine/claw_machine_game.dart';
import 'package:arcadelingo/features/games/falling_words/falling_words_run.dart';
import 'package:arcadelingo/features/games/ninja_slash/ninja_run.dart';
import 'package:arcadelingo/ui/word_pronunciation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../support/claw_actions.dart';
import '../support/fake_reminders.dart';
import '../support/in_memory_answer_log.dart';
import '../support/in_memory_stores.dart';

const _fish = ReviewItem(
  word: Word(
    id: 'fish',
    text: 'fish',
    translation: 'рыба',
    partOfSpeech: 'noun',
  ),
  distractors: ['краб', 'улитка', 'кит'],
);
const _pez = ReviewItem(
  word: Word(id: 'pez', text: 'pez', translation: 'рыба', partOfSpeech: 'noun'),
  distractors: ['краб', 'улитка', 'кит'],
);
final _now = DateTime(2026, 11, 18, 10);
const _spanishLanguage = ValueKey('settings.language.es');
const _englishLanguage = ValueKey('settings.language.en');
const _spanishCourse = ValueKey('course.ru-es');
const _englishCourse = ValueKey('course.ru-en');

Future<SharedPreferences> _preferences(
  String locale, {
  bool reminder = false,
}) async {
  SharedPreferences.setMockInitialValues({
    'reminder_settings':
        '{"version":2,"enabled":$reminder,"hour":20,"minute":0,"interfaceLanguage":"$locale"}',
  });
  return SharedPreferences.getInstance();
}

void _size(WidgetTester tester, {double height = 780, double textScale = 1}) {
  tester.view.physicalSize = Size(360, height);
  tester.view.devicePixelRatio = 1;
  tester.platformDispatcher.textScaleFactorTestValue = textScale;
  addTearDown(tester.view.reset);
  addTearDown(tester.platformDispatcher.clearAllTestValues);
}

Future<void> _tap(WidgetTester tester, Finder finder) async {
  await tester.ensureVisible(finder);
  await tester.tap(finder);
  await tester.pumpAndSettle();
}

Future<void> _choose(WidgetTester tester, Key menu, Key item) async {
  await _tap(tester, find.byKey(menu));
  await _tap(tester, find.byKey(item));
}

void main() {
  testWidgets('interface language and selected course persist independently', (
    tester,
  ) async {
    final prefs = await _preferences('ru', reminder: true);
    final reminders = FakeReminders();
    final ports = AppPorts(
      cards: InMemoryCardStore(),
      streaks: InMemoryStreakStore(),
      settings: SettingsPrefsStore(prefs),
      reminders: reminders,
    );
    final deck = CourseDeck(
      course: StudyCourse.spanishFromRussian,
      items: const [_pez],
      cards: InMemoryCardStore(),
      streaks: InMemoryStreakStore(),
      answers: InMemoryAnswerLog(),
    );
    WordarcadeApp app() => WordarcadeApp(
      seed: const Ok([_fish]),
      ports: ports,
      additionalDecks: [deck],
      now: () => _now,
    );
    _size(tester);
    await tester.pumpWidget(app());
    await tester.pumpAndSettle();

    await _tap(tester, find.byKey(AppKeys.settings));
    await _choose(tester, SettingsKeys.language, _spanishLanguage);
    expect(find.text('Ajustes'), findsOneWidget);
    expect(find.byTooltip('Atrás'), findsOneWidget);
    expect(reminders.current?.title, '¿Todo listo para volver a jugar?');
    await _tap(tester, find.byKey(SettingsKeys.time));
    expect(find.text('Hora del recordatorio'), findsOneWidget);
    expect(find.text('Guardar'), findsOneWidget);
    await _tap(tester, find.text('Cancelar'));
    await _tap(tester, find.byTooltip('Atrás'));

    expect(find.text('Inglés · traducciones al ruso'), findsOneWidget);
    await _choose(tester, AppKeys.course, _spanishCourse);
    expect(find.text('Español · traducciones al ruso'), findsOneWidget);
    expect(find.text('Nivel de español'), findsOneWidget);
    await _tap(tester, find.byKey(AppKeys.learn));
    expect(find.text('pez'), findsOneWidget);
    expect(find.text('рыба'), findsOneWidget);
    expect(find.text('Sustantivo'), findsOneWidget);
    await _tap(tester, find.byKey(WordPronunciation.buttonKey));
    expect(find.textContaining('Instala una voz en español'), findsOneWidget);
    await _tap(tester, find.byTooltip('Atrás'));

    await prefs.reload();
    await tester.pumpWidget(const SizedBox());
    await tester.pumpWidget(app());
    await tester.pumpAndSettle();
    expect(find.text('Elige un juego'), findsOneWidget);
    expect(find.text('Español · traducciones al ruso'), findsOneWidget);
    expect(
      prefs.getString('reminder_settings'),
      contains('"interfaceLanguage":"es"'),
    );
    expect(
      prefs.getString('reminder_settings'),
      contains('"courseId":"ru-es"'),
    );

    await _choose(tester, AppKeys.course, _englishCourse);
    expect(find.text('Nivel de inglés'), findsOneWidget);
    await _choose(tester, AppKeys.course, _spanishCourse);
    await _tap(tester, find.byKey(AppKeys.settings));
    await _choose(tester, SettingsKeys.language, _englishLanguage);
    await _tap(tester, find.byTooltip('Back'));
    expect(find.text('Spanish · Russian translations'), findsOneWidget);
    expect(
      prefs.getString('reminder_settings'),
      contains('"interfaceLanguage":"en"'),
    );
    expect(
      prefs.getString('reminder_settings'),
      contains('"courseId":"ru-es"'),
    );
  });

  testWidgets(
    'a Spanish system locale follows the device and respects an override',
    (tester) async {
      final prefs = await _preferences('system');
      _size(tester);
      tester.platformDispatcher.localesTestValue = const [Locale('es', 'MX')];
      await tester.pumpWidget(
        WordarcadeApp(
          ports: AppPorts(
            cards: InMemoryCardStore(),
            streaks: InMemoryStreakStore(),
            settings: SettingsPrefsStore(prefs),
          ),
          seed: const Ok([_fish]),
          followSystemLocale: true,
        ),
      );
      expect(find.text('Elige un juego'), findsOneWidget);
      tester.platformDispatcher.localesTestValue = const [Locale('en', 'US')];
      await tester.pumpAndSettle();
      expect(find.text('Choose a game'), findsOneWidget);
      await _tap(tester, find.byKey(AppKeys.settings));
      await _choose(tester, SettingsKeys.language, _spanishLanguage);
      tester.platformDispatcher.localesTestValue = const [Locale('ru', 'KZ')];
      await tester.pumpAndSettle();
      expect(find.text('Ajustes'), findsOneWidget);
      expect(find.byTooltip('Atrás'), findsOneWidget);
    },
  );

  testWidgets('Spanish settings and language dialog fit 360×640 at 2×', (
    tester,
  ) async {
    final prefs = await _preferences('es', reminder: true);
    _size(tester, height: 640, textScale: 2);
    await tester.pumpWidget(
      WordarcadeApp(
        ports: AppPorts(
          cards: InMemoryCardStore(),
          streaks: InMemoryStreakStore(),
          settings: SettingsPrefsStore(prefs),
        ),
        seed: const Ok([_fish]),
      ),
    );
    await _tap(tester, find.byKey(AppKeys.settings));
    expect(find.text('Ajustes'), findsOneWidget);
    expect(find.text('Recordatorio diario'), findsOneWidget);
    expect(find.text('Sonidos de los juegos'), findsOneWidget);
    await _tap(tester, find.byKey(SettingsKeys.language));
    for (final tag in ['system', 'ru', 'en', 'es']) {
      final row = find.byKey(ValueKey('settings.language.$tag'));
      await tester.ensureVisible(row);
      expect(row.hitTestable(), findsOneWidget);
      expect(tester.getSize(row).height, greaterThanOrEqualTo(48));
    }
    expect(tester.takeException(), isNull);
  });

  for (final (title, gameId) in [
    ('Palabras que caen', 'falling_words'),
    ('Corte ninja', 'ninja_slash'),
    ('Máquina de garra', 'claw_machine'),
  ]) {
    testWidgets('$title starts, records an answer and shows Spanish results', (
      tester,
    ) async {
      final prefs = await _preferences('es');
      final answers = InMemoryAnswerLog();
      _size(tester);
      await tester.pumpWidget(
        WordarcadeApp(
          ports: AppPorts(
            cards: InMemoryCardStore(),
            streaks: InMemoryStreakStore(),
            settings: SettingsPrefsStore(prefs),
            answers: answers,
          ),
          seed: const Ok([_fish]),
          now: () => _now,
        ),
      );
      await tester.pumpAndSettle();
      await _tap(tester, find.text(title));
      final play = find.byKey(AppKeys.play);
      await tester.ensureVisible(play);
      await tester.tap(play);
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 350));
      final claw = gameId == 'claw_machine';
      if (claw) {
        expect(find.text('Atrapar'), findsOneWidget);
        expect(find.text('Pista'), findsOneWidget);
        expect(find.text('рыба'), findsOneWidget);
        await missWithClaw(tester, 'f');
        await spellWithClaw(tester, 'fish');
        await tapClaw(tester, ClawKeys.next);
      } else {
        final ninja = gameId == 'ninja_slash';
        await tester.pump(
          ninja ? NinjaRun.windUpTime : FallingWordsRun.windUpTime,
        );
        await tester.pump(const Duration(milliseconds: 850));
        expect(find.text('fish'), findsOneWidget);
        final answer = find.text('рыба');
        expect(answer, findsOneWidget);
        if (ninja) {
          final center = tester.getCenter(answer);
          final swipe = await tester.startGesture(center - const Offset(30, 0));
          await swipe.moveTo(center + const Offset(30, 0));
          await swipe.up();
        } else {
          await tester.tap(answer);
        }
        await tester.pump();
        await tester.pump(
          ninja ? NinjaRun.correctReveal : FallingWordsRun.correctReveal,
        );
      }

      expect(find.text('Fin de la ronda'), findsOneWidget);
      expect(
        find.text(claw ? 'Aciertos: 0 de 1' : 'Aciertos: 1 de 1'),
        findsOneWidget,
      );
      expect(answers.records.single.wordId, 'fish');
      expect(answers.records.single.gameId, gameId);
      expect(answers.records.single.correct, !claw);
      if (claw) {
        await _tap(tester, find.text('Revisar errores (1)'));
        expect(find.text('Revisión de errores'), findsOneWidget);
        expect(find.text('Traducción correcta'), findsOneWidget);
        expect(find.text('Tu respuesta'), findsOneWidget);
        expect(find.text('рыба'), findsOneWidget);
      }
      await tester.pumpWidget(const SizedBox());
    });
  }

  testWidgets('Spanish progress, dictionary, word details and sources', (
    tester,
  ) async {
    final prefs = await _preferences('es');
    _size(tester);
    final answers = InMemoryAnswerLog();
    await tester.pumpWidget(
      WordarcadeApp(
        seed: const Ok([_fish]),
        ports: AppPorts(
          cards: InMemoryCardStore(),
          streaks: InMemoryStreakStore(),
          settings: SettingsPrefsStore(prefs),
          answers: answers,
          favorites: FavoritesPrefsStore(prefs),
        ),
        now: () => _now,
      ),
    );
    await _tap(tester, find.byKey(AppKeys.progress));
    expect(find.text('Progreso'), findsOneWidget);
    expect(
      find.text('Juega tu primera ronda para ver tu progreso aquí'),
      findsOneWidget,
    );
    await _tap(tester, find.text('Mi diccionario'));
    expect(find.text('Todavía no has visto ninguna palabra'), findsOneWidget);
    await _tap(tester, find.text('Favoritas'));
    expect(find.text('Todavía no tienes palabras favoritas'), findsOneWidget);
    await _tap(tester, find.byTooltip('Atrás'));
    await _tap(tester, find.byTooltip('Atrás'));

    await answers.append(
      AnswerRecord(
        wordId: 'fish',
        at: _now.toUtc(),
        localDay: StreakDay.of(_now),
        grade: ReviewGrade.good,
        correct: true,
        responseTime: const Duration(seconds: 1),
        timeLimit: const Duration(seconds: 5),
        hintsUsed: 0,
        gameId: 'ninja_slash',
        sessionId: 'spanish-ui-history',
      ),
    );
    await _tap(tester, find.byKey(AppKeys.progress));
    expect(find.text('Respuestas por día'), findsOneWidget);
    await _tap(tester, find.text('Mi diccionario'));
    await _tap(tester, find.text('fish'));
    expect(find.text('Ficha de la palabra'), findsOneWidget);
    expect(find.text('Historial de respuestas'), findsOneWidget);
    expect(find.textContaining('Corte ninja'), findsOneWidget);
    await _tap(tester, find.text('Añadir a favoritas'));
    expect(find.text('Quitar de favoritas'), findsOneWidget);
    for (var i = 0; i < 3; i++) {
      await _tap(tester, find.byTooltip('Atrás'));
    }

    // Читаем ассет из бандла, чтобы проверить лицензионную цитату.
    final source = await tester.runAsync(
      () => rootBundle.loadString('assets/ATTRIBUTION.es.md'),
    );
    expect(
      source,
      contains('The CEFR-J Wordlist Version 1.5. Compiled by Yukio Tono'),
    );
    expect(source, contains('CC BY-SA 4.0'));
    await _tap(tester, find.byKey(AppKeys.sources));
    expect(find.text('Fuentes'), findsOneWidget);
    expect(
      find.text('Fuentes y materiales de terceros', findRichText: true),
      findsOneWidget,
    );
  });

  testWidgets('Spanish error screens display localized recovery instructions', (
    tester,
  ) async {
    final prefs = await _preferences('es');
    _size(tester);
    final ports = AppPorts(
      cards: FailingCardStore(),
      streaks: InMemoryStreakStore(),
      settings: SettingsPrefsStore(prefs),
    );
    await tester.pumpWidget(
      WordarcadeApp(ports: ports, seed: const Ok([_fish])),
    );
    await _tap(tester, find.byKey(AppKeys.play));
    expect(find.text('No se pudo leer el progreso'), findsOneWidget);
    expect(find.text('Restablecer progreso'), findsOneWidget);
    expect(find.text('карточки не читаются'), findsNothing);
    await tester.pumpWidget(
      WordarcadeApp(
        ports: ports,
        seed: const Err(Failure('словарь повреждён')),
      ),
    );
    await tester.pumpAndSettle();
    expect(
      find.text('No se pudo leer el diccionario del curso'),
      findsOneWidget,
    );
    expect(find.text('словарь повреждён'), findsNothing);
  });
}
