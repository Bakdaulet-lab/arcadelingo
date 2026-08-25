/// Чтение файла атрибуции из бандла приложения.
///
/// Тонкая обёртка, как `loadWordsSeed`. Отсутствие ассета — `FlutterError`
/// из `loadString`: это дефект сборки (файл не зарегистрирован в
/// `pubspec.yaml`), а не битые данные, и в `Failure` он не заворачивается.
library;

import 'package:flutter/services.dart';

/// Путь ассета — тот же, что зарегистрирован в `pubspec.yaml`.
const String attributionAssetPath = 'assets/ATTRIBUTION.md';

/// Текст атрибуции из [bundle] (по умолчанию [rootBundle]).
Future<String> loadAttribution({AssetBundle? bundle}) =>
    (bundle ?? rootBundle).loadString(attributionAssetPath);
