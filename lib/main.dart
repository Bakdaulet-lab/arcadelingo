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
import 'package:arcadelingo/data/srs/leitner_prefs_store.dart';
import 'package:arcadelingo/data/words/words_seed_loader.dart';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  final prefs = await SharedPreferences.getInstance();
  final seed = await loadWordsSeed();
  runApp(WordarcadeApp(store: LeitnerPrefsStore(prefs), seed: seed));
}
