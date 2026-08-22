/// Результат операции, которая может не получиться: значение или [Failure].
///
/// CLAUDE.md → «Стиль»: ошибки из domain/ возвращаются, а не бросаются.
/// Бросают только ошибки вызывающего кода — не исходы работы, а баги:
/// невалидный аргумент при построении (`LeitnerCard` → `ArgumentError`) и
/// нарушение протокола вызова (`LeitnerReviewSession` → `StateError`).
///
/// Запечатанная иерархия: `switch` по результату обязан разобрать обе
/// ветви, компилятор не даст забыть про ошибку.
/// ```dart
/// switch (decodeLeitnerState(raw)) {
///   case Ok(:final value):
///     use(value);
///   case Err(:final failure):
///     report(failure);
/// }
/// ```
///
/// Без `map`/`when`/`==` намеренно: на Гейте-0 нужны два конструктора и
/// `toString`, чтобы упавший `expect` печатал причину, а не
/// `Instance of 'Err<…>'`. Остальное — когда появится второй потребитель.
library;

/// Успех со значением или неуспех с причиной. См. [Ok], [Err].
sealed class Result<T> {
  const Result();
}

/// Успех.
final class Ok<T> extends Result<T> {
  const Ok(this.value);

  final T value;

  @override
  String toString() => 'Ok($value)';
}

/// Неуспех.
final class Err<T> extends Result<T> {
  const Err(this.failure);

  final Failure failure;

  @override
  String toString() => 'Err($failure)';
}

/// Причина неуспеха — текст для лога и для сообщения упавшего теста.
///
/// Один класс без иерархии: до Фазы 2 никому не нужно различать ошибки
/// по типу, только прочитать, что случилось. Сообщение называет место
/// (id слова, имя поля), а не просто «битые данные».
class Failure {
  const Failure(this.message);

  final String message;

  @override
  String toString() => 'Failure($message)';
}
