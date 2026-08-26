/// Синтез трёх звуков ниндзя-слэша: свист клинка, свист на серии, удар.
///
/// Чистые функции: те же числа дают тот же байт. Отсюда главное свойство —
/// тест пересобирает WAV в памяти и сверяет с тем, что лежит в `assets/`.
/// Файл в репозитории не «какой-то звук», а ровно то, что написано в
/// `SPEC.md`, раздел «Ниндзя-слэш» → «Звук».
///
/// Почему рисуем, а не берём готовый пак: прецедент иконки лаунчера (0.15)
/// плюс причина, которой у иконки не было, — агент, пишущий этот код, звук
/// не слышит, и выбор файлов из пака по именам положил бы в продукт
/// содержимое, которого никто не проверял. Разбор — `docs/dev/context.md`.
///
/// Здесь нет ни Flutter, ни `dart:io`: файлы пишет `render_sounds.dart`,
/// а этот файл только считает сэмплы — поэтому его и может звать тест.
library;

import 'dart:math';
import 'dart:typed_data';

/// Частота дискретизации. 44.1 кГц — не выбор, а то, что играет везде без
/// пересчёта.
const int sampleRate = 44100;

/// Пиковая амплитуда. Не единица: сумма шума и тона на пике доходит до неё
/// вплотную, и запас в три десятых спасает от клиппинга.
const double peak = 0.7;

/// Сид шума. Без него два прогона дадут разные байты, и тест сверки
/// перестанет что-либо значить.
const int noiseSeed = 20260827;

/// Свист клинка: полосовой шум, центр ползёт вверх, спад экспонентой.
const Duration sliceLength = Duration(milliseconds: 180);
const double sliceFromHz = 1800;
const double sliceToHz = 3200;

/// Свист на горячей серии: тот же шум плюс тон с подъёмом на кварту.
const Duration sliceHotLength = Duration(milliseconds: 260);
const double hotToneFromHz = 660;
const double hotToneToHz = 880;

/// Удар: низкий тон с уходом вниз.
const Duration missLength = Duration(milliseconds: 220);
const double missFromHz = 140;
const double missToHz = 70;

/// Сэмплы свиста клинка, −1…1.
List<double> sliceWave() =>
    _swish(sliceLength, from: sliceFromHz, to: sliceToHz);

/// Сэмплы свиста на горячей серии: тот же свист и тон поверх него.
///
/// Не другой звук, а тот же с надстройкой: рука и ухо должны узнать рез, а
/// не услышать второе событие.
List<double> sliceHotWave() {
  final out = _swish(sliceHotLength, from: sliceFromHz, to: sliceToHz);
  final count = out.length;
  for (var i = 0; i < count; i++) {
    final t = i / count;
    final hz = hotToneFromHz + (hotToneToHz - hotToneFromHz) * t;
    // Тон входит не сразу: первые проценты занимает сам свист, иначе рез
    // звучал бы как нота, а не как удар с нотой.
    final swell = t < 0.15 ? t / 0.15 : 1.0;
    out[i] += 0.55 * swell * exp(-4 * t) * sin(2 * pi * hz * i / sampleRate);
  }
  return _normalise(out);
}

/// Сэмплы удара.
List<double> missWave() {
  final count = _samples(missLength);
  final out = List<double>.filled(count, 0);
  for (var i = 0; i < count; i++) {
    final t = i / count;
    final hz = missFromHz + (missToHz - missFromHz) * t;
    out[i] = exp(-6 * t) * sin(2 * pi * hz * i / sampleRate);
  }
  return _normalise(out);
}

/// Полосовой шум с ползущим центром и мгновенной атакой.
List<double> _swish(
  Duration length, {
  required double from,
  required double to,
}) {
  final count = _samples(length);
  final random = Random(noiseSeed);
  final out = List<double>.filled(count, 0);
  // Фильтр Чемберлина: два интегратора, полоса снимается со среднего.
  // Своя реализация, а не пакет: три строки арифметики не стоят зависимости.
  var low = 0.0;
  var band = 0.0;
  for (var i = 0; i < count; i++) {
    final t = i / count;
    final centre = from + (to - from) * t;
    final f = 2 * sin(pi * centre / sampleRate);
    const q = 0.35;
    final input = random.nextDouble() * 2 - 1;
    final high = input - low - q * band;
    band += f * high;
    low += f * band;
    // Атака мгновенная — спад экспонентой: клинок бьёт, а не разгоняется.
    // Та же причина, по которой тряска идёт от косинуса, а не от синуса.
    out[i] = band * exp(-7 * t);
  }
  return _normalise(out);
}

int _samples(Duration length) => length.inMicroseconds * sampleRate ~/ 1000000;

/// Приводит пик к [peak]. Тишину оставляет тишиной, а не делит на ноль.
List<double> _normalise(List<double> wave) {
  var loudest = 0.0;
  for (final sample in wave) {
    if (sample.abs() > loudest) loudest = sample.abs();
  }
  if (loudest == 0) return wave;
  final gain = peak / loudest;
  for (var i = 0; i < wave.length; i++) {
    wave[i] *= gain;
  }
  return wave;
}

/// WAV из сэмплов: моно, 16 бит, [sampleRate].
///
/// Заголовок пишется руками, потому что писать в нём нечего, кроме
/// одиннадцати чисел, а пакет ради них — зависимость на пустом месте.
Uint8List wav(List<double> wave) {
  final data = ByteData(wave.length * 2);
  for (var i = 0; i < wave.length; i++) {
    // Округление к ближайшему и зажим: 32768 в int16 не влезает.
    final value = (wave[i] * 32767).round().clamp(-32768, 32767);
    data.setInt16(i * 2, value, Endian.little);
  }
  final pcm = data.buffer.asUint8List();
  final out = BytesBuilder();
  void ascii(String tag) => out.add(tag.codeUnits);
  void u32(int value) => out.add(
    (ByteData(4)..setUint32(0, value, Endian.little)).buffer.asUint8List(),
  );
  void u16(int value) => out.add(
    (ByteData(2)..setUint16(0, value, Endian.little)).buffer.asUint8List(),
  );
  ascii('RIFF');
  u32(36 + pcm.length);
  ascii('WAVE');
  ascii('fmt ');
  u32(16);
  u16(1); // PCM без сжатия
  u16(1); // моно
  u32(sampleRate);
  u32(sampleRate * 2); // байт в секунду
  u16(2); // байт на кадр
  u16(16); // бит на сэмпл
  ascii('data');
  u32(pcm.length);
  out.add(pcm);
  return out.toBytes();
}

/// Что за чем лежит в `assets/sound/`: имя файла и его сэмплы.
Map<String, List<double> Function()> get sounds => {
  'slice.wav': sliceWave,
  'slice_hot.wav': sliceHotWave,
  'miss.wav': missWave,
};
