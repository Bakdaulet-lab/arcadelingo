// Три звука в `assets/sound/` — ровно то, что написано в SPEC.
//
// Главная проверка здесь не «файл на месте», а «файл — это те числа»:
// тест пересобирает WAV в памяти из `tool/sound/sound_synth.dart` и сверяет
// байты. Отсюда следует, что таблица в `SPEC.md` описывает содержимое
// репозитория, а не намерение: разошлись — красный тест в тот же день, а
// не тихо другой звук в проде.
//
// Прецедент — `tool/seed_rules.dart`: правила содержания живут в `tool/`, и
// их же применяет тест ассета.

import 'dart:convert';
import 'dart:io';

import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../tool/sound/sound_synth.dart';

/// Целое из little-endian куска WAV-заголовка.
int _le(List<int> bytes, int at, int width) {
  var value = 0;
  for (var i = width - 1; i >= 0; i--) {
    value = (value << 8) | bytes[at + i];
  }
  return value;
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('Файлы — это те самые числа', () {
    for (final name in sounds.keys) {
      test('$name пересобирается байт в байт', () async {
        final onDisk = File('assets/sound/$name').readAsBytesSync();

        expect(
          onDisk,
          wav(sounds[name]!()),
          reason:
              'файл разошёлся с tool/sound/sound_synth.dart. Пересобрать: '
              'dart run tool/sound/render_sounds.dart',
        );
      });
    }
  });

  group('Заголовок WAV', () {
    late Map<String, List<int>> files;

    setUpAll(() {
      files = {
        for (final name in sounds.keys)
          name: File('assets/sound/$name').readAsBytesSync(),
      };
    });

    test('RIFF/WAVE, моно, 44.1 кГц, 16 бит', () {
      for (final entry in files.entries) {
        final bytes = entry.value;
        expect(utf8.decode(bytes.sublist(0, 4)), 'RIFF', reason: entry.key);
        expect(utf8.decode(bytes.sublist(8, 12)), 'WAVE', reason: entry.key);
        expect(_le(bytes, 22, 2), 1, reason: 'каналов у ${entry.key}');
        expect(_le(bytes, 24, 4), 44100, reason: 'частота у ${entry.key}');
        expect(_le(bytes, 34, 2), 16, reason: 'бит у ${entry.key}');
      }
    });

    test('длительности из SPEC: 180, 260 и 220 мс', () {
      int ms(String name) {
        final bytes = files[name]!;
        return (_le(bytes, 40, 4) ~/ 2) * 1000 ~/ 44100;
      }

      expect(ms('slice.wav'), 180);
      expect(ms('slice_hot.wav'), 260);
      expect(ms('miss.wav'), 220);
    });

    test('не тишина и не клиппинг', () {
      for (final entry in files.entries) {
        final bytes = entry.value;
        var loudest = 0;
        for (var i = 44; i + 1 < bytes.length; i += 2) {
          var sample = _le(bytes, i, 2);
          if (sample >= 32768) sample -= 65536;
          if (sample.abs() > loudest) loudest = sample.abs();
        }
        expect(loudest / 32767, closeTo(peak, 0.001), reason: entry.key);
      }
    });
  });

  group('Одинаковый сид — одинаковые байты', () {
    test('свист не зависит от прогона: без этого сверка бессмысленна', () {
      expect(wav(sliceWave()), wav(sliceWave()));
      expect(wav(sliceHotWave()), wav(sliceHotWave()));
    });
  });

  group('Ассеты зарегистрированы', () {
    test('каждый файл читается из бандла, а не только с диска', () async {
      // Шов `rootBundle`, а не `File`: в бандл едет то, что перечислено в
      // pubspec, и забытая строка там — ровно тот дефект, который на диске
      // не виден. Та же грабля, что в 0.14 с ATTRIBUTION.md.
      for (final name in sounds.keys) {
        final data = await rootBundle.load('assets/sound/$name');

        expect(data.lengthInBytes, greaterThan(44), reason: name);
      }
    });
  });
}
