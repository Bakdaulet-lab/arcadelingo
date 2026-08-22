// Хелперы для тестов над Result: вытащить значение или причину, а если
// результат не той ветви — упасть с читаемым сообщением, не с TypeError.

import 'package:arcadelingo/domain/core/result.dart';
import 'package:flutter_test/flutter_test.dart';

/// Значение из [result]. Если там [Err] — тест падает с текстом причины.
T ok<T>(Result<T> result) => switch (result) {
  Ok(:final value) => value,
  Err(:final failure) => fail('ожидался Ok, получен $failure'),
};

/// Причина из [result]. Если там [Ok] — тест падает с показом значения.
Failure err<T>(Result<T> result) => switch (result) {
  Ok(:final value) => fail('ожидался Err, получен Ok($value)'),
  Err(:final failure) => failure,
};
