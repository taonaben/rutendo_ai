// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'calibration_harness_database.dart';

// ignore_for_file: type=lint
class $CalibrationSessionsTable extends CalibrationSessions
    with TableInfo<$CalibrationSessionsTable, CalibrationSession> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $CalibrationSessionsTable(this.attachedDatabase, [this._alias]);
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
  static const VerificationMeta _startedAtMsMeta = const VerificationMeta(
    'startedAtMs',
  );
  @override
  late final GeneratedColumn<int> startedAtMs = GeneratedColumn<int>(
    'started_at_ms',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _endedAtMsMeta = const VerificationMeta(
    'endedAtMs',
  );
  @override
  late final GeneratedColumn<int> endedAtMs = GeneratedColumn<int>(
    'ended_at_ms',
    aliasedName,
    true,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _modeMeta = const VerificationMeta('mode');
  @override
  late final GeneratedColumn<String> mode = GeneratedColumn<String>(
    'mode',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
    defaultValue: const Constant('live'),
  );
  static const VerificationMeta _notesMeta = const VerificationMeta('notes');
  @override
  late final GeneratedColumn<String> notes = GeneratedColumn<String>(
    'notes',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  @override
  List<GeneratedColumn> get $columns => [
    id,
    startedAtMs,
    endedAtMs,
    mode,
    notes,
  ];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'calibration_sessions';
  @override
  VerificationContext validateIntegrity(
    Insertable<CalibrationSession> instance, {
    bool isInserting = false,
  }) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('id')) {
      context.handle(_idMeta, id.isAcceptableOrUnknown(data['id']!, _idMeta));
    }
    if (data.containsKey('started_at_ms')) {
      context.handle(
        _startedAtMsMeta,
        startedAtMs.isAcceptableOrUnknown(
          data['started_at_ms']!,
          _startedAtMsMeta,
        ),
      );
    } else if (isInserting) {
      context.missing(_startedAtMsMeta);
    }
    if (data.containsKey('ended_at_ms')) {
      context.handle(
        _endedAtMsMeta,
        endedAtMs.isAcceptableOrUnknown(data['ended_at_ms']!, _endedAtMsMeta),
      );
    }
    if (data.containsKey('mode')) {
      context.handle(
        _modeMeta,
        mode.isAcceptableOrUnknown(data['mode']!, _modeMeta),
      );
    }
    if (data.containsKey('notes')) {
      context.handle(
        _notesMeta,
        notes.isAcceptableOrUnknown(data['notes']!, _notesMeta),
      );
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {id};
  @override
  CalibrationSession map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return CalibrationSession(
      id:
          attachedDatabase.typeMapping.read(
            DriftSqlType.int,
            data['${effectivePrefix}id'],
          )!,
      startedAtMs:
          attachedDatabase.typeMapping.read(
            DriftSqlType.int,
            data['${effectivePrefix}started_at_ms'],
          )!,
      endedAtMs: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}ended_at_ms'],
      ),
      mode:
          attachedDatabase.typeMapping.read(
            DriftSqlType.string,
            data['${effectivePrefix}mode'],
          )!,
      notes: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}notes'],
      ),
    );
  }

  @override
  $CalibrationSessionsTable createAlias(String alias) {
    return $CalibrationSessionsTable(attachedDatabase, alias);
  }
}

