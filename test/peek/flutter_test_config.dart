// Настройка peek-съёмки: только шрифты.
//
// Компаратор голденов здесь НЕ подменяется и вообще не участвует. Это не
// экономия и не забывчивость: peek пишет PNG напрямую, ничего ни с чем не
// сравнивает и не может ни принять эталон, ни его испортить. Единственный
// способ попасть в test/golden/images/ остаётся прежним — человек, artefact
// с CI и `mv` руками (docs/dev/goldens.md).
//
// Шрифты нужны по той же причине, что и голденам: без них тестовый движок
// рисует каждую букву прямоугольником, и снимок экрана становится
// бессмысленным ровно тогда, когда его собираются показать человеку.

import 'dart:async';

import 'package:flutter_test/flutter_test.dart';

import '../support/bundled_fonts.dart';

Future<void> testExecutable(FutureOr<void> Function() testMain) async {
  TestWidgetsFlutterBinding.ensureInitialized();
  await loadBundledFonts();
  await testMain();
}
