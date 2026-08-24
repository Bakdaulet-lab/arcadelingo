// Настройка голден-тестов: шрифты и компаратор, который никогда не пишет
// эталон сам.
//
// Файл лежит в test/golden/, а не в test/, намеренно: flutter test ищет
// ближайший flutter_test_config.dart вверх по дереву, поэтому загрузка
// шрифтов не платится при каждом прогоне быстрых тестов.
//
// Процедура обновления эталонов человеком — docs/dev/goldens.md.

import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

/// Начертания Roboto, которые нужны Material 3: w400, w500 и w700.
///
/// Одного regular мало — движок синтезировал бы жирный сам, и заголовки на
/// эталоне отличались бы от того, что рисует телефон.
const List<String> _robotoFiles = [
  'roboto-regular.ttf',
  'roboto-medium.ttf',
  'roboto-bold.ttf',
];

/// Где в дереве Flutter лежат шрифты Material.
const String _materialFontsPath = 'bin/cache/artifacts/material_fonts';

Future<void> testExecutable(FutureOr<void> Function() testMain) async {
  TestWidgetsFlutterBinding.ensureInitialized();
  await _loadRoboto();
  await _loadBundledFonts();
  final local = goldenFileComparator as LocalFileComparator;
  goldenFileComparator = _HumanReviewedComparator(
    local.basedir.resolve('flutter_test_config.dart'),
  );
  await testMain();
}

/// Roboto из кеша SDK.
///
/// В репозиторий не кладём: версия Flutter зафиксирована, а при её смене
/// эталоны поедут от движка отрисовки независимо от того, чья копия .ttf
/// лежала рядом.
Future<void> _loadRoboto() async {
  final directory = _materialFonts();
  final loader = FontLoader('Roboto');
  for (final name in _robotoFiles) {
    final file = File.fromUri(directory.uri.resolve(name));
    if (!file.existsSync()) {
      throw StateError(_missingFontsMessage(file.path));
    }
    final bytes = await file.readAsBytes();
    loader.addFont(
      Future.value(
        ByteData.view(bytes.buffer, bytes.offsetInBytes, bytes.lengthInBytes),
      ),
    );
  }
  await loader.load();
}

/// Шрифты из ассетов самого приложения — здесь это MaterialIcons.
///
/// Иконки несут половину смысла экрана: сердца, крест у промаха, галочка у
/// верного варианта. Без них голден снимет прямоугольники и будет зелёным.
Future<void> _loadBundledFonts() async {
  final manifest =
      json.decode(await rootBundle.loadString('FontManifest.json')) as List;
  final families = <String>[];
  for (final entry in manifest) {
    final family = (entry as Map)['family'] as String;
    families.add(family);
    final loader = FontLoader(family);
    for (final font in entry['fonts'] as List) {
      loader.addFont(rootBundle.load((font as Map)['asset'] as String));
    }
    await loader.load();
  }
  if (!families.contains('MaterialIcons')) {
    throw StateError(
      'В FontManifest.json нет MaterialIcons: ${families.join(', ')}.\n'
      'Иконки нарисуются прямоугольниками, а голдены останутся зелёными.\n'
      'Проверь uses-material-design: true в pubspec.yaml.',
    );
  }
}

/// Каталог с Roboto: сначала FLUTTER_ROOT, потом подъём от исполняемого
/// файла — тесты запускает движок из того же кеша, что и шрифты.
Directory _materialFonts() {
  final roots = <String>[
    if (Platform.environment['FLUTTER_ROOT'] case final root?) root,
    ..._ancestors(Platform.resolvedExecutable),
  ];
  for (final root in roots) {
    final directory = Directory('$root/$_materialFontsPath/');
    if (directory.existsSync()) return directory;
  }
  throw StateError(_missingFontsMessage('<$_materialFontsPath>'));
}

/// Все каталоги вверх от [path], от ближнего к дальнему.
Iterable<String> _ancestors(String path) sync* {
  var current = File(path).parent;
  while (true) {
    yield current.path;
    final parent = current.parent;
    if (parent.path == current.path) return;
    current = parent;
  }
}

String _missingFontsMessage(String looked) =>
    'Шрифты Material не найдены: $looked\n'
    'Без них flutter test рисует каждую букву прямоугольником — эталоны\n'
    'снялись бы зелёными и бессмысленными одновременно, поэтому падаем.\n'
    'Почини: flutter precache  (или проверь FLUTTER_ROOT)';

/// Компаратор, который сам эталон не пишет никогда.
///
/// Штатный [LocalFileComparator] при отсутствующем файле просто падает и
/// ничего не сохраняет — то есть создать первый эталон без --update-goldens
/// нечем. Здесь кандидат кладётся рядом с эталоном под именем
/// `<имя>.new.png`, а решение «это теперь эталон» принимает человек
/// переименованием.
class _HumanReviewedComparator extends LocalFileComparator {
  _HumanReviewedComparator(super.testFile);

  @override
  Future<bool> compare(Uint8List imageBytes, Uri golden) async {
    final master = _fileFor(golden);
    final candidate = _fileFor(_candidateFor(golden));

    if (!master.existsSync()) {
      _write(candidate, imageBytes);
      fail(
        'Эталона нет: ${master.path}\n'
        'Кандидат записан: ${candidate.path}\n'
        '$_howToAccept',
      );
    }

    final result = await GoldenFileComparator.compareLists(
      imageBytes,
      await master.readAsBytes(),
    );
    if (result.passed) {
      result.dispose();
      // Кандидат с прошлого прогона больше не описывает реальность. Если его
      // не убрать, однажды примут именно его — устаревший.
      if (candidate.existsSync()) candidate.deleteSync();
      return true;
    }

    _write(candidate, imageBytes);
    final report = await generateFailureOutput(result, golden, basedir);
    result.dispose();
    fail(
      '$report\n\n'
      'Кандидат записан: ${candidate.path}\n'
      '$_howToAccept',
    );
  }

  /// Единственное место, где эталон мог бы перезаписаться автоматом.
  ///
  /// `matchesGoldenFile` зовёт его вместо `compare()`, когда включён
  /// --update-goldens. Запрет в настройках останавливает агента; этот —
  /// всех и навсегда, потому что живёт в коде, а не в договорённости.
  @override
  Future<void> update(Uri golden, Uint8List imageBytes) {
    throw UnsupportedError(
      'flutter test --update-goldens в этом проекте не работает.\n'
      'Эталон принимает человек, посмотрев на PNG: docs/dev/goldens.md\n'
      'Запусти без флага — кандидат ляжет рядом с эталоном как .new.png',
    );
  }

  File _fileFor(Uri golden) => File.fromUri(basedir.resolveUri(golden));

  Uri _candidateFor(Uri golden) {
    final path = golden.path;
    final stem =
        path.endsWith('.png') ? path.substring(0, path.length - 4) : path;
    return Uri.parse('$stem.new.png');
  }

  void _write(File candidate, Uint8List bytes) {
    candidate.parent.createSync(recursive: true);
    candidate.writeAsBytesSync(bytes, flush: true);
  }

  static const String _howToAccept =
      'Посмотри на PNG. Если вид верный — переименуй .new.png в .png.\n'
      'Если нет — это найденный баг, кандидат в мусор. docs/dev/goldens.md';
}
