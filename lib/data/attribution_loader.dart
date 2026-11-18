/// Чтение файла атрибуции из бандла приложения.
///
/// Тонкая обёртка, как `loadWordsSeed`. Отсутствие ассета — `FlutterError`
/// из `loadString`: это дефект сборки (файл не зарегистрирован в
/// `pubspec.yaml`), а не битые данные, и в `Failure` он не заворачивается.
library;

import 'package:arcadelingo/domain/settings/app_settings.dart';
import 'package:flutter/services.dart';

/// Путь ассета — тот же, что зарегистрирован в `pubspec.yaml`.
const String attributionAssetPath = 'assets/ATTRIBUTION.md';

const String englishAttributionAssetPath = 'assets/ATTRIBUTION.en.md';
const String spanishAttributionAssetPath = 'assets/ATTRIBUTION.es.md';

/// Текст атрибуции из [bundle] (по умолчанию [rootBundle]).
Future<String> loadAttribution({
  AssetBundle? bundle,
  required InterfaceLanguage language,
}) {
  final asset = switch (language) {
    InterfaceLanguage.english => englishAttributionAssetPath,
    InterfaceLanguage.spanish => spanishAttributionAssetPath,
    InterfaceLanguage.russian ||
    InterfaceLanguage.system => attributionAssetPath,
  };
  return (bundle ?? rootBundle).loadString(asset);
}
