/// Экран «Источники»: содержимое `assets/ATTRIBUTION.md` как есть.
///
/// Экран существует потому, что условие лицензии CEFR-J — «cite properly» —
/// адресовано пользователю, а репозитория он не видит. Файл при этом остаётся
/// единственным источником: второй копии текста в Dart-коде нет нигде, и
/// именно поэтому здесь свой разбор, а не `showLicensePage` со своим текстом.
///
/// Юридическое приложение — четыре килобайта OFL — сюда не переезжает: на
/// него ведёт кнопка на штатный экран лицензий. Цитирование и лицензии это
/// разные вещи, и складывать их в один список значит прятать первое.
library;

import 'package:arcadelingo/app/app_views.dart';
import 'package:arcadelingo/app/attribution.dart';
import 'package:arcadelingo/data/attribution_loader.dart';
import 'package:arcadelingo/ui/theme.dart';
import 'package:flutter/material.dart';

/// Экран целиком: читает ассет и отдаёт его виду.
///
/// Загрузка здесь, а не в корне приложения: файл нужен ровно тогда, когда
/// экран открыли. Тянуть его при старте — работа впустую на каждом запуске
/// ради экрана, который открывают раз.
class AttributionScreen extends StatefulWidget {
  const AttributionScreen({super.key, this.bundle});

  /// Подменяется в тестах напрямую; иначе берётся из дерева через
  /// `DefaultAssetBundle`, а тот в продакшне отдаёт `rootBundle`.
  ///
  /// Шов нужен потому, что чтение настоящего ассета — настоящий ввод-вывод:
  /// в widget-тесте `pump()` его не дожидается, и экран остаётся пустым.
  /// Что ассет при этом вообще зарегистрирован в `pubspec.yaml`, сторожит
  /// отдельный тест — этот шов такую ошибку пропустил бы.
  final AssetBundle? bundle;

  @override
  State<AttributionScreen> createState() => _AttributionScreenState();
}

class _AttributionScreenState extends State<AttributionScreen> {
  Future<String>? _source;

  /// Future заводится один раз, а не в `build`: собранный в `build`, он
  /// пересоздавался бы на каждую перестройку, и экран моргал бы загрузкой
  /// при повороте или смене темы. Здесь, а не в `initState`, потому что
  /// бандл берётся из дерева.
  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _source ??= loadAttribution(
      bundle: widget.bundle ?? DefaultAssetBundle.of(context),
    );
  }

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<String>(
      future: _source,
      builder: (context, snapshot) {
        final error = snapshot.error;
        if (error != null) {
          // Отсутствующий ассет — дефект сборки, как и битый сид. Молчать о
          // нём нельзя: пустой экран «Источники» выглядит как отсутствие
          // источников, то есть как нарушение условия лицензии.
          return _Frame(child: Text('Источники не читаются: $error'));
        }
        final source = snapshot.data;
        return source == null
            ? const _Frame(child: SizedBox.shrink())
            : AttributionView(source: source);
      },
    );
  }
}

/// Атрибуция, нарисованная из [source].
///
/// Как и остальные экраны хоста, всё приходит параметром: читать ассет —
/// работа [AttributionScreen], а не вида.
class AttributionView extends StatelessWidget {
  const AttributionView({required this.source, super.key});

  /// Содержимое `ATTRIBUTION.md` целиком.
  final String source;

