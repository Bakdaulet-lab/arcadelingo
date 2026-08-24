/// Тема приложения — одна на всё, включая голден-тесты.
///
/// Вынесена из `app.dart` не ради опрятности. Голден обязан снимать ту самую
/// палитру, которую видит человек на телефоне; собранная в тесте копия
/// `ColorScheme.fromSeed(...)` разошлась бы с приложением молча — при смене
/// зерна эталоны остались бы зелёными и при этом неправильными.
library;

import 'package:flutter/material.dart';

/// Зерно палитры. Единственное место, где оно названо.
const Color wordarcadeSeed = Colors.deepPurple;

/// Тема приложения.
///
/// [platform] нужен голденам. `Typography` выбирает семейство шрифта по
/// платформе: на Windows это Segoe UI, на Android — Roboto. Эталон обязан
/// сниматься в той конфигурации, в которой игра живёт, а не в той, на
/// которой её сегодня собирают. Приложение параметр не передаёт — там
/// платформа настоящая.
ThemeData wordarcadeTheme({TargetPlatform? platform}) => ThemeData(
  colorScheme: ColorScheme.fromSeed(seedColor: wordarcadeSeed),
  platform: platform,
);
