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
  final blocks = <AttributionBlock>[];
  _Pending? pending;

  void flush() {
    final open = pending;
    if (open == null) return;
    blocks.add(AttributionBlock(open.kind, parseAttributionInline(open.text)));
    pending = null;
  }

  for (final raw in source.split('\n')) {
    // Хвостовой возврат каретки, а не replaceAll по всей строке: на Windows
    // рабочая копия приходит с CRLF, и невидимый символ в конце сорвал бы
    // дословность цитаты, ничего не показав глазу.
    final line = raw.endsWith('\r') ? raw.substring(0, raw.length - 1) : raw;
    final trimmed = line.trim();

    if (trimmed.isEmpty) {
      flush();
      continue;
    }

    // Отступ продолжает пункт списка — и только пункт: у абзацев в файле
    // продолжения не отбиты, и трогать их незачем.
    if (line.startsWith('  ') && pending?.kind == AttributionBlockKind.bullet) {
      pending!.add(trimmed);
      continue;
    }

    final kind = _kindOf(trimmed);
    switch (kind) {
      // Заголовок и незнакомая строка стоят сами по себе, соседей не собирают.
      case AttributionBlockKind.heading1:
      case AttributionBlockKind.heading2:
      case AttributionBlockKind.unsupported:
        flush();
        blocks.add(
          AttributionBlock(kind, parseAttributionInline(_strip(trimmed, kind))),
        );
      case AttributionBlockKind.bullet:
        flush();
        pending = _Pending(kind, _strip(trimmed, kind));
      case AttributionBlockKind.quote:
      case AttributionBlockKind.paragraph:
        final open = pending;
        if (open == null) {
          pending = _Pending(kind, _strip(trimmed, kind));
        } else if (open.kind == kind) {
          open.add(_strip(trimmed, kind));
        } else {
          flush();
          pending = _Pending(kind, _strip(trimmed, kind));
        }
    }
  }
  flush();
  return blocks;
}

/// Строки, которые копятся до пустой строки или до смены вида блока.
class _Pending {
  _Pending(this.kind, String first) : _parts = [first];

  final AttributionBlockKind kind;
  final List<String> _parts;

  void add(String part) => _parts.add(part);

  /// Мягкий перенос склеивается пробелом: абзац из трёх строк остаётся одним
  /// абзацем и переносится по ширине экрана, а не по ширине файла.
  String get text => _parts.join(' ');
}

/// Что за конструкция в начале строки.
///
/// Всё незнакомое уходит в [AttributionBlockKind.unsupported], и это главное
/// свойство разбора: тихо притвориться абзацем таблица не может.
AttributionBlockKind _kindOf(String line) {
  if (_unsupported.hasMatch(line)) return AttributionBlockKind.unsupported;
  if (line.startsWith('## ')) return AttributionBlockKind.heading2;
  if (line.startsWith('# ')) return AttributionBlockKind.heading1;
  if (line.startsWith('>')) return AttributionBlockKind.quote;
  if (line.startsWith('- ')) return AttributionBlockKind.bullet;
  return AttributionBlockKind.paragraph;
}

/// Конструкции, которых рендер не знает: третий уровень заголовка, таблица,
/// ссылка в квадратных скобках, картинка, горизонтальная черта, нумерованный
/// список, курсив и список звёздочкой.
///
/// Одиночная звёздочка, а не любая: абзац имеет право начаться с жирного
/// слова, и `**Автор:**` незнакомой конструкцией не является.
final RegExp _unsupported = RegExp(r'^(#{3,}|\||\[|!|-{3,}$|\d+\.\s|\*(?!\*))');

/// Снимает маркер блока. У незнакомой строки не снимает ничего: её показывают
/// как есть, чтобы в сообщении упавшего теста было видно, о чём речь.
String _strip(String line, AttributionBlockKind kind) => switch (kind) {
  AttributionBlockKind.heading1 => line.substring(2),
  AttributionBlockKind.heading2 => line.substring(3),
  AttributionBlockKind.quote => line.substring(1).trimLeft(),
  AttributionBlockKind.bullet => line.substring(2),
  AttributionBlockKind.paragraph || AttributionBlockKind.unsupported => line,
};

/// Разбирает разметку внутри строки: жирный, код и ссылка в угловых скобках.
///
/// Незакрытый маркер остаётся текстом. Это не снисходительность: маркер,
/// съедающий остаток строки, означал бы, что опечатка в файле молча
/// проглатывает кусок цитаты.
List<AttributionSpan> parseAttributionInline(String text) {
  final spans = <AttributionSpan>[];
  final plain = StringBuffer();
  var i = 0;

  void flushPlain() {
    if (plain.isEmpty) return;
    spans.add(AttributionSpan(plain.toString()));
    plain.clear();
  }

  while (i < text.length) {
    final marked = _markedAt(text, i);
    if (marked == null) {
      plain.write(text[i]);
      i++;
      continue;
    }
    flushPlain();
    spans.add(AttributionSpan(marked.text, marked.style));
    i += marked.length;
  }
  flushPlain();
  return spans;
}

/// Размеченный кусок, начинающийся в позиции [from], или null.
_Marked? _markedAt(String text, int from) {
  for (final (open, close, style) in const [
    ('**', '**', AttributionStyle.bold),
    ('`', '`', AttributionStyle.code),
    ('<', '>', AttributionStyle.link),
  ]) {
    if (!text.startsWith(open, from)) continue;
    // Угловые скобки — разметка только вокруг адреса. Иначе «<не ссылка>»
    // в обычном тексте превратилась бы в ссылку.
    if (style == AttributionStyle.link && !text.startsWith('<http', from)) {
      continue;
    }
    final start = from + open.length;
    final end = text.indexOf(close, start);
    if (end <= start) continue;
    return _Marked(
      text.substring(start, end),
      style,
      end + close.length - from,
    );
  }
  return null;
}

class _Marked {
  const _Marked(this.text, this.style, this.length);

  final String text;
  final AttributionStyle style;

  /// Сколько символов исходной строки занял кусок вместе с маркерами.
  final int length;
}
