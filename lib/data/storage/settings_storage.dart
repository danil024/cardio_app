import 'package:shared_preferences/shared_preferences.dart';

import '../../core/constants.dart';
import '../../core/utils.dart';
import '../../domain/models/hr_zones.dart';
import '../../domain/services/zones_calculator.dart';

const _keyAge = 'age';
const _keyTargetZoneMin = 'target_zone_min';
const _keyTargetZoneMax = 'target_zone_max';
const _keySoundEnabled = 'sound_enabled';
const _keyTtsEnabled = 'tts_enabled';
const _keyFirstRun = 'first_run';
const _keyChartWindowMinutes = 'chart_window_minutes';
const _keyKeepScreenOn = 'keep_screen_on';
const _keyUiLanguage = 'ui_language';
const _keyTtsLanguage = 'tts_language';
const _keyEnableCustomEmergencyAlert = 'enable_custom_emergency_alert';
const _keyCustomEmergencyBpm = 'custom_emergency_bpm';
const _keyEnableStartExerciseAlert = 'enable_start_exercise_alert';
const _keyStartExerciseBpm = 'start_exercise_bpm';
const _keyEnableTimerStopwatch = 'enable_timer_stopwatch';
const _keyEnableMusicControls = 'enable_music_controls';
const _keyShowClockOnHome = 'show_clock_on_home';
const _keyShowConnectInHeader = 'show_connect_in_header';
const _keyTimerMode = 'timer_mode';
const _keyTimerDurationSeconds = 'timer_duration_seconds';
const _keyEnableRangeAlert = 'enable_range_alert';
const _keyRangeAlertMinBpm = 'range_alert_min_bpm';
const _keyRangeAlertMaxBpm = 'range_alert_max_bpm';
const _keyHrRangeMode = 'hr_range_mode';
const _keyEnableRangeBeep = 'enable_range_beep';
const _keyEnableRangeVoice = 'enable_range_voice';
const _keyZoneRangeBeep = 'zone_range_beep';
const _keyZoneRangeVoice = 'zone_range_voice';
const _keyManualRangeBeep = 'manual_range_beep';
const _keyManualRangeVoice = 'manual_range_voice';
const _keySessionsCustomDirPath = 'sessions_custom_dir_path';

/// Хранилище настроек
class SettingsStorage {
  SettingsStorage(this._prefs);

  final SharedPreferences _prefs;

  int get age => _prefs.getInt(_keyAge) ?? AppConstants.defaultAge;

  set age(int value) {
    _prefs.setInt(_keyAge,
        AppUtils.clamp(value, AppConstants.minAge, AppConstants.maxAge));
  }

  double get targetZoneMinPercent =>
      _prefs.getDouble(_keyTargetZoneMin) ?? AppConstants.defaultTargetZoneMin;

  set targetZoneMinPercent(double value) {
    _prefs.setDouble(_keyTargetZoneMin, value);
  }

  double get targetZoneMaxPercent =>
      _prefs.getDouble(_keyTargetZoneMax) ?? AppConstants.defaultTargetZoneMax;

  set targetZoneMaxPercent(double value) {
    _prefs.setDouble(_keyTargetZoneMax, value);
  }

  bool get soundEnabled => _prefs.getBool(_keySoundEnabled) ?? true;

  set soundEnabled(bool value) {
    _prefs.setBool(_keySoundEnabled, value);
  }

  bool get ttsEnabled => _prefs.getBool(_keyTtsEnabled) ?? true;

  set ttsEnabled(bool value) {
    _prefs.setBool(_keyTtsEnabled, value);
  }

  bool get isFirstRun => _prefs.getBool(_keyFirstRun) ?? true;

  set isFirstRun(bool value) {
    _prefs.setBool(_keyFirstRun, value);
  }

  int get chartWindowMinutes {
    final stored =
        _prefs.getInt(_keyChartWindowMinutes) ?? AppConstants.defaultChartWindowMinutes;
    if (AppConstants.chartWindowOptions.contains(stored)) {
      return stored;
    }
    // Soft migration from legacy 3-minute option and any invalid values.
    _prefs.setInt(_keyChartWindowMinutes, AppConstants.defaultChartWindowMinutes);
    return AppConstants.defaultChartWindowMinutes;
  }

  set chartWindowMinutes(int value) {
    if (AppConstants.chartWindowOptions.contains(value)) {
      _prefs.setInt(_keyChartWindowMinutes, value);
    }
  }

