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

  static const spanishFromEnglish = StudyCourse(
    id: 'en-es',
    studyLanguage: 'es',
    translationLanguage: 'en',
  );
  static const russianFromKazakh = StudyCourse(
    id: 'kk-ru',
    studyLanguage: 'ru',
    translationLanguage: 'kk',
  );
  static const englishFromKazakh = StudyCourse(
    id: 'kk-en',
    studyLanguage: 'en',
    translationLanguage: 'kk',
  );
  static const spanishFromKazakh = StudyCourse(
    id: 'kk-es',
    studyLanguage: 'es',
    translationLanguage: 'kk',
  );
  static const kazakhCourses = [
    russianFromKazakh,
    englishFromKazakh,
    spanishFromKazakh,
  ];

  static const germanFromRussian = StudyCourse(
    id: 'ru-de',
    studyLanguage: 'de',
    translationLanguage: 'ru',
  );
  static const germanFromEnglish = StudyCourse(
    id: 'en-de',
    studyLanguage: 'de',
    translationLanguage: 'en',
  );
  static const germanFromSpanish = StudyCourse(
    id: 'es-de',
    studyLanguage: 'de',
    translationLanguage: 'es',
  );
  static const germanFromKazakh = StudyCourse(
    id: 'kk-de',
    studyLanguage: 'de',
    translationLanguage: 'kk',
  );
  static const germanCourses = [
    germanFromRussian,
    germanFromEnglish,
    germanFromSpanish,
    germanFromKazakh,
  ];

  static final multilingualCourses = List<StudyCourse>.unmodifiable([
    for (final study in ['fr', 'zh', 'ar'])
      for (final bridge in ['ru', 'en', 'es', 'kk'])
        StudyCourse(
          id: '$bridge-$study',
          studyLanguage: study,
          translationLanguage: bridge,
        ),
  ]);

  final String id;
  final String studyLanguage;
  final String translationLanguage;
}
