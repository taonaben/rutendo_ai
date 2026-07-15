import 'package:drift/drift.dart' as drift;

import '../models/cue_decision.dart';
import '../models/detection_result.dart';
import '../models/motion_object.dart';
import 'calibration_codec.dart';
import 'calibration_harness_database.dart';

class CalibrationHarnessStore {
  CalibrationHarnessStore({CalibrationHarnessDatabase? database})
    : _database = database ?? CalibrationHarnessDatabase();

  final CalibrationHarnessDatabase _database;

  Future<int> startSession({String mode = 'live', String? notes}) async {
    return _database
        .into(_database.calibrationSessions)
        .insert(
          CalibrationSessionsCompanion.insert(
            startedAtMs: DateTime.now().millisecondsSinceEpoch,
            mode: drift.Value(mode),
            notes:
                notes == null ? const drift.Value.absent() : drift.Value(notes),
          ),
        );
  }

  Future<void> endSession(int sessionId) async {
    await (_database.update(_database.calibrationSessions)
      ..where((table) => table.id.equals(sessionId))).write(
      CalibrationSessionsCompanion(
        endedAtMs: drift.Value(DateTime.now().millisecondsSinceEpoch),
      ),
    );
  }

  Future<void> appendFrame({
    required int sessionId,
    required int timestampMs,
    required List<DetectionResult> detections,
    required List<MotionObject> motionObjects,
    required RiskAssessment riskAssessment,
  }) async {
    await _database
        .into(_database.calibrationFrames)
        .insert(
          CalibrationFramesCompanion.insert(
            sessionId: sessionId,
            timestampMs: timestampMs,
            detectionsJson: CalibrationCodec.detectionsToJson(detections),
            motionObjectsJson: CalibrationCodec.motionObjectsToJson(
              motionObjects,
            ),
            riskAssessmentJson: CalibrationCodec.riskAssessmentToJson(
              riskAssessment,
            ),
          ),
        );
  }

  Future<CalibrationSession?> latestCompletedSession() {
    final query =
        _database.select(_database.calibrationSessions)
          ..where((table) => table.endedAtMs.isNotNull())
          ..orderBy([
            (table) => drift.OrderingTerm(
              expression: table.endedAtMs,
              mode: drift.OrderingMode.desc,
            ),
          ])
          ..limit(1);
    return query.getSingleOrNull();
  }

  Future<List<CalibrationFrame>> framesForSession(int sessionId) {
    final query =
        _database.select(_database.calibrationFrames)
          ..where((table) => table.sessionId.equals(sessionId))
          ..orderBy([
            (table) => drift.OrderingTerm(
              expression: table.timestampMs,
              mode: drift.OrderingMode.asc,
            ),
          ]);
    return query.get();
  }

  Future<void> close() => _database.close();
}
