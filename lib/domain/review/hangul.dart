const _syllableBase = 0xAC00;
const _vowelCount = 21;
const _trailingCount = 28;
const _initials = 'ㄱㄲㄴㄷㄸㄹㅁㅂㅃㅅㅆㅇㅈㅉㅊㅋㅌㅍㅎ';
const _vowels = 'ㅏㅐㅑㅒㅓㅔㅕㅖㅗㅘㅙㅚㅛㅜㅝㅞㅟㅠㅡㅢㅣ';
const _finals = ' ㄱㄲㄳㄴㄵㄶㄷㄹㄺㄻㄼㄽㄾㄿㅀㅁㅂㅄㅅㅆㅇㅈㅊㅋㅌㅍㅎ';
const hangulTileAlphabet = '$_initials$_vowelsㄳㄵㄶㄺㄻㄼㄽㄾㄿㅀㅄ';

final _shortWord = RegExp(r'^[\uac00-\ud7a3]{1,4}$');
final _decomposed = RegExp(
  r'[\u1100-\u1112][\u1161-\u1175][\u11a8-\u11c2]?'
  r'|[\uac00-\ud7a3][\u11a8-\u11c2]',
);

/// Compose modern conjoining Jamo from keyboards or pasted text.
String composeHangul(String value) => value.replaceAllMapped(_decomposed, (m) {
  final units = m[0]!.codeUnits;
  if (units.first >= _syllableBase) {
    final base = units.first - _syllableBase;
    if (base % _trailingCount != 0) return m[0]!;
    return String.fromCharCode(units.first + units.last - 0x11A7);
  }
  final initial = units.first - 0x1100;
  final vowel = units[1] - 0x1161;
  final trailing = units.length == 3 ? units.last - 0x11A7 : 0;
  final syllable = (initial * _vowelCount + vowel) * _trailingCount + trailing;
  return String.fromCharCode(_syllableBase + syllable);
});

/// Short words are spelled with individual letters. Longer phrases use whole
/// syllable tiles, so spelling still fits comfortably in an arcade round.
class HangulSpelling {
  HangulSpelling._(this._word, this.tiles, this._ends);

  static HangulSpelling? forWord(String value) {
    final word = composeHangul(value);
    if (!_shortWord.hasMatch(word)) return null;
    final tiles = <String>[];
    final ends = <int>[];
    for (final code in word.codeUnits) {
      if (tiles.isNotEmpty) tiles.add(' ');
      final offset = code - _syllableBase;
      final trailing = offset % _trailingCount;
      final initialAndVowel = offset ~/ _trailingCount;
      tiles
        ..add(_initials[initialAndVowel ~/ _vowelCount])
        ..add(_vowels[initialAndVowel % _vowelCount]);
      if (trailing != 0) tiles.add(_finals[trailing]);
      ends.add(tiles.length);
    }
    return HangulSpelling._(word, List.unmodifiable(tiles), ends);
  }

  final String _word;
  final List<String> tiles;
  final List<int> _ends;

  String completedAt(int slots) =>
      _word.substring(0, _ends.takeWhile((end) => end <= slots).length);
}