  bool get keepScreenOn => _prefs.getBool(_keyKeepScreenOn) ?? true;

  set keepScreenOn(bool value) {
    _prefs.setBool(_keyKeepScreenOn, value);
  }

  int get sensorPollIntervalMs =>
      AppConstants.mockIntervalMsForChartWindow(chartWindowMinutes);

  String get uiLanguage => _prefs.getString(_keyUiLanguage) ?? 'en';

  set uiLanguage(String value) {
    if (value == 'en' || value == 'ru') {
      _prefs.setString(_keyUiLanguage, value);
    }
  }

  String get ttsLanguage => _prefs.getString(_keyTtsLanguage) ?? 'en';

  set ttsLanguage(String value) {
    if (value == 'en' || value == 'ru') {
      _prefs.setString(_keyTtsLanguage, value);
    }
  }

  bool get enableCustomEmergencyAlert =>
      _prefs.getBool(_keyEnableCustomEmergencyAlert) ?? false;

  set enableCustomEmergencyAlert(bool value) {
    _prefs.setBool(_keyEnableCustomEmergencyAlert, value);
  }

  int get customEmergencyBpm => _prefs.getInt(_keyCustomEmergencyBpm) ?? 170;

  set customEmergencyBpm(int value) {
    _prefs.setInt(_keyCustomEmergencyBpm, AppUtils.clamp(value, 80, 230));
  }

  bool get enableStartExerciseAlert =>
      _prefs.getBool(_keyEnableStartExerciseAlert) ?? false;

  set enableStartExerciseAlert(bool value) {
    _prefs.setBool(_keyEnableStartExerciseAlert, value);
  }

  int get startExerciseBpm => _prefs.getInt(_keyStartExerciseBpm) ?? 110;

  set startExerciseBpm(int value) {
    _prefs.setInt(_keyStartExerciseBpm, AppUtils.clamp(value, 60, 200));
  }

  bool get enableTimerStopwatch =>
      _prefs.getBool(_keyEnableTimerStopwatch) ?? true;

  set enableTimerStopwatch(bool value) {
    _prefs.setBool(_keyEnableTimerStopwatch, value);
  }

  bool get enableMusicControls =>
      _prefs.getBool(_keyEnableMusicControls) ?? false;

  set enableMusicControls(bool value) {
    _prefs.setBool(_keyEnableMusicControls, value);
  }

  bool get showClockOnHome => _prefs.getBool(_keyShowClockOnHome) ?? true;

  set showClockOnHome(bool value) {
    _prefs.setBool(_keyShowClockOnHome, value);
  }

  bool get showConnectInHeader =>
      _prefs.getBool(_keyShowConnectInHeader) ?? true;

  set showConnectInHeader(bool value) {
    _prefs.setBool(_keyShowConnectInHeader, value);
  }

  String get timerMode => _prefs.getString(_keyTimerMode) ?? 'timer';

  set timerMode(String value) {
    if (value == 'timer' || value == 'stopwatch') {
      _prefs.setString(_keyTimerMode, value);
    }
  }

  int get timerDurationSeconds => _prefs.getInt(_keyTimerDurationSeconds) ?? 60;

  set timerDurationSeconds(int value) {
    _prefs.setInt(
        _keyTimerDurationSeconds, AppUtils.clamp(value, 10, 24 * 3600));
  }

  bool get enableRangeAlert => _prefs.getBool(_keyEnableRangeAlert) ?? false;

  set enableRangeAlert(bool value) {
    _prefs.setBool(_keyEnableRangeAlert, value);
  }

  String get hrRangeMode {
    final stored = _prefs.getString(_keyHrRangeMode);
    if (stored == 'zone' || stored == 'manual') {
      return stored!;
    }
    // Migration from legacy toggle: enabled manual range -> manual mode.
    return enableRangeAlert ? 'manual' : 'zone';
  }

  set hrRangeMode(String value) {
    if (value == 'zone' || value == 'manual') {
      _prefs.setString(_keyHrRangeMode, value);
    }
  }

  bool get enableRangeBeep {
    final stored = _prefs.getBool(_keyEnableRangeBeep);
    if (stored != null) {
      return stored;
    }
    // Migration default: preserve previous "sound enabled" behavior.
    return true;
  }

  set enableRangeBeep(bool value) {
    _prefs.setBool(_keyEnableRangeBeep, value);
  }

