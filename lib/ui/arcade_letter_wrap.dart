import 'package:flutter/widgets.dart';

/// Keep the slots of each word together when the entire word fits on a line.
class ArcadeLetterWrap extends StatelessWidget {
  const ArcadeLetterWrap({
    required this.spelling,
    required this.slot,
    required this.spacing,
    required this.runSpacing,
    this.alignment = WrapAlignment.start,
    this.textDirection,
    super.key,
  });

  final List<String> spelling;
  final IndexedWidgetBuilder slot;
  final double spacing;
  final double runSpacing;
  final WrapAlignment alignment;
  final TextDirection? textDirection;

  @override
  Widget build(BuildContext context) {
    Widget wrap(List<Widget> children, double gap) => Wrap(
      alignment: alignment,
      textDirection: textDirection,
      spacing: gap,
      runSpacing: runSpacing,
      children: children,
    );

    final words = <Widget>[];
    var letters = <Widget>[];
    for (final (index, character) in spelling.indexed) {
      if (character.trim().isEmpty) {
        if (letters.isEmpty) continue;
        words.add(wrap(letters, spacing));
        letters = [];
      } else {
        letters.add(slot(context, index));
      }
    }
    if (letters.isNotEmpty) words.add(wrap(letters, spacing));
    return words.length == 1 ? words.single : wrap(words, spacing + 8);
  }
}
