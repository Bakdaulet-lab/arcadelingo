// Фейковый порт звука: журнал того, что игра просила сыграть.
//
// Имена событий, а не имена файлов: порт про файлы не знает, и тест,
// сверяющий `assets/sound/slice.wav`, проверял бы адаптер, а не игру.

import 'package:arcadelingo/domain/ports/sounds.dart';

/// Звук, который всё запоминает и ничего не играет.
class FakeSounds implements Sounds {
  /// Что просили сыграть, по порядку.
  final List<GameSound> played = [];

  @override
  void play(GameSound sound) => played.add(sound);
}
