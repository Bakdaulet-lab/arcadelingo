import 'dart:typed_data' show Endian;

import 'package:arcadelingo/data/sound/audio_sounds.dart';
import 'package:arcadelingo/domain/ports/sounds.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

const _expected = {
  GameSound.slice: (path: 'sound/slice.wav', milliseconds: 230),
  GameSound.sliceHot: (path: 'sound/slice_hot.wav', milliseconds: 290),
  GameSound.miss: (path: 'sound/miss.wav', milliseconds: 170),
  GameSound.roundEnd: (path: 'sound/round_end.wav', milliseconds: 290),
  GameSound.clawCatch: (path: 'sound/claw_catch.wav', milliseconds: 145),
  GameSound.clawMiss: (path: 'sound/claw_miss.wav', milliseconds: 130),
  GameSound.clawWord: (path: 'sound/claw_word.wav', milliseconds: 335),
};

String _tag(ByteData data, int offset) => String.fromCharCodes([
  for (var index = 0; index < 4; index++) data.getUint8(offset + index),
]);

ByteData _chunk(ByteData wav, String name) {
  // WAV может содержать служебные чанки и байт выравнивания после нечётных.
  for (var offset = 12; offset + 8 <= wav.lengthInBytes;) {
    final length = wav.getUint32(offset + 4, Endian.little);
    final start = offset + 8;
    final end = start + length;
    if (end > wav.lengthInBytes) break;
    if (_tag(wav, offset) == name) return ByteData.sublistView(wav, start, end);
    offset = end + (length & 1);
  }
  throw StateError('В WAV не найден чанк $name');
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('каждое звуковое событие связано со своим ассетом', () {
    expect(
      soundAssets,
      _expected.map((sound, asset) => MapEntry(sound, asset.path)),
    );
    expect(soundAssets.keys, unorderedEquals(GameSound.values));
  });

  for (final asset in _expected.values) {
    test('${asset.path}: короткий моно PCM WAV включён в бандл', () async {
      final wav = await rootBundle.load('assets/${asset.path}');
      expect(_tag(wav, 0), 'RIFF');
      expect(_tag(wav, 8), 'WAVE');
      expect(wav.getUint32(4, Endian.little) + 8, wav.lengthInBytes);

      final format = _chunk(wav, 'fmt ');
      expect(format.getUint16(0, Endian.little), 1, reason: 'PCM');
      expect(format.getUint16(2, Endian.little), 1, reason: 'моно');
      expect(format.getUint32(4, Endian.little), 44100);
      expect(format.getUint16(14, Endian.little), 16);

      final samples = _chunk(wav, 'data');
      expect(samples.lengthInBytes.isEven, isTrue);
      expect(samples.lengthInBytes / 2 / 44.1, closeTo(asset.milliseconds, 10));
      var peak = 0;
      for (var offset = 0; offset < samples.lengthInBytes; offset += 2) {
        final amplitude = samples.getInt16(offset, Endian.little).abs();
        if (amplitude > peak) peak = amplitude;
      }
      expect(
        peak,
        inExclusiveRange(1000, 32767),
        reason: 'не тишина и не клиппинг',
      );
    });
  }
}
