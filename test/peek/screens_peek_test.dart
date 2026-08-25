// Снималка экранов. Не тест: ничего не проверяет и всегда зелёная.
//
// Запуск только руками:
//
//   flutter test --tags peek test/peek/
//
// Результат — PNG в test/peek/out/, каталог в .gitignore. Приложить такой
// снимок к задаче — то, чего требует Definition of Done для UI-изменений.
//
// Эталоном ни один из этих файлов не является и стать не может: у голденов
// своя платформа, свой каталог и своя процедура приёмки человеком
// (docs/dev/goldens.md).
//
// Ниже — экраны, у которых голдена нет. Восемь кадров игры голденами уже
// покрыты, и снимать их здесь незачем: за них отвечает CI.

@Tags(['peek'])
library;

import 'dart:io';

import 'package:arcadelingo/app/app_views.dart';
import 'package:arcadelingo/app/attribution_view.dart';
import 'package:flutter_test/flutter_test.dart';

import '../support/ritual_views.dart';
import 'peek_harness.dart';

void main() {
  testWidgets('домашний экран', (tester) async {
    await pumpPeek(tester, PlayView(onPlay: () {}, onSources: () {}));
    await peek(tester, 'home');
  });

  // Тот самый экран из 0.14, ради скриншота которого и понадобилась законная
  // дверь. Читается настоящий assets/ATTRIBUTION.md: снимок обязан показывать
  // документ, который лежит в репозитории, а не выдуманный образец.
  testWidgets('источники', (tester) async {
    final source = File('assets/ATTRIBUTION.md').readAsStringSync();
    await pumpPeek(tester, AttributionView(source: source));
    await peek(tester, 'sources');
  });

  // Домашний экран с серией: после слияния с Фазой 2 на нём соседствуют марка
  // и «Серия: N». Числами это соседство не проверить — вопрос в том, не
  // тесно ли им, — а голдена на домашний экран нет и не планируется.
  testWidgets('домашний экран с серией', (tester) async {
    await pumpPeek(
      tester,
      PlayView(onPlay: () {}, onSources: () {}, ritual: ritualView(days: 5)),
    );
    await peek(tester, 'home_streak');
  });

  // Системный шрифт 2× на том же экране: по нему видно переполнение, которого
  // не видно числами. Голдена на этот случай нет намеренно — там открыта Р7,
  // и эталон закрепил бы сломанную вёрстку как правильную. Снимок ничего не
  // закрепляет, поэтому здесь он уместен.
  testWidgets('домашний экран при системном шрифте 2×', (tester) async {
    await pumpPeek(
      tester,
      PlayView(onPlay: () {}, onSources: () {}),
      textScale: 2,
    );
    await peek(tester, 'home_text2x');
  });
}