class CalibrationSession extends DataClass
    implements Insertable<CalibrationSession> {
  final int id;
  final int startedAtMs;
  final int? endedAtMs;
  final String mode;
  final String? notes;
  const CalibrationSession({
    required this.id,
    required this.startedAtMs,
    this.endedAtMs,
    required this.mode,
    this.notes,
  });
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['id'] = Variable<int>(id);
    map['started_at_ms'] = Variable<int>(startedAtMs);
    if (!nullToAbsent || endedAtMs != null) {
      map['ended_at_ms'] = Variable<int>(endedAtMs);
    }
    map['mode'] = Variable<String>(mode);
    if (!nullToAbsent || notes != null) {
      map['notes'] = Variable<String>(notes);
    }
    return map;
  }

  CalibrationSessionsCompanion toCompanion(bool nullToAbsent) {
    return CalibrationSessionsCompanion(
      id: Value(id),
      startedAtMs: Value(startedAtMs),
      endedAtMs:
          endedAtMs == null && nullToAbsent
              ? const Value.absent()
              : Value(endedAtMs),
      mode: Value(mode),
      notes:
          notes == null && nullToAbsent ? const Value.absent() : Value(notes),
    );
  }

  factory CalibrationSession.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return CalibrationSession(
      id: serializer.fromJson<int>(json['id']),
      startedAtMs: serializer.fromJson<int>(json['startedAtMs']),
      endedAtMs: serializer.fromJson<int?>(json['endedAtMs']),
      mode: serializer.fromJson<String>(json['mode']),
      notes: serializer.fromJson<String?>(json['notes']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'id': serializer.toJson<int>(id),
      'startedAtMs': serializer.toJson<int>(startedAtMs),
      'endedAtMs': serializer.toJson<int?>(endedAtMs),
      'mode': serializer.toJson<String>(mode),
      'notes': serializer.toJson<String?>(notes),
    };
  }

  CalibrationSession copyWith({
    int? id,
    int? startedAtMs,
    Value<int?> endedAtMs = const Value.absent(),
    String? mode,
    Value<String?> notes = const Value.absent(),
  }) => CalibrationSession(
    id: id ?? this.id,
    startedAtMs: startedAtMs ?? this.startedAtMs,
    endedAtMs: endedAtMs.present ? endedAtMs.value : this.endedAtMs,
    mode: mode ?? this.mode,
    notes: notes.present ? notes.value : this.notes,
  );
  CalibrationSession copyWithCompanion(CalibrationSessionsCompanion data) {
    return CalibrationSession(
      id: data.id.present ? data.id.value : this.id,
      startedAtMs:
          data.startedAtMs.present ? data.startedAtMs.value : this.startedAtMs,
      endedAtMs: data.endedAtMs.present ? data.endedAtMs.value : this.endedAtMs,
      mode: data.mode.present ? data.mode.value : this.mode,
      notes: data.notes.present ? data.notes.value : this.notes,
    );
  }

  @override
  String toString() {
    return (StringBuffer('CalibrationSession(')
          ..write('id: $id, ')
          ..write('startedAtMs: $startedAtMs, ')
          ..write('endedAtMs: $endedAtMs, ')
          ..write('mode: $mode, ')
          ..write('notes: $notes')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(id, startedAtMs, endedAtMs, mode, notes);
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is CalibrationSession &&
          other.id == this.id &&
          other.startedAtMs == this.startedAtMs &&
          other.endedAtMs == this.endedAtMs &&
          other.mode == this.mode &&
          other.notes == this.notes);
}

class CalibrationSessionsCompanion extends UpdateCompanion<CalibrationSession> {
  final Value<int> id;
  final Value<int> startedAtMs;
  final Value<int?> endedAtMs;
  final Value<String> mode;
  final Value<String?> notes;
  const CalibrationSessionsCompanion({
    this.id = const Value.absent(),
    this.startedAtMs = const Value.absent(),
    this.endedAtMs = const Value.absent(),
    this.mode = const Value.absent(),
    this.notes = const Value.absent(),
  });
  CalibrationSessionsCompanion.insert({
    this.id = const Value.absent(),
    required int startedAtMs,
    this.endedAtMs = const Value.absent(),
    this.mode = const Value.absent(),
    this.notes = const Value.absent(),
  }) : startedAtMs = Value(startedAtMs);
  static Insertable<CalibrationSession> custom({
    Expression<int>? id,
    Expression<int>? startedAtMs,
    Expression<int>? endedAtMs,
    Expression<String>? mode,
    Expression<String>? notes,
  }) {
    return RawValuesInsertable({
      if (id != null) 'id': id,
      if (startedAtMs != null) 'started_at_ms': startedAtMs,
      if (endedAtMs != null) 'ended_at_ms': endedAtMs,
      if (mode != null) 'mode': mode,
      if (notes != null) 'notes': notes,
    });
  }

