/// Точка входа: разрешить асинхронные зависимости и отдать их корню.
///
/// Здесь только то, что нельзя сделать внутри дерева виджетов, — два
/// `await`. Что делать с их результатами, решает `WordarcadeApp`:
/// `lib/app/app.dart`.
///
/// Состояние читается не здесь, хотя `SharedPreferences` уже под рукой:
/// сессия строится по тапу «Играть» (0.6), и чтение состояния идёт тем же
/// тапом. Прочитанное на старте успело бы устареть.
library;

import 'package:arcadelingo/app/app.dart';
import 'package:arcadelingo/data/log/drift_answer_log.dart';
import 'package:arcadelingo/data/log/drift_event_log.dart';
import 'package:arcadelingo/data/log/history_database.dart';
import 'package:arcadelingo/data/srs/leitner_prefs_store.dart';
import 'package:arcadelingo/data/streak/streak_prefs_store.dart';
import 'package:arcadelingo/data/words/words_seed_loader.dart';
import 'package:arcadelingo/ui/theme.dart';
import 'package:drift_flutter/drift_flutter.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:shared_preferences/shared_preferences.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  _registerFontLicense();
  final prefs = await SharedPreferences.getInstance();
  final seed = await loadWordsSeed();
  // Одна база на два журнала: у них одна природа и одна миграция. Файл
  // открывается лениво, при первой записи, — журналы не на пути старта.
  final history = HistoryDatabase(driftDatabase(name: 'wordarcade_answers'));
  runApp(
    WordarcadeApp(
      store: LeitnerPrefsStore(prefs),
      streakStore: StreakPrefsStore(prefs),
      seed: seed,
      // Файл открывается лениво, при первой записи: журнал не на пути
      // старта, и ждать его здесь незачем.
      answerLog: DriftAnswerLog(history),
      eventLog: DriftEventLog(history),
    ),
  );
}

/// Отдаёт лицензию шрифта в `showLicensePage`.
///
/// Не формальность: OFL требует распространять текст лицензии вместе со
/// шрифтом, а шрифт вшит в приложение. Реестр — единственное место, где он
/// доезжает до пользователя.
void _registerFontLicense() {
  LicenseRegistry.addLicense(() async* {
    final text = await rootBundle.loadString('assets/fonts/OFL.txt');
    yield LicenseEntryWithLineBreaks([wordarcadeFont], text);
  });
}
