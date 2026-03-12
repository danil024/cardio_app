import 'package:equatable/equatable.dart';
import '../../core/constants.dart';

/// Зона пульса
enum HrZoneType {
  recovery,
  fatBurning,
  aerobic,
  anaerobic,
  max,
}

/// Описание зоны пульса
class HrZone extends Equatable {
  const HrZone({
    required this.type,
    required this.minBpm,
    required this.maxBpm,
    required this.minPercent,
    required this.maxPercent,
    required this.name,
  });

  final HrZoneType type;
  final int minBpm;
  final int maxBpm;
  final double minPercent;
  final double maxPercent;
  final String name;

  bool contains(int bpm) => bpm >= minBpm && bpm <= maxBpm;

  @override
  List<Object?> get props => [type, minBpm, maxBpm];
}

/// Набор зон пульса на основе возраста
class HrZones extends Equatable {
  const HrZones({
    required this.maxHr,
    required this.age,
    required this.zones,
    required this.targetZoneMinPercent,
    required this.targetZoneMaxPercent,
  });

  final int maxHr;
  final int age;
  final List<HrZone> zones;
  final double targetZoneMinPercent;
  final double targetZoneMaxPercent;

  int get targetZoneMinBpm => (maxHr * targetZoneMinPercent).round();
  int get targetZoneMaxBpm => (maxHr * targetZoneMaxPercent).round();

  int get dangerZoneBpm => (maxHr * AppConstants.dangerZoneThreshold).round();

  bool isInTargetZone(int bpm) =>
      bpm >= targetZoneMinBpm && bpm <= targetZoneMaxBpm;

  bool isAboveTarget(int bpm) => bpm > targetZoneMaxBpm;

  bool isBelowTarget(int bpm) => bpm < targetZoneMinBpm;

  bool isInDangerZone(int bpm) => bpm >= dangerZoneBpm;

  HrZone? zoneFor(int bpm) {
    for (final zone in zones) {
      if (zone.contains(bpm)) return zone;
    }
    return null;
  }

  @override
  List<Object?> get props => [maxHr, age, zones, targetZoneMinPercent, targetZoneMaxPercent];
}