  CalibrationSessionsCompanion copyWith({
    Value<int>? id,
    Value<int>? startedAtMs,
    Value<int?>? endedAtMs,
    Value<String>? mode,
    Value<String?>? notes,
  }) {
    return CalibrationSessionsCompanion(
      id: id ?? this.id,
      startedAtMs: startedAtMs ?? this.startedAtMs,
      endedAtMs: endedAtMs ?? this.endedAtMs,
      mode: mode ?? this.mode,
      notes: notes ?? this.notes,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (id.present) {
      map['id'] = Variable<int>(id.value);
    }
    if (startedAtMs.present) {
      map['started_at_ms'] = Variable<int>(startedAtMs.value);
    }
    if (endedAtMs.present) {
      map['ended_at_ms'] = Variable<int>(endedAtMs.value);
    }
    if (mode.present) {
      map['mode'] = Variable<String>(mode.value);
    }
    if (notes.present) {
      map['notes'] = Variable<String>(notes.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('CalibrationSessionsCompanion(')
          ..write('id: $id, ')
          ..write('startedAtMs: $startedAtMs, ')
          ..write('endedAtMs: $endedAtMs, ')
          ..write('mode: $mode, ')
          ..write('notes: $notes')
          ..write(')'))
        .toString();
  }
}

class $CalibrationFramesTable extends CalibrationFrames
    with TableInfo<$CalibrationFramesTable, CalibrationFrame> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $CalibrationFramesTable(this.attachedDatabase, [this._alias]);
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
  static const VerificationMeta _sessionIdMeta = const VerificationMeta(
    'sessionId',
  );
  @override
  late final GeneratedColumn<int> sessionId = GeneratedColumn<int>(
    'session_id',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _timestampMsMeta = const VerificationMeta(
    'timestampMs',
  );
  @override
  late final GeneratedColumn<int> timestampMs = GeneratedColumn<int>(
    'timestamp_ms',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _detectionsJsonMeta = const VerificationMeta(
    'detectionsJson',
  );
  @override
  late final GeneratedColumn<String> detectionsJson = GeneratedColumn<String>(
    'detections_json',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _motionObjectsJsonMeta = const VerificationMeta(
    'motionObjectsJson',
  );
  @override
  late final GeneratedColumn<String> motionObjectsJson =
      GeneratedColumn<String>(
        'motion_objects_json',
        aliasedName,
        false,
        type: DriftSqlType.string,
        requiredDuringInsert: true,
      );
  static const VerificationMeta _riskAssessmentJsonMeta =
      const VerificationMeta('riskAssessmentJson');
  @override
  late final GeneratedColumn<String> riskAssessmentJson =
      GeneratedColumn<String>(
        'risk_assessment_json',
        aliasedName,
        false,
        type: DriftSqlType.string,
        requiredDuringInsert: true,
      );
  @override
  List<GeneratedColumn> get $columns => [
    id,
    sessionId,
    timestampMs,
    detectionsJson,
    motionObjectsJson,
    riskAssessmentJson,
  ];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'calibration_frames';
  @override
  VerificationContext validateIntegrity(
    Insertable<CalibrationFrame> instance, {
    bool isInserting = false,
  }) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('id')) {
      context.handle(_idMeta, id.isAcceptableOrUnknown(data['id']!, _idMeta));
    }
    if (data.containsKey('session_id')) {
      context.handle(
        _sessionIdMeta,
        sessionId.isAcceptableOrUnknown(data['session_id']!, _sessionIdMeta),
      );
    } else if (isInserting) {
      context.missing(_sessionIdMeta);
    }
    if (data.containsKey('timestamp_ms')) {
      context.handle(
        _timestampMsMeta,
        timestampMs.isAcceptableOrUnknown(
          data['timestamp_ms']!,
          _timestampMsMeta,
        ),
      );
    } else if (isInserting) {
      context.missing(_timestampMsMeta);
    }
    if (data.containsKey('detections_json')) {
      context.handle(
        _detectionsJsonMeta,
        detectionsJson.isAcceptableOrUnknown(
          data['detections_json']!,
          _detectionsJsonMeta,
        ),
      );
    } else if (isInserting) {
      context.missing(_detectionsJsonMeta);
    }
    if (data.containsKey('motion_objects_json')) {
      context.handle(
        _motionObjectsJsonMeta,
        motionObjectsJson.isAcceptableOrUnknown(
          data['motion_objects_json']!,
          _motionObjectsJsonMeta,
        ),
      );
    } else if (isInserting) {
      context.missing(_motionObjectsJsonMeta);
    }
    if (data.containsKey('risk_assessment_json')) {
      context.handle(
        _riskAssessmentJsonMeta,
        riskAssessmentJson.isAcceptableOrUnknown(
          data['risk_assessment_json']!,
          _riskAssessmentJsonMeta,
        ),
      );
    } else if (isInserting) {
      context.missing(_riskAssessmentJsonMeta);
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {id};
  @override
  CalibrationFrame map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return CalibrationFrame(
      id:
          attachedDatabase.typeMapping.read(
            DriftSqlType.int,
            data['${effectivePrefix}id'],
          )!,
      sessionId:
          attachedDatabase.typeMapping.read(
            DriftSqlType.int,
            data['${effectivePrefix}session_id'],
          )!,
      timestampMs:
          attachedDatabase.typeMapping.read(
            DriftSqlType.int,
            data['${effectivePrefix}timestamp_ms'],
          )!,
      detectionsJson:
          attachedDatabase.typeMapping.read(
            DriftSqlType.string,
            data['${effectivePrefix}detections_json'],
          )!,
      motionObjectsJson:
          attachedDatabase.typeMapping.read(
            DriftSqlType.string,
            data['${effectivePrefix}motion_objects_json'],
          )!,
      riskAssessmentJson:
          attachedDatabase.typeMapping.read(
            DriftSqlType.string,
            data['${effectivePrefix}risk_assessment_json'],
          )!,
    );
  }

  @override
  $CalibrationFramesTable createAlias(String alias) {
    return $CalibrationFramesTable(attachedDatabase, alias);
  }
}

class CalibrationFrame extends DataClass
    implements Insertable<CalibrationFrame> {
  final int id;
  final int sessionId;
  final int timestampMs;
  final String detectionsJson;
  final String motionObjectsJson;
  final String riskAssessmentJson;
  const CalibrationFrame({
    required this.id,
    required this.sessionId,
    required this.timestampMs,
    required this.detectionsJson,
    required this.motionObjectsJson,
    required this.riskAssessmentJson,
  });
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['id'] = Variable<int>(id);
    map['session_id'] = Variable<int>(sessionId);
    map['timestamp_ms'] = Variable<int>(timestampMs);
    map['detections_json'] = Variable<String>(detectionsJson);
    map['motion_objects_json'] = Variable<String>(motionObjectsJson);
    map['risk_assessment_json'] = Variable<String>(riskAssessmentJson);
    return map;
  }

  CalibrationFramesCompanion toCompanion(bool nullToAbsent) {
    return CalibrationFramesCompanion(
      id: Value(id),
      sessionId: Value(sessionId),
      timestampMs: Value(timestampMs),
      detectionsJson: Value(detectionsJson),
      motionObjectsJson: Value(motionObjectsJson),
      riskAssessmentJson: Value(riskAssessmentJson),
    );
  }

  factory CalibrationFrame.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return CalibrationFrame(
      id: serializer.fromJson<int>(json['id']),
      sessionId: serializer.fromJson<int>(json['sessionId']),
      timestampMs: serializer.fromJson<int>(json['timestampMs']),
      detectionsJson: serializer.fromJson<String>(json['detectionsJson']),
      motionObjectsJson: serializer.fromJson<String>(json['motionObjectsJson']),
      riskAssessmentJson: serializer.fromJson<String>(
        json['riskAssessmentJson'],
      ),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'id': serializer.toJson<int>(id),
      'sessionId': serializer.toJson<int>(sessionId),
      'timestampMs': serializer.toJson<int>(timestampMs),
      'detectionsJson': serializer.toJson<String>(detectionsJson),
      'motionObjectsJson': serializer.toJson<String>(motionObjectsJson),
      'riskAssessmentJson': serializer.toJson<String>(riskAssessmentJson),
    };
  }

  CalibrationFrame copyWith({
    int? id,
    int? sessionId,
    int? timestampMs,
    String? detectionsJson,
    String? motionObjectsJson,
    String? riskAssessmentJson,
  }) => CalibrationFrame(
    id: id ?? this.id,
    sessionId: sessionId ?? this.sessionId,
    timestampMs: timestampMs ?? this.timestampMs,
    detectionsJson: detectionsJson ?? this.detectionsJson,
    motionObjectsJson: motionObjectsJson ?? this.motionObjectsJson,
    riskAssessmentJson: riskAssessmentJson ?? this.riskAssessmentJson,
  );
  CalibrationFrame copyWithCompanion(CalibrationFramesCompanion data) {
    return CalibrationFrame(
      id: data.id.present ? data.id.value : this.id,
      sessionId: data.sessionId.present ? data.sessionId.value : this.sessionId,
      timestampMs:
          data.timestampMs.present ? data.timestampMs.value : this.timestampMs,
      detectionsJson:
          data.detectionsJson.present
              ? data.detectionsJson.value
              : this.detectionsJson,
      motionObjectsJson:
          data.motionObjectsJson.present
              ? data.motionObjectsJson.value
              : this.motionObjectsJson,
      riskAssessmentJson:
          data.riskAssessmentJson.present
              ? data.riskAssessmentJson.value
              : this.riskAssessmentJson,
    );
  }

  @override
  String toString() {
    return (StringBuffer('CalibrationFrame(')
          ..write('id: $id, ')
          ..write('sessionId: $sessionId, ')
          ..write('timestampMs: $timestampMs, ')
          ..write('detectionsJson: $detectionsJson, ')
          ..write('motionObjectsJson: $motionObjectsJson, ')
          ..write('riskAssessmentJson: $riskAssessmentJson')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(
    id,
    sessionId,
    timestampMs,
    detectionsJson,
    motionObjectsJson,
    riskAssessmentJson,
  );
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is CalibrationFrame &&
          other.id == this.id &&
          other.sessionId == this.sessionId &&
          other.timestampMs == this.timestampMs &&
          other.detectionsJson == this.detectionsJson &&
          other.motionObjectsJson == this.motionObjectsJson &&
          other.riskAssessmentJson == this.riskAssessmentJson);
}

class CalibrationFramesCompanion extends UpdateCompanion<CalibrationFrame> {
  final Value<int> id;
  final Value<int> sessionId;
  final Value<int> timestampMs;
  final Value<String> detectionsJson;
  final Value<String> motionObjectsJson;
  final Value<String> riskAssessmentJson;
  const CalibrationFramesCompanion({
    this.id = const Value.absent(),
    this.sessionId = const Value.absent(),
    this.timestampMs = const Value.absent(),
    this.detectionsJson = const Value.absent(),
    this.motionObjectsJson = const Value.absent(),
    this.riskAssessmentJson = const Value.absent(),
  });
  CalibrationFramesCompanion.insert({
    this.id = const Value.absent(),
    required int sessionId,
    required int timestampMs,
    required String detectionsJson,
    required String motionObjectsJson,
    required String riskAssessmentJson,
  }) : sessionId = Value(sessionId),
       timestampMs = Value(timestampMs),
       detectionsJson = Value(detectionsJson),
       motionObjectsJson = Value(motionObjectsJson),
       riskAssessmentJson = Value(riskAssessmentJson);
  static Insertable<CalibrationFrame> custom({
    Expression<int>? id,
    Expression<int>? sessionId,
    Expression<int>? timestampMs,
    Expression<String>? detectionsJson,
    Expression<String>? motionObjectsJson,
    Expression<String>? riskAssessmentJson,
  }) {
    return RawValuesInsertable({
      if (id != null) 'id': id,
      if (sessionId != null) 'session_id': sessionId,
      if (timestampMs != null) 'timestamp_ms': timestampMs,
      if (detectionsJson != null) 'detections_json': detectionsJson,
      if (motionObjectsJson != null) 'motion_objects_json': motionObjectsJson,
      if (riskAssessmentJson != null)
        'risk_assessment_json': riskAssessmentJson,
    });
  }

  CalibrationFramesCompanion copyWith({
    Value<int>? id,
    Value<int>? sessionId,
    Value<int>? timestampMs,
    Value<String>? detectionsJson,
    Value<String>? motionObjectsJson,
    Value<String>? riskAssessmentJson,
  }) {
    return CalibrationFramesCompanion(
      id: id ?? this.id,
      sessionId: sessionId ?? this.sessionId,
      timestampMs: timestampMs ?? this.timestampMs,
      detectionsJson: detectionsJson ?? this.detectionsJson,
      motionObjectsJson: motionObjectsJson ?? this.motionObjectsJson,
      riskAssessmentJson: riskAssessmentJson ?? this.riskAssessmentJson,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (id.present) {
      map['id'] = Variable<int>(id.value);
    }
    if (sessionId.present) {
      map['session_id'] = Variable<int>(sessionId.value);
    }
    if (timestampMs.present) {
      map['timestamp_ms'] = Variable<int>(timestampMs.value);
    }
    if (detectionsJson.present) {
      map['detections_json'] = Variable<String>(detectionsJson.value);
    }
    if (motionObjectsJson.present) {
      map['motion_objects_json'] = Variable<String>(motionObjectsJson.value);
    }
    if (riskAssessmentJson.present) {
      map['risk_assessment_json'] = Variable<String>(riskAssessmentJson.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('CalibrationFramesCompanion(')
          ..write('id: $id, ')
          ..write('sessionId: $sessionId, ')
          ..write('timestampMs: $timestampMs, ')
          ..write('detectionsJson: $detectionsJson, ')
          ..write('motionObjectsJson: $motionObjectsJson, ')
          ..write('riskAssessmentJson: $riskAssessmentJson')
          ..write(')'))
        .toString();
  }
}

abstract class _$CalibrationHarnessDatabase extends GeneratedDatabase {
  _$CalibrationHarnessDatabase(QueryExecutor e) : super(e);
  $CalibrationHarnessDatabaseManager get managers =>
      $CalibrationHarnessDatabaseManager(this);
  late final $CalibrationSessionsTable calibrationSessions =
      $CalibrationSessionsTable(this);
  late final $CalibrationFramesTable calibrationFrames =
      $CalibrationFramesTable(this);
  @override
  Iterable<TableInfo<Table, Object?>> get allTables =>
      allSchemaEntities.whereType<TableInfo<Table, Object?>>();
  @override
  List<DatabaseSchemaEntity> get allSchemaEntities => [
    calibrationSessions,
    calibrationFrames,
  ];
}

typedef $$CalibrationSessionsTableCreateCompanionBuilder =
    CalibrationSessionsCompanion Function({
      Value<int> id,
      required int startedAtMs,
      Value<int?> endedAtMs,
      Value<String> mode,
      Value<String?> notes,
    });
typedef $$CalibrationSessionsTableUpdateCompanionBuilder =
    CalibrationSessionsCompanion Function({
      Value<int> id,
      Value<int> startedAtMs,
      Value<int?> endedAtMs,
      Value<String> mode,
      Value<String?> notes,
    });

class $$CalibrationSessionsTableFilterComposer
    extends Composer<_$CalibrationHarnessDatabase, $CalibrationSessionsTable> {
  $$CalibrationSessionsTableFilterComposer({
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

  ColumnFilters<int> get startedAtMs => $composableBuilder(
    column: $table.startedAtMs,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get endedAtMs => $composableBuilder(
    column: $table.endedAtMs,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get mode => $composableBuilder(
    column: $table.mode,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get notes => $composableBuilder(
    column: $table.notes,
    builder: (column) => ColumnFilters(column),
  );
}

class $$CalibrationSessionsTableOrderingComposer
    extends Composer<_$CalibrationHarnessDatabase, $CalibrationSessionsTable> {
  $$CalibrationSessionsTableOrderingComposer({
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

  ColumnOrderings<int> get startedAtMs => $composableBuilder(
    column: $table.startedAtMs,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get endedAtMs => $composableBuilder(
    column: $table.endedAtMs,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get mode => $composableBuilder(
    column: $table.mode,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get notes => $composableBuilder(
    column: $table.notes,
    builder: (column) => ColumnOrderings(column),
  );
}

class $$CalibrationSessionsTableAnnotationComposer
    extends Composer<_$CalibrationHarnessDatabase, $CalibrationSessionsTable> {
  $$CalibrationSessionsTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<int> get id =>
      $composableBuilder(column: $table.id, builder: (column) => column);

  GeneratedColumn<int> get startedAtMs => $composableBuilder(
    column: $table.startedAtMs,
    builder: (column) => column,
  );

  GeneratedColumn<int> get endedAtMs =>
      $composableBuilder(column: $table.endedAtMs, builder: (column) => column);

  GeneratedColumn<String> get mode =>
      $composableBuilder(column: $table.mode, builder: (column) => column);

  GeneratedColumn<String> get notes =>
      $composableBuilder(column: $table.notes, builder: (column) => column);
}

class $$CalibrationSessionsTableTableManager
    extends
        RootTableManager<
          _$CalibrationHarnessDatabase,
          $CalibrationSessionsTable,
          CalibrationSession,
          $$CalibrationSessionsTableFilterComposer,
          $$CalibrationSessionsTableOrderingComposer,
          $$CalibrationSessionsTableAnnotationComposer,
          $$CalibrationSessionsTableCreateCompanionBuilder,
          $$CalibrationSessionsTableUpdateCompanionBuilder,
          (
            CalibrationSession,
            BaseReferences<
              _$CalibrationHarnessDatabase,
              $CalibrationSessionsTable,
              CalibrationSession
            >,
          ),
          CalibrationSession,
          PrefetchHooks Function()
        > {
  $$CalibrationSessionsTableTableManager(
    _$CalibrationHarnessDatabase db,
    $CalibrationSessionsTable table,
  ) : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer:
              () => $$CalibrationSessionsTableFilterComposer(
                $db: db,
                $table: table,
              ),
          createOrderingComposer:
              () => $$CalibrationSessionsTableOrderingComposer(
                $db: db,
                $table: table,
              ),
          createComputedFieldComposer:
              () => $$CalibrationSessionsTableAnnotationComposer(
                $db: db,
                $table: table,
              ),
          updateCompanionCallback:
              ({
                Value<int> id = const Value.absent(),
                Value<int> startedAtMs = const Value.absent(),
                Value<int?> endedAtMs = const Value.absent(),
                Value<String> mode = const Value.absent(),
                Value<String?> notes = const Value.absent(),
              }) => CalibrationSessionsCompanion(
                id: id,
                startedAtMs: startedAtMs,
                endedAtMs: endedAtMs,
                mode: mode,
                notes: notes,
              ),
          createCompanionCallback:
              ({
                Value<int> id = const Value.absent(),
                required int startedAtMs,
                Value<int?> endedAtMs = const Value.absent(),
                Value<String> mode = const Value.absent(),
                Value<String?> notes = const Value.absent(),
              }) => CalibrationSessionsCompanion.insert(
                id: id,
                startedAtMs: startedAtMs,
                endedAtMs: endedAtMs,
                mode: mode,
                notes: notes,
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

typedef $$CalibrationSessionsTableProcessedTableManager =
    ProcessedTableManager<
      _$CalibrationHarnessDatabase,
      $CalibrationSessionsTable,
      CalibrationSession,
      $$CalibrationSessionsTableFilterComposer,
      $$CalibrationSessionsTableOrderingComposer,
      $$CalibrationSessionsTableAnnotationComposer,
      $$CalibrationSessionsTableCreateCompanionBuilder,
      $$CalibrationSessionsTableUpdateCompanionBuilder,
      (
        CalibrationSession,
        BaseReferences<
          _$CalibrationHarnessDatabase,
          $CalibrationSessionsTable,
          CalibrationSession
        >,
      ),
      CalibrationSession,
      PrefetchHooks Function()
    >;
typedef $$CalibrationFramesTableCreateCompanionBuilder =
    CalibrationFramesCompanion Function({
      Value<int> id,
      required int sessionId,
      required int timestampMs,
      required String detectionsJson,
      required String motionObjectsJson,
      required String riskAssessmentJson,
    });
typedef $$CalibrationFramesTableUpdateCompanionBuilder =
    CalibrationFramesCompanion Function({
      Value<int> id,
      Value<int> sessionId,
      Value<int> timestampMs,
      Value<String> detectionsJson,
      Value<String> motionObjectsJson,
      Value<String> riskAssessmentJson,
    });

class $$CalibrationFramesTableFilterComposer
    extends Composer<_$CalibrationHarnessDatabase, $CalibrationFramesTable> {
  $$CalibrationFramesTableFilterComposer({
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

  ColumnFilters<int> get sessionId => $composableBuilder(
    column: $table.sessionId,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get timestampMs => $composableBuilder(
    column: $table.timestampMs,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get detectionsJson => $composableBuilder(
    column: $table.detectionsJson,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get motionObjectsJson => $composableBuilder(
    column: $table.motionObjectsJson,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get riskAssessmentJson => $composableBuilder(
    column: $table.riskAssessmentJson,
    builder: (column) => ColumnFilters(column),
  );
}

class $$CalibrationFramesTableOrderingComposer
    extends Composer<_$CalibrationHarnessDatabase, $CalibrationFramesTable> {
  $$CalibrationFramesTableOrderingComposer({
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

  ColumnOrderings<int> get sessionId => $composableBuilder(
    column: $table.sessionId,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get timestampMs => $composableBuilder(
    column: $table.timestampMs,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get detectionsJson => $composableBuilder(
    column: $table.detectionsJson,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get motionObjectsJson => $composableBuilder(
    column: $table.motionObjectsJson,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get riskAssessmentJson => $composableBuilder(
    column: $table.riskAssessmentJson,
    builder: (column) => ColumnOrderings(column),
  );
}

class $$CalibrationFramesTableAnnotationComposer
    extends Composer<_$CalibrationHarnessDatabase, $CalibrationFramesTable> {
  $$CalibrationFramesTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<int> get id =>
      $composableBuilder(column: $table.id, builder: (column) => column);

  GeneratedColumn<int> get sessionId =>
      $composableBuilder(column: $table.sessionId, builder: (column) => column);

  GeneratedColumn<int> get timestampMs => $composableBuilder(
    column: $table.timestampMs,
    builder: (column) => column,
  );

  GeneratedColumn<String> get detectionsJson => $composableBuilder(
    column: $table.detectionsJson,
    builder: (column) => column,
  );

  GeneratedColumn<String> get motionObjectsJson => $composableBuilder(
    column: $table.motionObjectsJson,
    builder: (column) => column,
  );

  GeneratedColumn<String> get riskAssessmentJson => $composableBuilder(
    column: $table.riskAssessmentJson,
    builder: (column) => column,
  );
}

class $$CalibrationFramesTableTableManager
    extends
        RootTableManager<
          _$CalibrationHarnessDatabase,
          $CalibrationFramesTable,
          CalibrationFrame,
          $$CalibrationFramesTableFilterComposer,
          $$CalibrationFramesTableOrderingComposer,
          $$CalibrationFramesTableAnnotationComposer,
          $$CalibrationFramesTableCreateCompanionBuilder,
          $$CalibrationFramesTableUpdateCompanionBuilder,
          (
            CalibrationFrame,
            BaseReferences<
              _$CalibrationHarnessDatabase,
              $CalibrationFramesTable,
              CalibrationFrame
            >,
          ),
          CalibrationFrame,
          PrefetchHooks Function()
        > {
  $$CalibrationFramesTableTableManager(
    _$CalibrationHarnessDatabase db,
    $CalibrationFramesTable table,
  ) : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer:
              () => $$CalibrationFramesTableFilterComposer(
                $db: db,
                $table: table,
              ),
          createOrderingComposer:
              () => $$CalibrationFramesTableOrderingComposer(
                $db: db,
                $table: table,
              ),
          createComputedFieldComposer:
              () => $$CalibrationFramesTableAnnotationComposer(
                $db: db,
                $table: table,
              ),
          updateCompanionCallback:
              ({
                Value<int> id = const Value.absent(),
                Value<int> sessionId = const Value.absent(),
                Value<int> timestampMs = const Value.absent(),
                Value<String> detectionsJson = const Value.absent(),
                Value<String> motionObjectsJson = const Value.absent(),
                Value<String> riskAssessmentJson = const Value.absent(),
              }) => CalibrationFramesCompanion(
                id: id,
                sessionId: sessionId,
                timestampMs: timestampMs,
                detectionsJson: detectionsJson,
                motionObjectsJson: motionObjectsJson,
                riskAssessmentJson: riskAssessmentJson,
              ),
          createCompanionCallback:
              ({
                Value<int> id = const Value.absent(),
                required int sessionId,
                required int timestampMs,
                required String detectionsJson,
                required String motionObjectsJson,
                required String riskAssessmentJson,
              }) => CalibrationFramesCompanion.insert(
                id: id,
                sessionId: sessionId,
                timestampMs: timestampMs,
                detectionsJson: detectionsJson,
                motionObjectsJson: motionObjectsJson,
                riskAssessmentJson: riskAssessmentJson,
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

typedef $$CalibrationFramesTableProcessedTableManager =
    ProcessedTableManager<
      _$CalibrationHarnessDatabase,
      $CalibrationFramesTable,
      CalibrationFrame,
      $$CalibrationFramesTableFilterComposer,
      $$CalibrationFramesTableOrderingComposer,
      $$CalibrationFramesTableAnnotationComposer,
      $$CalibrationFramesTableCreateCompanionBuilder,
      $$CalibrationFramesTableUpdateCompanionBuilder,
      (
        CalibrationFrame,
        BaseReferences<
          _$CalibrationHarnessDatabase,
          $CalibrationFramesTable,
          CalibrationFrame
        >,
      ),
      CalibrationFrame,
      PrefetchHooks Function()
    >;

class $CalibrationHarnessDatabaseManager {
  final _$CalibrationHarnessDatabase _db;
  $CalibrationHarnessDatabaseManager(this._db);
  $$CalibrationSessionsTableTableManager get calibrationSessions =>
      $$CalibrationSessionsTableTableManager(_db, _db.calibrationSessions);
  $$CalibrationFramesTableTableManager get calibrationFrames =>
      $$CalibrationFramesTableTableManager(_db, _db.calibrationFrames);
}
