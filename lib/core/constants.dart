/// Константы приложения Cardio HR Monitor
class AppConstants {
  AppConstants._();

  // BLE Heart Rate Profile (GEOID HS500)
  static const String heartRateServiceUuid =
      '0000180d-0000-1000-8000-00805f9b34fb';
  static const String heartRateMeasurementUuid =
      '00002a37-0000-1000-8000-00805f9b34fb';

  // Возраст
  static const int minAge = 18;
  static const int maxAge = 100;
  static const int defaultAge = 35;

  // Формула МЧСС
  static const int maxHrBase = 220;

  // Зоны пульса (% от МЧСС)
  static const double zoneRecoveryMin = 0.50;
  static const double zoneRecoveryMax = 0.60;
  static const double zoneFatBurningMin = 0.60;
  static const double zoneFatBurningMax = 0.70;
  static const double zoneAerobicMin = 0.70;
  static const double zoneAerobicMax = 0.80;
  static const double zoneAnaerobicMin = 0.80;
  static const double zoneAnaerobicMax = 0.90;
  static const double zoneMaxMin = 0.90;
  static const double zoneMaxMax = 1.00;

  // Целевая зона по умолчанию (жиросжигание)
  static const double defaultTargetZoneMin = 0.60;
  static const double defaultTargetZoneMax = 0.70;

  // Опасный лимит (% МЧСС) — сигнал «снизьте нагрузку»
  static const double dangerZoneThreshold = 0.90;

  // Оповещения
  static const Duration notificationCooldown = Duration(seconds: 20);

  // Окно графика (минуты)
  static const List<int> chartWindowOptions = [3, 5, 10, 20];
  static const int defaultChartWindowMinutes = 5;
  static const List<int> sensorPollIntervalOptionsMs = [500, 1000, 5000, 20000];
  static const int defaultSensorPollIntervalMs = 1000;

  // Папка для сессий
  static const String sessionsFolder = 'CardioSessions';
  static const String androidPublicLogsFolder =
      '/storage/emulated/0/CardioAppLog';

  // Порог объёма для предложения очистки (байты, ~100 MB)
  static const int storageCleanupThresholdBytes = 100 * 1024 * 1024;

  // Режим эмуляции пульсометра (для теста визуала на эмуляторе)
  static const bool enableMockHeartRate = false;
  static const int mockHrMin = 90;
  static const int mockHrMax = 160;
  static const Duration mockHrInterval = Duration(seconds: 1);
}
