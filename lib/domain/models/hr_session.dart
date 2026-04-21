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

  Map<String, dynamic> toCoachSummaryJson() {
    final ended = endedAt ?? (readings.isNotEmpty ? readings.last.timestamp : startedAt);
    final durationSec = ended.difference(startedAt).inSeconds.clamp(0, 24 * 3600 * 48);
    final hrValues = readings.map((r) => r.heartRate).toList()..sort();
    final avgHr = hrValues.isEmpty
        ? null
        : (hrValues.reduce((a, b) => a + b) / hrValues.length).round();
    final minHr = hrValues.isEmpty ? null : hrValues.first;
    final maxHr = hrValues.isEmpty ? null : hrValues.last;
    final p50 = hrValues.isEmpty ? null : _percentile(hrValues, 0.50);
    final p90 = hrValues.isEmpty ? null : _percentile(hrValues, 0.90);
    final zoneDurationsSec = _calculateZoneDurationsSeconds(endedAt: ended);
    final zoneSharesPct = <String, double>{};
    final totalZoneSec =
        zoneDurationsSec.values.fold<int>(0, (sum, value) => sum + value);
    for (final entry in zoneDurationsSec.entries) {
      zoneSharesPct[entry.key] =
          totalZoneSec == 0 ? 0 : (entry.value * 10000 / totalZoneSec).round() / 100;
    }
    return {
      'format': 'cardio_app_coach_summary',
      'format_version': 1,
      'session_id': id,
      'started_at': startedAt.toIso8601String(),
      'ended_at': endedAt?.toIso8601String(),
      'duration_sec': durationSec,
      'heart_rate_unit': 'bpm',
      'samples_count': readings.length,
      'zones': {
        'age': zones.age,
        'max_hr': zones.maxHr,
        'target_zone_min': zones.targetZoneMinBpm,
        'target_zone_max': zones.targetZoneMaxBpm,
      },
      'hr_stats': {
        'min': minHr,
        'max': maxHr,
        'avg': avgHr,
        'p50': p50,
        'p90': p90,
      },
      'time_in_zones_sec': zoneDurationsSec,
      'time_in_zones_pct': zoneSharesPct,
    };
  }

  int _percentile(List<int> sorted, double percentile) {
    if (sorted.isEmpty) return 0;
    final index = ((sorted.length - 1) * percentile).round().clamp(0, sorted.length - 1);
    return sorted[index];
  }

  Map<String, int> _calculateZoneDurationsSeconds({required DateTime endedAt}) {
    final result = <String, int>{};
    for (final zone in zones.zones) {
      result[zone.name] = 0;
    }
    if (readings.length < 2) {
      return result;
    }
    for (var i = 0; i < readings.length - 1; i++) {
      final current = readings[i];
      final next = readings[i + 1];
      final deltaSec =
          next.timestamp.difference(current.timestamp).inSeconds.clamp(0, 60);
      final zone = zones.zoneFor(current.heartRate);
      if (zone != null && deltaSec > 0) {
        result[zone.name] = (result[zone.name] ?? 0) + deltaSec;
      }
    }
    final last = readings.last;
    final tailDelta = endedAt.difference(last.timestamp).inSeconds.clamp(0, 60);
    final tailZone = zones.zoneFor(last.heartRate);
    if (tailZone != null && tailDelta > 0) {
      result[tailZone.name] = (result[tailZone.name] ?? 0) + tailDelta;
    }
    return result;
  }

  @override
  List<Object?> get props => [id, startedAt, zones, readings, endedAt];
}
