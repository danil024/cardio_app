import 'package:equatable/equatable.dart';

import 'hr_reading.dart';
import 'hr_zones.dart';

/// Сессия тренировки
class HrSession extends Equatable {
  const HrSession({
    required this.id,
    required this.startedAt,
    required this.zones,
    this.readings = const [],
    this.endedAt,
  });

  final String id;
  final DateTime startedAt;
  final HrZones zones;
  final List<HrReading> readings;
  final DateTime? endedAt;

  Duration get duration {
    final end = endedAt ?? DateTime.now();
    return end.difference(startedAt);
  }

  HrReading? get latestReading =>
      readings.isEmpty ? null : readings.last;

  int? get currentHeartRate => latestReading?.heartRate;

  HrSession copyWith({
    String? id,
    DateTime? startedAt,
    HrZones? zones,
    List<HrReading>? readings,
    DateTime? endedAt,
  }) {
    return HrSession(
      id: id ?? this.id,
      startedAt: startedAt ?? this.startedAt,
      zones: zones ?? this.zones,
      readings: readings ?? this.readings,
      endedAt: endedAt ?? this.endedAt,
    );
  }

  Map<String, dynamic> toJson() => {
        'format': 'cardio_app_session',
        'format_version': 1,
        'session_id': id,
        'started_at': startedAt.toIso8601String(),
        'age': zones.age,
        'max_hr': zones.maxHr,
        'target_zone_min': zones.targetZoneMinBpm,
        'target_zone_max': zones.targetZoneMaxBpm,
        'heart_rate_unit': 'bpm',
        'ended_at': endedAt?.toIso8601String(),
        'readings': readings.map((r) => r.toJson()).toList(),
      };

  @override
  List<Object?> get props => [id, startedAt, zones, readings, endedAt];
}
