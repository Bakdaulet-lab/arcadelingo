/// Геометрия реза: когда движение считается свайпом и что оно задело.
///
/// Отдельно от виджета, потому что это единственное место, где решается
/// «попал или нет», и решаться оно обязано без дерева виджетов.
///
/// Числа — `SPEC.md`, раздел «Ниндзя-слэш» → «Рез».
library;

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
}) => _distanceToSegment(from: from, to: to, point: center) <= radius;

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
}) {
  int? nearest;
  var best = double.infinity;
  for (var i = 0; i < centers.length; i++) {
    if (!sliceHit(from: from, to: to, center: centers[i], radius: radius)) {
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
