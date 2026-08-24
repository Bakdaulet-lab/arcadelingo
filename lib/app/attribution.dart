/// Разбор `assets/ATTRIBUTION.md` в блоки, которые умеет нарисовать экран.
///
/// Зачем свой разбор, а не пакет и не `showLicensePage`: `ATTRIBUTION.md`
/// обязан остаться единственным источником атрибуции. Копия того же текста
/// в Dart-коде разошлась бы с файлом молча, а в репозитории ревьюер читает
/// именно файл. Полноценный markdown ради полутора конструкций — лишняя
/// зависимость.
///
/// Разбор намеренно **частичный**: он знает ровно то, что в файле есть.
/// Честность этого держится на [AttributionBlockKind.unsupported] — всё
/// незнакомое попадает туда, а тест разбирает настоящий файл и требует,
/// чтобы таких блоков не было ни одного. Добавили в файл таблицу — красный
/// тест в тот же день, а не мусор на экране через полгода.
///
/// Flutter здесь нет намеренно: разбор проверяется обычным `test()`, без
/// дерева виджетов.
library;

/// Что за блок перед нами.
enum AttributionBlockKind {
  heading1,
  heading2,
  paragraph,
  quote,
  bullet,

  /// Конструкция, которой рендер не знает. Существует затем, чтобы её
  /// появление было видно тесту, а не пользователю.
  unsupported,
}

/// Как нарисовать кусок строки.
enum AttributionStyle { plain, bold, code, link }

/// Кусок строки с одной разметкой на всю длину.
class AttributionSpan {
  const AttributionSpan(this.text, [this.style = AttributionStyle.plain]);

  final String text;
  final AttributionStyle style;

  @override
  bool operator ==(Object other) =>
      other is AttributionSpan && other.text == text && other.style == style;

  @override
  int get hashCode => Object.hash(text, style);

  @override
  String toString() => 'AttributionSpan($text, $style)';
}

/// Блок разметки: заголовок, абзац, цитата или пункт списка.
class AttributionBlock {
  const AttributionBlock(this.kind, this.spans);

  final AttributionBlockKind kind;
  final List<AttributionSpan> spans;

  /// Текст блока без разметки — то, что увидит человек.
  String get text => spans.map((span) => span.text).join();

  @override
  String toString() => 'AttributionBlock($kind, $text)';
}

/// Разбирает [source] в блоки по порядку.
List<AttributionBlock> parseAttribution(String source) {
  throw UnimplementedError();
}
