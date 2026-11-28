import 'hangul.dart';

final _spaces = RegExp(r'\s+');
final _separators = RegExp(r'\s*[,;/]\s*');
final _arabicVowels = RegExp(r'[\u0640\u064b-\u0652\u0670]');

String normalizedWordLabel(String value) =>
    value.trim().replaceAll('ẞ', 'ß').toLowerCase().replaceAll(_spaces, ' ');

/// Letter tiles stay one glyph per letter, including German ß.
String uppercaseWordLetters(String value, {String? studyLanguage}) =>
    (studyLanguage == 'tr' ? value.replaceAll('i', 'İ') : value)
        .replaceAll('ß', 'ẞ')
        .toUpperCase();

/// Course entries may list several accepted meanings for the same word.
Set<String> translationMeanings(String translation) {
  final label = normalizedWordLabel(translation);
  return {
    if (label.isNotEmpty) label,
    ...label.split(_separators).where((part) => part.isNotEmpty),
  };
}

// Keyboards can enter accented letters either as one code point or as a base
// plus a combining mark. Compare equivalent
// spellings in the course languages without discarding meaningful accents.
const _accentLetters = {
  '\u0300': ('aeiou', 'àèìòù'),
  '\u0301': ('aeiouy', 'áéíóúý'),
  '\u0302': ('aeiou', 'âêîôû'),
  '\u0303': ('ano', 'ãñõ'),
  '\u0306': ('gи', 'ğй'),
  '\u0308': ('aeiouyе', 'äëïöüÿё'),
  '\u030a': ('a', 'å'),
  '\u0327': ('cs', 'çş'),
  '\u3099': (
    'うかきくけこさしすせそたちつてとはひふへほゝウカキクケコサシスセソタチツテトハヒフヘホワヰヱヲヽ',
    'ゔがぎぐげござじずぜぞだぢづでどばびぶべぼゞヴガギグゲゴザジズゼゾダヂヅデドバビブベボヷヸヹヺヾ',
  ),
  '\u309a': ('はひふへほハヒフヘホ', 'ぱぴぷぺぽパピプペポ'),
};
final _combiningLetter = RegExp(r'([a-zеиぁ-ゖァ-ヺゝヽ])(\p{M})', unicode: true);

String normalizedCourseSpelling(String value, {String? studyLanguage}) {
  // Turkish treats the dotted and dotless pairs as different letters.
  final text =
      studyLanguage == 'tr'
          ? value
              .replaceAll('I\u0307', 'i')
              .replaceAll('I\u0302', 'î')
              .replaceAll('İ', 'i')
              .replaceAll('I', 'ı')
          : value;
  return composeHangul(normalizedWordLabel(text))
      .replaceAll('’', "'")
      .replaceAll('ا\u0653', 'آ')
      .replaceAll('ا\u0654', 'أ')
      .replaceAll('ا\u0655', 'إ')
      .replaceAll('و\u0654', 'ؤ')
      .replaceAll('ي\u0654', 'ئ')
      .replaceAll(_arabicVowels, '')
      .replaceAllMapped(_combiningLetter, (match) {
        final forms = _accentLetters[match[2]];
        if (forms == null) return match[0]!;
        final index = forms.$1.indexOf(match[1]!);
        return index < 0 ? match[0]! : forms.$2[index];
      });
}