  bool get enableRangeVoice {
    final stored = _prefs.getBool(_keyEnableRangeVoice);
    if (stored != null) {
      return stored;
    }
    // Migration default: preserve previous "voice enabled" behavior.
    return true;
  }

  set enableRangeVoice(bool value) {
    _prefs.setBool(_keyEnableRangeVoice, value);
  }

  bool get zoneRangeBeepEnabled {
    final stored = _prefs.getBool(_keyZoneRangeBeep);
    if (stored != null) {
      return stored;
    }
    return true;
  }

  set zoneRangeBeepEnabled(bool value) {
    _prefs.setBool(_keyZoneRangeBeep, value);
  }

  bool get zoneRangeVoiceEnabled {
    final stored = _prefs.getBool(_keyZoneRangeVoice);
    if (stored != null) {
      return stored;
    }
    return true;
  }

  set zoneRangeVoiceEnabled(bool value) {
    _prefs.setBool(_keyZoneRangeVoice, value);
  }

  bool get manualRangeBeepEnabled {
    final stored = _prefs.getBool(_keyManualRangeBeep);
    if (stored != null) {
      return stored;
    }
    final legacy = _prefs.getBool(_keyEnableRangeBeep);
    if (legacy != null) {
      return legacy;
    }
    return true;
  }

  set manualRangeBeepEnabled(bool value) {
    _prefs.setBool(_keyManualRangeBeep, value);
    // Keep legacy key in sync for backward compatibility.
    _prefs.setBool(_keyEnableRangeBeep, value);
  }

  bool get manualRangeVoiceEnabled {
    final stored = _prefs.getBool(_keyManualRangeVoice);
    if (stored != null) {
      return stored;
    }
    final legacy = _prefs.getBool(_keyEnableRangeVoice);
    if (legacy != null) {
      return legacy;
    }
    return true;
  }

  set manualRangeVoiceEnabled(bool value) {
    _prefs.setBool(_keyManualRangeVoice, value);
    // Keep legacy key in sync for backward compatibility.
    _prefs.setBool(_keyEnableRangeVoice, value);
  }

  String? get sessionsCustomDirPath {
    final value = _prefs.getString(_keySessionsCustomDirPath);
    if (value == null || value.trim().isEmpty) {
      return null;
    }
    return value;
  }

  set sessionsCustomDirPath(String? value) {
    if (value == null || value.trim().isEmpty) {
      _prefs.remove(_keySessionsCustomDirPath);
      return;
    }
    _prefs.setString(_keySessionsCustomDirPath, value.trim());
  }

  int get rangeAlertMinBpm {
    final rawMin = _prefs.getInt(_keyRangeAlertMinBpm) ?? 110;
    final rawMax = _prefs.getInt(_keyRangeAlertMaxBpm) ?? 170;
    return AppUtils.clamp(rawMin, 50, AppUtils.clamp(rawMax - 1, 51, 229));
  }

  set rangeAlertMinBpm(int value) {
    final nextMin = AppUtils.clamp(value, 50, 229);
    var nextMax = rangeAlertMaxBpm;
    if (nextMin >= nextMax) {
      nextMax = AppUtils.clamp(nextMin + 1, 51, 230);
      _prefs.setInt(_keyRangeAlertMaxBpm, nextMax);
    }
    _prefs.setInt(_keyRangeAlertMinBpm, AppUtils.clamp(nextMin, 50, nextMax - 1));
  }

  int get rangeAlertMaxBpm {
    final rawMin = _prefs.getInt(_keyRangeAlertMinBpm) ?? 110;
    final rawMax = _prefs.getInt(_keyRangeAlertMaxBpm) ?? 170;
    return AppUtils.clamp(rawMax, AppUtils.clamp(rawMin + 1, 51, 230), 230);
  }

  set rangeAlertMaxBpm(int value) {
    final nextMax = AppUtils.clamp(value, 51, 230);
    var nextMin = rangeAlertMinBpm;
    if (nextMax <= nextMin) {
      nextMin = AppUtils.clamp(nextMax - 1, 50, 229);
      _prefs.setInt(_keyRangeAlertMinBpm, nextMin);
    }
    _prefs.setInt(_keyRangeAlertMaxBpm, AppUtils.clamp(nextMax, nextMin + 1, 230));
  }

  HrZones get zones => ZonesCalculator.calculate(
        age: age,
        targetZoneMinPercent: targetZoneMinPercent,
        targetZoneMaxPercent: targetZoneMaxPercent,
      );

  Future<void> save() async {
    await _prefs.reload();
  }
}
