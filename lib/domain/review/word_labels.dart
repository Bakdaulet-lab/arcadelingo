final _spaces = RegExp(r'\s+');
final _separators = RegExp(r'\s*[,;/]\s*');

String normalizedWordLabel(String value) =>
    value.trim().toLowerCase().replaceAll(_spaces, ' ');

/// Course entries may list several accepted meanings for the same word.
Set<String> translationMeanings(String translation) {
  final label = normalizedWordLabel(translation);
  return {
    if (label.isNotEmpty) label,
    ...label.split(_separators).where((part) => part.isNotEmpty),
  };
}
