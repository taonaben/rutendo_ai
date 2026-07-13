import 'package:drift/drift.dart';
import 'package:drift_flutter/drift_flutter.dart';

part 'calibration_harness_database.g.dart';

class CalibrationSessions extends Table {
  IntColumn get id => integer().autoIncrement()();

  IntColumn get startedAtMs => integer()();

  IntColumn get endedAtMs => integer().nullable()();

  TextColumn get mode => text().withDefault(const Constant('live'))();

  TextColumn get notes => text().nullable()();
}

class CalibrationFrames extends Table {
  IntColumn get id => integer().autoIncrement()();

  IntColumn get sessionId => integer()();

  IntColumn get timestampMs => integer()();

  TextColumn get detectionsJson => text()();

  TextColumn get motionObjectsJson => text()();

  TextColumn get riskAssessmentJson => text()();
}

@DriftDatabase(tables: [CalibrationSessions, CalibrationFrames])
class CalibrationHarnessDatabase extends _$CalibrationHarnessDatabase {
  CalibrationHarnessDatabase()
    : super(driftDatabase(name: 'rutendo_calibration_harness'));

  @override
  int get schemaVersion => 1;

  @override
  MigrationStrategy get migration => MigrationStrategy(
    onCreate: (migrator) async {
      await migrator.createAll();
    },
  );
}
