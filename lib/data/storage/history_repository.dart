import 'dart:convert';
import 'dart:io';

import '../../domain/models/hr_reading.dart';
import '../../domain/models/hr_zones.dart';
import '../../domain/services/zones_calculator.dart';
import 'session_storage.dart';

class SessionSummary {
  const SessionSummary({
    required this.id,
    required this.startedAt,
    required this.endedAt,
    required this.duration,
    required this.averageHr,
    required this.minHr,
    required this.maxHr,
    required this.zones,
    required this.jsonPath,
    required this.csvPath,
    required this.coachSummaryPath,
  });

  final String id;
  final DateTime startedAt;
  final DateTime? endedAt;
  final Duration duration;
  final int averageHr;
  final int minHr;
  final int maxHr;
  final HrZones zones;
  final String jsonPath;
  final String csvPath;
  final String coachSummaryPath;
}

class SessionDetail {
  const SessionDetail({
    required this.summary,
    required this.readings,
    required this.timeInZones,
  });

  final SessionSummary summary;
  final List<HrReading> readings;
  final Map<String, Duration> timeInZones;
}

class HistoryRepository {
  HistoryRepository({required SessionStorage sessionStorage})
      : _sessionStorage = sessionStorage;

  final SessionStorage _sessionStorage;

  Future<List<SessionSummary>> loadSummaries({int limit = 50}) async {
    final files = await _sessionStorage.listJsonSessions();
    final selected = files.take(limit);
    final summaries = <SessionSummary>[];
    for (final file in selected) {
      final raw = await file.readAsString();
      final map = jsonDecode(raw) as Map<String, dynamic>;
      final readings = _parseReadings(map['readings']);
      if (readings.isEmpty) continue;

      final age = (map['age'] as num?)?.toInt() ?? 35;
      final maxHr =
          (map['max_hr'] as num?)?.toInt() ?? ZonesCalculator.maxHrForAge(age);
      final targetMinBpm =
          (map['target_zone_min'] as num?)?.toInt() ?? (maxHr * 0.6).round();
      final targetMaxBpm =
          (map['target_zone_max'] as num?)?.toInt() ?? (maxHr * 0.7).round();
      final zones = ZonesCalculator.calculate(
        age: age,
        targetZoneMinPercent: targetMinBpm / maxHr,
        targetZoneMaxPercent: targetMaxBpm / maxHr,
      );

      final hrs = readings.map((r) => r.heartRate).toList();
      final avg = (hrs.reduce((a, b) => a + b) / hrs.length).round();
      final min = hrs.reduce((a, b) => a < b ? a : b);
      final max = hrs.reduce((a, b) => a > b ? a : b);
      final startedAt = DateTime.tryParse(map['started_at'] as String? ?? '') ??
          readings.first.timestamp;
      final endedAt = DateTime.tryParse(map['ended_at'] as String? ?? '');
      final duration = endedAt?.difference(startedAt) ??
          readings.last.timestamp.difference(readings.first.timestamp);
      final csvPath = file.path.replaceAll('.json', '.csv');
      final coachSummaryPath = file.path.replaceAll('.json', '.coach.json');

      summaries.add(
        SessionSummary(
          id: (map['session_id'] as String?) ?? file.uri.pathSegments.last,
          startedAt: startedAt,
          endedAt: endedAt,
          duration: duration,
          averageHr: avg,
          minHr: min,
          maxHr: max,
          zones: zones,
          jsonPath: file.path,
          csvPath: csvPath,
          coachSummaryPath: coachSummaryPath,
        ),
      );
    }
    return summaries;
  }

  Future<String> logsFolderPath() async {
    final dir = await _sessionStorage.getSessionsDirectory();
    return dir.path;
  }

  Future<void> deleteSession(SessionSummary summary) async {
    final jsonFile = File(summary.jsonPath);
    final csvFile = File(summary.csvPath);
    final coachSummaryFile = File(summary.coachSummaryPath);
    if (await jsonFile.exists()) {
      await jsonFile.delete();
    }
    if (await csvFile.exists()) {
      await csvFile.delete();
    }
    if (await coachSummaryFile.exists()) {
      await coachSummaryFile.delete();
    }
  }

  Future<int> deleteAllSessions() async {
    final dir = await _sessionStorage.getSessionsDirectory();
    if (!await dir.exists()) return 0;
    var deleted = 0;
    await for (final entity in dir.list(followLinks: false)) {
      if (entity is File &&
          (entity.path.endsWith('.json') ||
              entity.path.endsWith('.csv') ||
              entity.path.endsWith('.coach.json'))) {
        await entity.delete();
        deleted++;
      }
    }
    return deleted;
  }

  Future<SessionDetail> loadDetail(SessionSummary summary) async {
    final raw = await File(summary.jsonPath).readAsString();
    final map = jsonDecode(raw) as Map<String, dynamic>;
    final readings = _parseReadings(map['readings']);
    final zoneDurations = _calculateZoneDurations(readings, summary.zones);
    return SessionDetail(
      summary: summary,
      readings: readings,
      timeInZones: zoneDurations,
    );
  }

  Future<String> loadCsvContent(SessionSummary summary) async {
    return File(summary.csvPath).readAsString();
  }

  Future<String> loadJsonContent(SessionSummary summary) async {
    return File(summary.jsonPath).readAsString();
  }

  Future<String> loadCoachSummaryContent(SessionSummary summary) async {
    final coachFile = File(summary.coachSummaryPath);
    if (await coachFile.exists()) {
      return coachFile.readAsString();
    }
    final raw = await File(summary.jsonPath).readAsString();
    final map = jsonDecode(raw) as Map<String, dynamic>;
    map.remove('readings');
    return jsonEncode(map);
  }

  List<HrReading> _parseReadings(dynamic rawReadings) {
    final readingsList = (rawReadings as List<dynamic>? ?? []);
    return readingsList
        .map((e) => HrReading.fromJson(e as Map<String, dynamic>))
        .toList();
  }

  Map<String, Duration> _calculateZoneDurations(
      List<HrReading> readings, HrZones zones) {
    final result = <String, Duration>{};
    for (final zone in zones.zones) {
      result[zone.name] = Duration.zero;
    }
    for (int i = 0; i < readings.length - 1; i++) {
      final current = readings[i];
      final next = readings[i + 1];
      final delta = next.timestamp.difference(current.timestamp);
      final zone = zones.zoneFor(current.heartRate);
      if (zone != null) {
        result[zone.name] = (result[zone.name] ?? Duration.zero) + delta;
      }
    }
    return result;
  }
}
