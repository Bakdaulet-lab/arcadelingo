// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'history_database.dart';

// ignore_for_file: type=lint
class $AnswersTable extends Answers with TableInfo<$AnswersTable, Answer> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $AnswersTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _idMeta = const VerificationMeta('id');
  @override
  late final GeneratedColumn<int> id = GeneratedColumn<int>(
    'id',
    aliasedName,
    false,
    hasAutoIncrement: true,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
    defaultConstraints: GeneratedColumn.constraintIsAlways(
      'PRIMARY KEY AUTOINCREMENT',
    ),
  );
  static const VerificationMeta _wordIdMeta = const VerificationMeta('wordId');
  @override
  late final GeneratedColumn<String> wordId = GeneratedColumn<String>(
    'word_id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _atUtcMicrosMeta = const VerificationMeta(
    'atUtcMicros',
  );
  @override
  late final GeneratedColumn<int> atUtcMicros = GeneratedColumn<int>(
    'at_utc_micros',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _localDayMeta = const VerificationMeta(
    'localDay',
  );
  @override
  late final GeneratedColumn<String> localDay = GeneratedColumn<String>(
    'local_day',
    aliasedName,
    false,
    additionalChecks: GeneratedColumn.checkTextLength(
      minTextLength: 10,
      maxTextLength: 10,
    ),
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  @override
  late final GeneratedColumnWithTypeConverter<ReviewGrade, String> grade =
      GeneratedColumn<String>(
        'grade',
        aliasedName,
        false,
        type: DriftSqlType.string,
        requiredDuringInsert: true,
      ).withConverter<ReviewGrade>($AnswersTable.$convertergrade);
  static const VerificationMeta _correctMeta = const VerificationMeta(
    'correct',
  );
  @override
  late final GeneratedColumn<bool> correct = GeneratedColumn<bool>(
    'correct',
    aliasedName,
    false,
    type: DriftSqlType.bool,
    requiredDuringInsert: true,
    defaultConstraints: GeneratedColumn.constraintIsAlways(
      'CHECK ("correct" IN (0, 1))',
    ),
  );
  static const VerificationMeta _responseMicrosMeta = const VerificationMeta(
    'responseMicros',
  );
  @override
  late final GeneratedColumn<int> responseMicros = GeneratedColumn<int>(
    'response_micros',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _limitMicrosMeta = const VerificationMeta(
    'limitMicros',
  );
  @override
  late final GeneratedColumn<int> limitMicros = GeneratedColumn<int>(
    'limit_micros',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _hintsUsedMeta = const VerificationMeta(
    'hintsUsed',
  );
  @override
  late final GeneratedColumn<int> hintsUsed = GeneratedColumn<int>(
    'hints_used',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _gameIdMeta = const VerificationMeta('gameId');
  @override
  late final GeneratedColumn<String> gameId = GeneratedColumn<String>(
    'game_id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _sessionIdMeta = const VerificationMeta(
    'sessionId',
  );
  @override
  late final GeneratedColumn<String> sessionId = GeneratedColumn<String>(
    'session_id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  @override
  List<GeneratedColumn> get $columns => [
    id,
    wordId,
    atUtcMicros,
    localDay,
    grade,
    correct,
    responseMicros,
    limitMicros,
    hintsUsed,
    gameId,
    sessionId,
  ];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'answers';
  @override
  VerificationContext validateIntegrity(
    Insertable<Answer> instance, {
    bool isInserting = false,
  }) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('id')) {
      context.handle(_idMeta, id.isAcceptableOrUnknown(data['id']!, _idMeta));
    }
    if (data.containsKey('word_id')) {
      context.handle(
        _wordIdMeta,
        wordId.isAcceptableOrUnknown(data['word_id']!, _wordIdMeta),
      );
    } else if (isInserting) {
      context.missing(_wordIdMeta);
    }
    if (data.containsKey('at_utc_micros')) {
      context.handle(
        _atUtcMicrosMeta,
        atUtcMicros.isAcceptableOrUnknown(
          data['at_utc_micros']!,
          _atUtcMicrosMeta,
        ),
      );
    } else if (isInserting) {
      context.missing(_atUtcMicrosMeta);
    }
    if (data.containsKey('local_day')) {
      context.handle(
        _localDayMeta,
        localDay.isAcceptableOrUnknown(data['local_day']!, _localDayMeta),
      );
    } else if (isInserting) {
      context.missing(_localDayMeta);
    }
    if (data.containsKey('correct')) {
      context.handle(
        _correctMeta,
        correct.isAcceptableOrUnknown(data['correct']!, _correctMeta),
      );
    } else if (isInserting) {
      context.missing(_correctMeta);
    }
    if (data.containsKey('response_micros')) {
      context.handle(
        _responseMicrosMeta,
        responseMicros.isAcceptableOrUnknown(
          data['response_micros']!,
          _responseMicrosMeta,
        ),
      );
    } else if (isInserting) {
      context.missing(_responseMicrosMeta);
    }
    if (data.containsKey('limit_micros')) {
      context.handle(
        _limitMicrosMeta,
        limitMicros.isAcceptableOrUnknown(
          data['limit_micros']!,
          _limitMicrosMeta,
        ),
      );
    } else if (isInserting) {
      context.missing(_limitMicrosMeta);
    }
    if (data.containsKey('hints_used')) {
      context.handle(
        _hintsUsedMeta,
        hintsUsed.isAcceptableOrUnknown(data['hints_used']!, _hintsUsedMeta),
      );
    } else if (isInserting) {
      context.missing(_hintsUsedMeta);
    }
    if (data.containsKey('game_id')) {
      context.handle(
        _gameIdMeta,
        gameId.isAcceptableOrUnknown(data['game_id']!, _gameIdMeta),
      );
    } else if (isInserting) {
      context.missing(_gameIdMeta);
    }
    if (data.containsKey('session_id')) {
      context.handle(
        _sessionIdMeta,
        sessionId.isAcceptableOrUnknown(data['session_id']!, _sessionIdMeta),
      );
    } else if (isInserting) {
      context.missing(_sessionIdMeta);
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {id};
  @override
  Answer map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return Answer(
      id:
          attachedDatabase.typeMapping.read(
            DriftSqlType.int,
            data['${effectivePrefix}id'],
          )!,
      wordId:
          attachedDatabase.typeMapping.read(
            DriftSqlType.string,
            data['${effectivePrefix}word_id'],
          )!,
      atUtcMicros:
          attachedDatabase.typeMapping.read(
            DriftSqlType.int,
            data['${effectivePrefix}at_utc_micros'],
          )!,
      localDay:
          attachedDatabase.typeMapping.read(
            DriftSqlType.string,
            data['${effectivePrefix}local_day'],
          )!,
      grade: $AnswersTable.$convertergrade.fromSql(
        attachedDatabase.typeMapping.read(
          DriftSqlType.string,
          data['${effectivePrefix}grade'],
        )!,
      ),
      correct:
          attachedDatabase.typeMapping.read(
            DriftSqlType.bool,
            data['${effectivePrefix}correct'],
          )!,
      responseMicros:
          attachedDatabase.typeMapping.read(
            DriftSqlType.int,
            data['${effectivePrefix}response_micros'],
          )!,
      limitMicros:
          attachedDatabase.typeMapping.read(
            DriftSqlType.int,
            data['${effectivePrefix}limit_micros'],
          )!,
      hintsUsed:
          attachedDatabase.typeMapping.read(
            DriftSqlType.int,
            data['${effectivePrefix}hints_used'],
          )!,
      gameId:
          attachedDatabase.typeMapping.read(
            DriftSqlType.string,
            data['${effectivePrefix}game_id'],
          )!,
      sessionId:
          attachedDatabase.typeMapping.read(
            DriftSqlType.string,
            data['${effectivePrefix}session_id'],
          )!,
    );
  }

  @override
  $AnswersTable createAlias(String alias) {
    return $AnswersTable(attachedDatabase, alias);
  }

  static JsonTypeConverter2<ReviewGrade, String, String> $convertergrade =
      const EnumNameConverter<ReviewGrade>(ReviewGrade.values);
}

class Answer extends DataClass implements Insertable<Answer> {
  /// Суррогатный ключ. Он же — вторичный порядок при равных моментах: два
  /// ответа в одну микросекунду невозможны на живых часах, но возможны на
  /// подставленных, и порядок переигровки не должен от этого зависеть.
  final int id;

  /// Слово из сида. Само слово не хранится: оно живёт в ассете и меняется
  /// вместе с ним, а копия в журнале через год начала бы врать.
  final String wordId;

  /// Момент ответа: микросекунды с эпохи, UTC.
  final int atUtcMicros;

  /// Локальный календарный день игравшего, `ГГГГ-ММ-ДД`.
  final String localDay;

  /// Оценка для планировщика — именем значения перечисления.
  ///
  /// Сохранена, а не пересчитывается при чтении: переигровка обязана
  /// прогонять те оценки, которые действительно применялись, а `gradeOutcome`
  /// со временем может измениться. Переименование значения `ReviewGrade` —
  /// миграция данных, а не рефакторинг.
  final ReviewGrade grade;

  /// Сырой факт от игры, как в `ReviewOutcome`.
  final bool correct;
  final int responseMicros;
  final int limitMicros;
  final int hintsUsed;

  /// Идентификатор из реестра `lib/app/games.dart`.
  final String gameId;

  /// Партия, внутри которой случился ответ.
  final String sessionId;
  const Answer({
    required this.id,
    required this.wordId,
    required this.atUtcMicros,
    required this.localDay,
    required this.grade,
    required this.correct,
    required this.responseMicros,
    required this.limitMicros,
    required this.hintsUsed,
    required this.gameId,
    required this.sessionId,
  });
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['id'] = Variable<int>(id);
    map['word_id'] = Variable<String>(wordId);
    map['at_utc_micros'] = Variable<int>(atUtcMicros);
    map['local_day'] = Variable<String>(localDay);
    {
      map['grade'] = Variable<String>(
        $AnswersTable.$convertergrade.toSql(grade),
      );
    }
    map['correct'] = Variable<bool>(correct);
    map['response_micros'] = Variable<int>(responseMicros);
    map['limit_micros'] = Variable<int>(limitMicros);
    map['hints_used'] = Variable<int>(hintsUsed);
    map['game_id'] = Variable<String>(gameId);
    map['session_id'] = Variable<String>(sessionId);
    return map;
  }

  AnswersCompanion toCompanion(bool nullToAbsent) {
    return AnswersCompanion(
      id: Value(id),
      wordId: Value(wordId),
      atUtcMicros: Value(atUtcMicros),
      localDay: Value(localDay),
      grade: Value(grade),
      correct: Value(correct),
      responseMicros: Value(responseMicros),
      limitMicros: Value(limitMicros),
      hintsUsed: Value(hintsUsed),
      gameId: Value(gameId),
      sessionId: Value(sessionId),
    );
  }

  factory Answer.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return Answer(
      id: serializer.fromJson<int>(json['id']),
      wordId: serializer.fromJson<String>(json['wordId']),
      atUtcMicros: serializer.fromJson<int>(json['atUtcMicros']),
      localDay: serializer.fromJson<String>(json['localDay']),
      grade: $AnswersTable.$convertergrade.fromJson(
        serializer.fromJson<String>(json['grade']),
      ),
      correct: serializer.fromJson<bool>(json['correct']),
      responseMicros: serializer.fromJson<int>(json['responseMicros']),
      limitMicros: serializer.fromJson<int>(json['limitMicros']),
      hintsUsed: serializer.fromJson<int>(json['hintsUsed']),
      gameId: serializer.fromJson<String>(json['gameId']),
      sessionId: serializer.fromJson<String>(json['sessionId']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'id': serializer.toJson<int>(id),
      'wordId': serializer.toJson<String>(wordId),
      'atUtcMicros': serializer.toJson<int>(atUtcMicros),
      'localDay': serializer.toJson<String>(localDay),
      'grade': serializer.toJson<String>(
        $AnswersTable.$convertergrade.toJson(grade),
      ),
      'correct': serializer.toJson<bool>(correct),
      'responseMicros': serializer.toJson<int>(responseMicros),
      'limitMicros': serializer.toJson<int>(limitMicros),
      'hintsUsed': serializer.toJson<int>(hintsUsed),
      'gameId': serializer.toJson<String>(gameId),
      'sessionId': serializer.toJson<String>(sessionId),
    };
  }

  Answer copyWith({
    int? id,
    String? wordId,
    int? atUtcMicros,
    String? localDay,
    ReviewGrade? grade,
    bool? correct,
    int? responseMicros,
    int? limitMicros,
    int? hintsUsed,
    String? gameId,
    String? sessionId,
  }) => Answer(
    id: id ?? this.id,
    wordId: wordId ?? this.wordId,
    atUtcMicros: atUtcMicros ?? this.atUtcMicros,
    localDay: localDay ?? this.localDay,
    grade: grade ?? this.grade,
    correct: correct ?? this.correct,
    responseMicros: responseMicros ?? this.responseMicros,
    limitMicros: limitMicros ?? this.limitMicros,
    hintsUsed: hintsUsed ?? this.hintsUsed,
    gameId: gameId ?? this.gameId,
    sessionId: sessionId ?? this.sessionId,
  );
  Answer copyWithCompanion(AnswersCompanion data) {
    return Answer(
      id: data.id.present ? data.id.value : this.id,
      wordId: data.wordId.present ? data.wordId.value : this.wordId,
      atUtcMicros:
          data.atUtcMicros.present ? data.atUtcMicros.value : this.atUtcMicros,
      localDay: data.localDay.present ? data.localDay.value : this.localDay,
      grade: data.grade.present ? data.grade.value : this.grade,
      correct: data.correct.present ? data.correct.value : this.correct,
      responseMicros:
          data.responseMicros.present
              ? data.responseMicros.value
              : this.responseMicros,
      limitMicros:
          data.limitMicros.present ? data.limitMicros.value : this.limitMicros,
      hintsUsed: data.hintsUsed.present ? data.hintsUsed.value : this.hintsUsed,
      gameId: data.gameId.present ? data.gameId.value : this.gameId,
      sessionId: data.sessionId.present ? data.sessionId.value : this.sessionId,
    );
  }

  @override
  String toString() {
    return (StringBuffer('Answer(')
          ..write('id: $id, ')
          ..write('wordId: $wordId, ')
          ..write('atUtcMicros: $atUtcMicros, ')
          ..write('localDay: $localDay, ')
          ..write('grade: $grade, ')
          ..write('correct: $correct, ')
          ..write('responseMicros: $responseMicros, ')
          ..write('limitMicros: $limitMicros, ')
          ..write('hintsUsed: $hintsUsed, ')
          ..write('gameId: $gameId, ')
          ..write('sessionId: $sessionId')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(
    id,
    wordId,
    atUtcMicros,
    localDay,
    grade,
    correct,
    responseMicros,
    limitMicros,
    hintsUsed,
    gameId,
    sessionId,
  );
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is Answer &&
          other.id == this.id &&
          other.wordId == this.wordId &&
          other.atUtcMicros == this.atUtcMicros &&
          other.localDay == this.localDay &&
          other.grade == this.grade &&
          other.correct == this.correct &&
          other.responseMicros == this.responseMicros &&
          other.limitMicros == this.limitMicros &&
          other.hintsUsed == this.hintsUsed &&
          other.gameId == this.gameId &&
          other.sessionId == this.sessionId);
}

class AnswersCompanion extends UpdateCompanion<Answer> {
  final Value<int> id;
  final Value<String> wordId;
  final Value<int> atUtcMicros;
  final Value<String> localDay;
  final Value<ReviewGrade> grade;
  final Value<bool> correct;
  final Value<int> responseMicros;
  final Value<int> limitMicros;
  final Value<int> hintsUsed;
  final Value<String> gameId;
  final Value<String> sessionId;
  const AnswersCompanion({
    this.id = const Value.absent(),
    this.wordId = const Value.absent(),
    this.atUtcMicros = const Value.absent(),
    this.localDay = const Value.absent(),
    this.grade = const Value.absent(),
    this.correct = const Value.absent(),
    this.responseMicros = const Value.absent(),
    this.limitMicros = const Value.absent(),
    this.hintsUsed = const Value.absent(),
    this.gameId = const Value.absent(),
    this.sessionId = const Value.absent(),
  });
  AnswersCompanion.insert({
    this.id = const Value.absent(),
    required String wordId,
    required int atUtcMicros,
    required String localDay,
    required ReviewGrade grade,
    required bool correct,
    required int responseMicros,
    required int limitMicros,
    required int hintsUsed,
    required String gameId,
    required String sessionId,
  }) : wordId = Value(wordId),
       atUtcMicros = Value(atUtcMicros),
       localDay = Value(localDay),
       grade = Value(grade),
       correct = Value(correct),
       responseMicros = Value(responseMicros),
       limitMicros = Value(limitMicros),
       hintsUsed = Value(hintsUsed),
       gameId = Value(gameId),
       sessionId = Value(sessionId);
  static Insertable<Answer> custom({
    Expression<int>? id,
    Expression<String>? wordId,
    Expression<int>? atUtcMicros,
    Expression<String>? localDay,
    Expression<String>? grade,
    Expression<bool>? correct,
    Expression<int>? responseMicros,
    Expression<int>? limitMicros,
    Expression<int>? hintsUsed,
    Expression<String>? gameId,
    Expression<String>? sessionId,
  }) {
    return RawValuesInsertable({
      if (id != null) 'id': id,
      if (wordId != null) 'word_id': wordId,
      if (atUtcMicros != null) 'at_utc_micros': atUtcMicros,
      if (localDay != null) 'local_day': localDay,
      if (grade != null) 'grade': grade,
      if (correct != null) 'correct': correct,
      if (responseMicros != null) 'response_micros': responseMicros,
      if (limitMicros != null) 'limit_micros': limitMicros,
      if (hintsUsed != null) 'hints_used': hintsUsed,
      if (gameId != null) 'game_id': gameId,
      if (sessionId != null) 'session_id': sessionId,
    });
  }

  AnswersCompanion copyWith({
    Value<int>? id,
    Value<String>? wordId,
    Value<int>? atUtcMicros,
    Value<String>? localDay,
    Value<ReviewGrade>? grade,
    Value<bool>? correct,
    Value<int>? responseMicros,
    Value<int>? limitMicros,
    Value<int>? hintsUsed,
    Value<String>? gameId,
    Value<String>? sessionId,
  }) {
    return AnswersCompanion(
      id: id ?? this.id,
      wordId: wordId ?? this.wordId,
      atUtcMicros: atUtcMicros ?? this.atUtcMicros,
      localDay: localDay ?? this.localDay,
      grade: grade ?? this.grade,
      correct: correct ?? this.correct,
      responseMicros: responseMicros ?? this.responseMicros,
      limitMicros: limitMicros ?? this.limitMicros,
      hintsUsed: hintsUsed ?? this.hintsUsed,
      gameId: gameId ?? this.gameId,
      sessionId: sessionId ?? this.sessionId,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (id.present) {
      map['id'] = Variable<int>(id.value);
    }
    if (wordId.present) {
      map['word_id'] = Variable<String>(wordId.value);
    }
    if (atUtcMicros.present) {
      map['at_utc_micros'] = Variable<int>(atUtcMicros.value);
    }
    if (localDay.present) {
      map['local_day'] = Variable<String>(localDay.value);
    }
    if (grade.present) {
      map['grade'] = Variable<String>(
        $AnswersTable.$convertergrade.toSql(grade.value),
      );
    }
    if (correct.present) {
      map['correct'] = Variable<bool>(correct.value);
    }
    if (responseMicros.present) {
      map['response_micros'] = Variable<int>(responseMicros.value);
    }
    if (limitMicros.present) {
      map['limit_micros'] = Variable<int>(limitMicros.value);
    }
    if (hintsUsed.present) {
      map['hints_used'] = Variable<int>(hintsUsed.value);
    }
    if (gameId.present) {
      map['game_id'] = Variable<String>(gameId.value);
    }
    if (sessionId.present) {
      map['session_id'] = Variable<String>(sessionId.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('AnswersCompanion(')
          ..write('id: $id, ')
          ..write('wordId: $wordId, ')
          ..write('atUtcMicros: $atUtcMicros, ')
          ..write('localDay: $localDay, ')
          ..write('grade: $grade, ')
          ..write('correct: $correct, ')
          ..write('responseMicros: $responseMicros, ')
          ..write('limitMicros: $limitMicros, ')
          ..write('hintsUsed: $hintsUsed, ')
          ..write('gameId: $gameId, ')
          ..write('sessionId: $sessionId')
          ..write(')'))
        .toString();
  }
}

abstract class _$HistoryDatabase extends GeneratedDatabase {
  _$HistoryDatabase(QueryExecutor e) : super(e);
  $HistoryDatabaseManager get managers => $HistoryDatabaseManager(this);
  late final $AnswersTable answers = $AnswersTable(this);
  late final Index answersWord = Index(
    'answers_word',
    'CREATE INDEX answers_word ON answers (word_id)',
  );
  late final Index answersDay = Index(
    'answers_day',
    'CREATE INDEX answers_day ON answers (local_day)',
  );
  @override
  Iterable<TableInfo<Table, Object?>> get allTables =>
      allSchemaEntities.whereType<TableInfo<Table, Object?>>();
  @override
  List<DatabaseSchemaEntity> get allSchemaEntities => [
    answers,
    answersWord,
    answersDay,
  ];
}

typedef $$AnswersTableCreateCompanionBuilder =
    AnswersCompanion Function({
      Value<int> id,
      required String wordId,
      required int atUtcMicros,
      required String localDay,
      required ReviewGrade grade,
      required bool correct,
      required int responseMicros,
      required int limitMicros,
      required int hintsUsed,
      required String gameId,
      required String sessionId,
    });
typedef $$AnswersTableUpdateCompanionBuilder =
    AnswersCompanion Function({
      Value<int> id,
      Value<String> wordId,
      Value<int> atUtcMicros,
      Value<String> localDay,
      Value<ReviewGrade> grade,
      Value<bool> correct,
      Value<int> responseMicros,
      Value<int> limitMicros,
      Value<int> hintsUsed,
      Value<String> gameId,
      Value<String> sessionId,
    });

class $$AnswersTableFilterComposer
    extends Composer<_$HistoryDatabase, $AnswersTable> {
  $$AnswersTableFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<int> get id => $composableBuilder(
    column: $table.id,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get wordId => $composableBuilder(
    column: $table.wordId,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get atUtcMicros => $composableBuilder(
    column: $table.atUtcMicros,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get localDay => $composableBuilder(
    column: $table.localDay,
    builder: (column) => ColumnFilters(column),
  );

  ColumnWithTypeConverterFilters<ReviewGrade, ReviewGrade, String> get grade =>
      $composableBuilder(
        column: $table.grade,
        builder: (column) => ColumnWithTypeConverterFilters(column),
      );

  ColumnFilters<bool> get correct => $composableBuilder(
    column: $table.correct,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get responseMicros => $composableBuilder(
    column: $table.responseMicros,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get limitMicros => $composableBuilder(
    column: $table.limitMicros,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get hintsUsed => $composableBuilder(
    column: $table.hintsUsed,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get gameId => $composableBuilder(
    column: $table.gameId,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get sessionId => $composableBuilder(
    column: $table.sessionId,
    builder: (column) => ColumnFilters(column),
  );
}

class $$AnswersTableOrderingComposer
    extends Composer<_$HistoryDatabase, $AnswersTable> {
  $$AnswersTableOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<int> get id => $composableBuilder(
    column: $table.id,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get wordId => $composableBuilder(
    column: $table.wordId,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get atUtcMicros => $composableBuilder(
    column: $table.atUtcMicros,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get localDay => $composableBuilder(
    column: $table.localDay,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get grade => $composableBuilder(
    column: $table.grade,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<bool> get correct => $composableBuilder(
    column: $table.correct,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get responseMicros => $composableBuilder(
    column: $table.responseMicros,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get limitMicros => $composableBuilder(
    column: $table.limitMicros,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get hintsUsed => $composableBuilder(
    column: $table.hintsUsed,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get gameId => $composableBuilder(
    column: $table.gameId,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get sessionId => $composableBuilder(
    column: $table.sessionId,
    builder: (column) => ColumnOrderings(column),
  );
}

class $$AnswersTableAnnotationComposer
    extends Composer<_$HistoryDatabase, $AnswersTable> {
  $$AnswersTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<int> get id =>
      $composableBuilder(column: $table.id, builder: (column) => column);

  GeneratedColumn<String> get wordId =>
      $composableBuilder(column: $table.wordId, builder: (column) => column);

  GeneratedColumn<int> get atUtcMicros => $composableBuilder(
    column: $table.atUtcMicros,
    builder: (column) => column,
  );

  GeneratedColumn<String> get localDay =>
      $composableBuilder(column: $table.localDay, builder: (column) => column);

  GeneratedColumnWithTypeConverter<ReviewGrade, String> get grade =>
      $composableBuilder(column: $table.grade, builder: (column) => column);

  GeneratedColumn<bool> get correct =>
      $composableBuilder(column: $table.correct, builder: (column) => column);

  GeneratedColumn<int> get responseMicros => $composableBuilder(
    column: $table.responseMicros,
    builder: (column) => column,
  );

  GeneratedColumn<int> get limitMicros => $composableBuilder(
    column: $table.limitMicros,
    builder: (column) => column,
  );

  GeneratedColumn<int> get hintsUsed =>
      $composableBuilder(column: $table.hintsUsed, builder: (column) => column);

  GeneratedColumn<String> get gameId =>
      $composableBuilder(column: $table.gameId, builder: (column) => column);

  GeneratedColumn<String> get sessionId =>
      $composableBuilder(column: $table.sessionId, builder: (column) => column);
}

class $$AnswersTableTableManager
    extends
        RootTableManager<
          _$HistoryDatabase,
          $AnswersTable,
          Answer,
          $$AnswersTableFilterComposer,
          $$AnswersTableOrderingComposer,
          $$AnswersTableAnnotationComposer,
          $$AnswersTableCreateCompanionBuilder,
          $$AnswersTableUpdateCompanionBuilder,
          (Answer, BaseReferences<_$HistoryDatabase, $AnswersTable, Answer>),
          Answer,
          PrefetchHooks Function()
        > {
  $$AnswersTableTableManager(_$HistoryDatabase db, $AnswersTable table)
    : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer:
              () => $$AnswersTableFilterComposer($db: db, $table: table),
          createOrderingComposer:
              () => $$AnswersTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer:
              () => $$AnswersTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback:
              ({
                Value<int> id = const Value.absent(),
                Value<String> wordId = const Value.absent(),
                Value<int> atUtcMicros = const Value.absent(),
                Value<String> localDay = const Value.absent(),
                Value<ReviewGrade> grade = const Value.absent(),
                Value<bool> correct = const Value.absent(),
                Value<int> responseMicros = const Value.absent(),
                Value<int> limitMicros = const Value.absent(),
                Value<int> hintsUsed = const Value.absent(),
                Value<String> gameId = const Value.absent(),
                Value<String> sessionId = const Value.absent(),
              }) => AnswersCompanion(
                id: id,
                wordId: wordId,
                atUtcMicros: atUtcMicros,
                localDay: localDay,
                grade: grade,
                correct: correct,
                responseMicros: responseMicros,
                limitMicros: limitMicros,
                hintsUsed: hintsUsed,
                gameId: gameId,
                sessionId: sessionId,
              ),
          createCompanionCallback:
              ({
                Value<int> id = const Value.absent(),
                required String wordId,
                required int atUtcMicros,
                required String localDay,
                required ReviewGrade grade,
                required bool correct,
                required int responseMicros,
                required int limitMicros,
                required int hintsUsed,
                required String gameId,
                required String sessionId,
              }) => AnswersCompanion.insert(
                id: id,
                wordId: wordId,
                atUtcMicros: atUtcMicros,
                localDay: localDay,
                grade: grade,
                correct: correct,
                responseMicros: responseMicros,
                limitMicros: limitMicros,
                hintsUsed: hintsUsed,
                gameId: gameId,
                sessionId: sessionId,
              ),
          withReferenceMapper:
              (p0) =>
                  p0
                      .map(
                        (e) => (
                          e.readTable(table),
                          BaseReferences(db, table, e),
                        ),
                      )
                      .toList(),
          prefetchHooksCallback: null,
        ),
      );
}

typedef $$AnswersTableProcessedTableManager =
    ProcessedTableManager<
      _$HistoryDatabase,
      $AnswersTable,
      Answer,
      $$AnswersTableFilterComposer,
      $$AnswersTableOrderingComposer,
      $$AnswersTableAnnotationComposer,
      $$AnswersTableCreateCompanionBuilder,
      $$AnswersTableUpdateCompanionBuilder,
      (Answer, BaseReferences<_$HistoryDatabase, $AnswersTable, Answer>),
      Answer,
      PrefetchHooks Function()
    >;

class $HistoryDatabaseManager {
  final _$HistoryDatabase _db;
  $HistoryDatabaseManager(this._db);
  $$AnswersTableTableManager get answers =>
      $$AnswersTableTableManager(_db, _db.answers);
}