  @override
  Widget build(BuildContext context) {
    final blocks = parseAttribution(source);
    return _Frame(
      // SelectionArea, чтобы цитату и адрес источника можно было выделить и
      // скопировать. Тапабельных ссылок нет намеренно: url_launcher — новая
      // зависимость, а «cite properly» требует читаемости, не кликабельности.
      //
      // Колонка целиком, а не ListView: ленивый список строит только видимое,
      // и выделить им можно ровно то, что сейчас на экране. Для экрана,
      // существующего ради цитирования, это дефект — цитата обязана
      // копироваться целиком. Документ короткий и фиксированный, экономить
      // на нём нечего.
      child: SelectionArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(24, 8, 24, 32),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              for (final block in blocks) _AttributionBlockView(block: block),
              const SizedBox(height: 32),
              FilledButton.tonal(
                key: AppKeys.licenses,
                onPressed: () => showLicensePage(context: context),
                style: ButtonStyle(
                  minimumSize: WidgetStateProperty.all(const Size(220, 56)),
                ),
                child: const Text('Полные тексты лицензий'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Общая рама экрана: заголовок и стрелка назад.
///
/// Стрелку рисует `AppBar` сам, раз экран открыт маршрутом. Она обязательна:
/// застрять на «Источниках» игрок не должен, а системная кнопка «назад» есть
/// не на всякой платформе.
class _Frame extends StatelessWidget {
  const _Frame({required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) => Scaffold(
    key: AppKeys.sourcesView,
    appBar: AppBar(title: const Text('Источники')),
    body: child,
  );
}

/// Один блок разметки.
class _AttributionBlockView extends StatelessWidget {
  const _AttributionBlockView({required this.block});

  final AttributionBlock block;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final text = _text(context);

    return switch (block.kind) {
      AttributionBlockKind.heading1 => Padding(
        padding: const EdgeInsets.only(top: 8, bottom: 16),
        child: text,
      ),
      AttributionBlockKind.heading2 => Padding(
        padding: const EdgeInsets.only(top: 24, bottom: 8),
        child: text,
      ),
      // Цитата — полосой слева, а не курсивом: курсивного начертания Rubik в
      // бандле нет, и движок подделал бы наклон синтетически.
      AttributionBlockKind.quote => Padding(
        padding: const EdgeInsets.symmetric(vertical: 8),
        child: Container(
          padding: const EdgeInsets.only(left: 16),
          decoration: BoxDecoration(
            border: Border(left: BorderSide(color: scheme.primary, width: 3)),
          ),
          child: text,
        ),
      ),
      AttributionBlockKind.bullet => Padding(
        padding: const EdgeInsets.only(bottom: 12),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('•  ', style: theme.textTheme.bodyLarge),
            Expanded(child: text),
          ],
        ),
      ),
      // Незнакомая строка показывается как есть. Сюда попасть нельзя: тест
      // разбирает живой файл и требует ноль таких блоков. Но если однажды
      // попадёт, лучше показать сырую строку, чем проглотить её.
      AttributionBlockKind.paragraph || AttributionBlockKind.unsupported =>
        Padding(padding: const EdgeInsets.only(bottom: 12), child: text),
    };
  }

  Widget _text(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final base = switch (block.kind) {
      AttributionBlockKind.heading1 => withWeight(
        theme.textTheme.headlineMedium!,
        FontWeight.bold,
      ),
      AttributionBlockKind.heading2 => withWeight(
        theme.textTheme.titleLarge!,
        FontWeight.bold,
      ),
      AttributionBlockKind.quote => theme.textTheme.bodyLarge!.copyWith(
        color: scheme.onSurfaceVariant,
      ),
      _ => theme.textTheme.bodyLarge!,
    };

    return Text.rich(
      TextSpan(
        children: [
          for (final span in block.spans)
            TextSpan(text: span.text, style: _styled(base, span.style, scheme)),
        ],
      ),
      style: base,
    );
  }

  /// Разметка куска поверх стиля блока.
  ///
  /// Жирный — через `withWeight`: обычный `fontWeight` на вариативном Rubik
  /// инертен, ось `wght` двигается только `fontVariations` (задача 0.12).
  TextStyle _styled(TextStyle base, AttributionStyle style, ColorScheme s) =>
      switch (style) {
        AttributionStyle.plain => base,
        AttributionStyle.bold => withWeight(base, FontWeight.bold),
        AttributionStyle.code => base.copyWith(color: s.tertiary),
        AttributionStyle.link => base.copyWith(
          color: s.primary,
          decoration: TextDecoration.underline,
          decorationColor: s.primary,
        ),
      };
}
