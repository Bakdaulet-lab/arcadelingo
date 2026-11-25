/// Геометрия реза: когда движение считается свайпом и что оно задело.
///
/// Отдельно от виджета, потому что это единственное место, где решается
/// «попал или нет», и решаться оно обязано без дерева виджетов.
///
/// Числа — `SPEC.md`, раздел «Ниндзя-слэш» → «Рез».
library;

import 'dart:math';
import 'dart:ui';

/// Сколько пути должен пройти палец, чтобы движение стало резом.
///
/// Без порога случайное касание в полёте стоило бы жизни: тап — это не
/// свайп, и режет только свайп.
const double sliceThreshold = 16;

/// Прошёл ли жест [travelled] логических пикселей, то есть режет ли он.
bool swipeCounts(double travelled) => travelled >= sliceThreshold;

/// Задел ли отрезок [from] → [to] круг с центром [center] и радиусом
/// [radius].
///
/// Расстояние до **отрезка**, а не до точки: быстрый свайп даёт точки реже,
/// чем диаметр объекта, и проверка «точка в круге» пропускала бы объект
/// насквозь.
bool sliceHit({
  required Offset from,
  required Offset to,
  required Offset center,
  required double radius,
  double? width,
}) =>
    _distanceToSpine(
      from,
      to,
      center,
      width == null ? 0 : width / 2 - radius,
    ) <=
    radius;

/// Ближайшая к [point] точка отрезка [from] → [to].
///
/// Она же — точка реза: место, где жест прошёл через объект. Из неё летят
/// искры, и брать вместо неё центр объекта было бы враньём на глаз —
/// касательный рез виден именно краем.
Offset closestPointOnSegment({
  required Offset from,
  required Offset to,
  required Offset point,
}) {
  final segment = to - from;
  final lengthSquared = segment.distanceSquared;
  // Вырожденный отрезок — это точка, и вести себя он обязан как точка.
  if (lengthSquared == 0) return from;
  final offset = point - from;
  // Проекция на прямую, зажатая в отрезок.
  final t = ((offset.dx * segment.dx + offset.dy * segment.dy) / lengthSquared)
      .clamp(0.0, 1.0);
  return from + segment * t;
}

/// Какой из [centers] разрезан отрезком [from] → [to]; null — ни один.
///
/// Задеты двое — режется тот, чей центр ближе к [from]: рука прошла через
/// него первой.
int? sliceTarget({
  required Offset from,
  required Offset to,
  required List<Offset> centers,
  required double radius,
  List<double>? widths,
  List<Size>? cards,
}) {
  int? nearest;
  var best = double.infinity;
  for (var i = 0; i < centers.length; i++) {
    final card = cards?[i];
    final hit =
        card == null
            ? sliceHit(
              from: from,
              to: to,
              center: centers[i],
              radius: radius,
              width: widths?[i],
            )
            : _sliceCard(from, to, centers[i], card);
    if (!hit) {
      continue;
    }
    // Квадрат расстояния: корень порядок не меняет, а считается на каждом
    // кадре жеста по каждому объекту.
    final distance = (centers[i] - from).distanceSquared;
    if (distance < best) {
      best = distance;
      nearest = i;
    }
  }
  return nearest;
}

/// The visible card consists of two intersecting strips and four rounded
/// corners. Test the swipe segment against the same shape.
bool _sliceCard(Offset from, Offset to, Offset center, Size size) {
  const corner = 16.0;
  final rect = Rect.fromCenter(
    center: center,
    width: size.width,
    height: size.height,
  );
  final inner = rect.deflate(corner);
  return _sliceRect(
        from,
        to,
        Rect.fromLTRB(rect.left, inner.top, rect.right, inner.bottom),
      ) ||
      _sliceRect(
        from,
        to,
        Rect.fromLTRB(inner.left, rect.top, inner.right, rect.bottom),
      ) ||
      [
        inner.topLeft,
        inner.topRight,
        inner.bottomLeft,
        inner.bottomRight,
      ].any((p) => sliceHit(from: from, to: to, center: p, radius: corner));
}

bool _sliceRect(Offset from, Offset to, Rect rect) {
  if (rect.contains(from) || rect.contains(to)) return true;
  final dx = to.dx - from.dx;
  final dy = to.dy - from.dy;
  if (dx != 0) {
    for (final side in [rect.left, rect.right]) {
      final t = (side - from.dx) / dx;
      final y = from.dy + t * dy;
      if (t >= 0 && t <= 1 && y >= rect.top && y <= rect.bottom) return true;
    }
  }
  if (dy != 0) {
    for (final side in [rect.top, rect.bottom]) {
      final t = (side - from.dy) / dy;
      final x = from.dx + t * dx;
      if (t >= 0 && t <= 1 && x >= rect.left && x <= rect.right) return true;
    }
  }
  return false;
}

/// Расстояние от [point] до отрезка [from] → [to].
///
/// Через [closestPointOnSegment], а не своей копией проекции: искры летят
/// из той же точки, по которой считается попадание, и две копии этой
/// арифметики разъехались бы молча — искра била бы мимо реза.
double _distanceToSegment({
  required Offset from,
  required Offset to,
  required Offset point,
}) =>
    (point - closestPointOnSegment(from: from, to: to, point: point)).distance;

/// Зона реза капсулы — все точки в пределах радиуса от её осевого отрезка.
/// Минимальное расстояние между непересекающимися отрезками достигается
/// на одном из их концов.
double _distanceToSpine(
  Offset from,
  Offset to,
  Offset center,
  double halfSpine,
) {
  double toBlade(Offset point) =>
      _distanceToSegment(from: from, to: to, point: point);
  if (halfSpine <= 0) return toBlade(center);
  final left = center.dx - halfSpine;
  final right = center.dx + halfSpine;
  if (to.dy != from.dy) {
    final t = (center.dy - from.dy) / (to.dy - from.dy);
    final x = from.dx + t * (to.dx - from.dx);
    if (t >= 0 && t <= 1 && x >= left && x <= right) return 0;
  }
  double toSpine(Offset p) =>
      (p - Offset(p.dx.clamp(left, right), center.dy)).distance;
  return min(
    min(toSpine(from), toSpine(to)),
    min(toBlade(Offset(left, center.dy)), toBlade(Offset(right, center.dy))),
  );
}

/// Насколько дальше радиуса объекта жест ещё считается касанием вскользь.
///
/// Две трети радиуса. Больше — отклик начнёт приходить на свайпы, которые
/// игрок не считал попыткой; меньше — сольётся с самим попаданием, где уже
/// есть свой, куда более громкий отклик.
const double grazeMargin = 24;

/// Прошёл ли отрезок [from] → [to] **вскользь** мимо круга [centre]:
/// самого объекта не задел, но ближе, чем радиус плюс [grazeMargin].
///
/// Почти-успех, который ничем не отзывается, читается как «игра меня не
/// увидела», и человек винит не свою руку, а хит-зону. Зеркало правила
/// 0.11 из падающих слов, где так же не отзывался успех.
bool grazed({
  required Offset from,
  required Offset to,
  required Offset centre,
  required double radius,
  double? width,
}) {
  final distance = _distanceToSpine(
    from,
    to,
    centre,
    width == null ? 0 : width / 2 - radius,
  );
  return distance > radius && distance <= radius + grazeMargin;
}
