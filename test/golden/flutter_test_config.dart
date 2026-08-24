// Настройка голден-тестов: шрифты и компаратор, который никогда не пишет
// эталон сам.
//
// Файл лежит в test/golden/, а не в test/, намеренно: flutter test ищет
// ближайший flutter_test_config.dart вверх по дереву, поэтому загрузка
// шрифтов не платится при каждом прогоне быстрых тестов.
//
// Шрифты грузятся только из ассетов приложения, общим загрузчиком из
// test/support/bundled_fonts.dart — тем же, которым пользуется test/peek/.
//
// Процедура обновления эталонов человеком — docs/dev/goldens.md.

import 'dart:async';
import 'dart:io';
// Uint8List: приезжал транзитом через package:flutter/services.dart,
// который уехал вместе с загрузчиком шрифтов. Импорт точный.
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';

import '../support/bundled_fonts.dart';

Future<void> testExecutable(FutureOr<void> Function() testMain) async {
  TestWidgetsFlutterBinding.ensureInitialized();
  await loadBundledFonts();
  final local = goldenFileComparator as LocalFileComparator;
  goldenFileComparator = _HumanReviewedComparator(
    local.basedir.resolve('flutter_test_config.dart'),
  );
  await testMain();
}

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
