/// Стабильный идентификатор курса и направление словаря.
class StudyCourse {
  const StudyCourse({
    required this.id,
    required this.studyLanguage,
    required this.translationLanguage,
  });

  static const englishFromRussianId = 'ru-en';
  static const englishFromRussian = StudyCourse(
    id: englishFromRussianId,
    studyLanguage: 'en',
    translationLanguage: 'ru',
  );

  static const spanishFromRussian = StudyCourse(
    id: 'ru-es',
    studyLanguage: 'es',
    translationLanguage: 'ru',
  );

  static const englishFromSpanish = StudyCourse(
    id: 'es-en',
    studyLanguage: 'en',
    translationLanguage: 'es',
  );

  final String id;
  final String studyLanguage;
  final String translationLanguage;
}
