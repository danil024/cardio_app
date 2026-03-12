import '../models/hr_zones.dart';
import '../../core/constants.dart';
import '../../core/utils.dart';

/// Расчёт зон пульса по возрасту (формула 220 - возраст)
class ZonesCalculator {
  ZonesCalculator._();

  /// Максимальная ЧСС по возрасту
  static int maxHrForAge(int age) {
    final a = AppUtils.clamp(age, AppConstants.minAge, AppConstants.maxAge);
    return AppConstants.maxHrBase - a;
  }

  /// Создание набора зон
  static HrZones calculate({
    required int age,
    double targetZoneMinPercent = AppConstants.defaultTargetZoneMin,
    double targetZoneMaxPercent = AppConstants.defaultTargetZoneMax,
  }) {
    final maxHr = maxHrForAge(age);

    final zones = [
      HrZone(
        type: HrZoneType.recovery,
        minBpm: (maxHr * AppConstants.zoneRecoveryMin).round(),
        maxBpm: (maxHr * AppConstants.zoneRecoveryMax).round(),
        minPercent: AppConstants.zoneRecoveryMin,
        maxPercent: AppConstants.zoneRecoveryMax,
        name: 'Восстановление',
      ),
      HrZone(
        type: HrZoneType.fatBurning,
        minBpm: (maxHr * AppConstants.zoneFatBurningMin).round(),
        maxBpm: (maxHr * AppConstants.zoneFatBurningMax).round(),
        minPercent: AppConstants.zoneFatBurningMin,
        maxPercent: AppConstants.zoneFatBurningMax,
        name: 'Жиросжигание',
      ),
      HrZone(
        type: HrZoneType.aerobic,
        minBpm: (maxHr * AppConstants.zoneAerobicMin).round(),
        maxBpm: (maxHr * AppConstants.zoneAerobicMax).round(),
        minPercent: AppConstants.zoneAerobicMin,
        maxPercent: AppConstants.zoneAerobicMax,
        name: 'Аэробная',
      ),
      HrZone(
        type: HrZoneType.anaerobic,
        minBpm: (maxHr * AppConstants.zoneAnaerobicMin).round(),
        maxBpm: (maxHr * AppConstants.zoneAnaerobicMax).round(),
        minPercent: AppConstants.zoneAnaerobicMin,
        maxPercent: AppConstants.zoneAnaerobicMax,
        name: 'Анаэробная',
      ),
      HrZone(
        type: HrZoneType.max,
        minBpm: (maxHr * AppConstants.zoneMaxMin).round(),
        maxBpm: maxHr,
        minPercent: AppConstants.zoneMaxMin,
        maxPercent: AppConstants.zoneMaxMax,
        name: 'Максимум',
      ),
    ];

    return HrZones(
      maxHr: maxHr,
      age: age,
      zones: zones,
      targetZoneMinPercent: targetZoneMinPercent,
      targetZoneMaxPercent: targetZoneMaxPercent,
    );
  }
}
