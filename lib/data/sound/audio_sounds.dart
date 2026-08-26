/// Звук на `audioplayers`: единственное место, которое знает имена файлов.
///
/// Порт говорит «верный рез», адаптер знает, что это `assets/sound/slice.wav`.
/// Между ними ровно одна строка соответствия, и она здесь.
///
/// Пакет сверен на pub.dev перед добавлением (6.8.1, 60 дней назад, 3.4k
/// лайков, verified publisher); наш пин Flutter 3.29.2 пустил `^6.6.0` — та
/// же история, что с тремя пакетами напоминаний в 3.5.
library;

import 'package:arcadelingo/domain/ports/sounds.dart';
import 'package:audioplayers/audioplayers.dart';

/// Что каким файлом озвучено. Пути без `assets/`: `AssetSource` добавляет
/// префикс сам.
const Map<GameSound, String> soundAssets = {
  GameSound.slice: 'sound/slice.wav',
  GameSound.sliceHot: 'sound/slice_hot.wav',
  GameSound.miss: 'sound/miss.wav',
};

/// Роль звука в системе: «ambient».
///
/// Она и есть уважение к беззвучному режиму: на iOS такой звук молчит,
/// когда переключатель сбоку опущен, а на Android не перехватывает фокус у
/// музыки, которую человек слушает. Игра, глушащая чужой плеер ради свиста
/// клинка, — игра, которую выключают.
final AudioContext _ambient = AudioContext(
  iOS: AudioContextIOS(category: AVAudioSessionCategory.ambient),
  android: const AudioContextAndroid(
    usageType: AndroidUsageType.game,
    audioFocus: AndroidAudioFocus.none,
  ),
);

/// Три коротких звука, каждый на своём проигрывателе.
///
/// Своём, потому что рез и промах не накладываются друг на друга, а вот два
/// реза подряд на серии — запросто: один проигрыватель обрывал бы сам себя
/// на полуслове. Три — это ровно столько, сколько разных звуков в игре.
class AudioSounds implements Sounds {
  AudioSounds() {
    for (final entry in soundAssets.entries) {
      final player =
          AudioPlayer()
            ..setReleaseMode(ReleaseMode.stop)
            ..setAudioContext(_ambient)
            // Прогреть: первый `play` без этого тянет файл с диска в момент
            // касания, и рез звучит позже, чем ощущается.
            ..setSource(AssetSource(entry.value));
      _players[entry.key] = player;
    }
  }

  final Map<GameSound, AudioPlayer> _players = {};

  @override
  void play(GameSound sound) {
    final player = _players[sound];
    if (player == null) return;
    // С нуля, а не с того места, где остановились: два реза подряд обязаны
    // прозвучать дважды, а не продолжить один.
    player
      ..seek(Duration.zero)
      ..resume();
  }

  /// Отпустить проигрыватели. Зовёт композиционный корень.
  Future<void> dispose() async {
    for (final player in _players.values) {
      await player.dispose();
    }
    _players.clear();
  }
}
