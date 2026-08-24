/// Экран «Источники»: содержимое `assets/ATTRIBUTION.md` как есть.
///
/// Как и остальные экраны хоста, всё приходит параметром: разбирать ассет —
/// работа маршрута, а не вида.
library;

import 'package:flutter/material.dart';

/// Атрибуция, нарисованная из [source].
class AttributionView extends StatelessWidget {
  const AttributionView({required this.source, super.key});

  /// Содержимое `ATTRIBUTION.md` целиком.
  final String source;

  @override
  Widget build(BuildContext context) {
    throw UnimplementedError();
  }
}
