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
bool swipeCounts(double travelled) => throw UnimplementedError();

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
}) => throw UnimplementedError();

/// Какой из [centers] разрезан отрезком [from] → [to]; null — ни один.
///
/// Задеты двое — режется тот, чей центр ближе к [from]: рука прошла через
/// него первой.
int? sliceTarget({
  required Offset from,
  required Offset to,
  required List<Offset> centers,
  required double radius,
}) => throw UnimplementedError();
