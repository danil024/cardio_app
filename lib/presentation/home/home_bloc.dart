import 'dart:async';

import 'package:bloc/bloc.dart';
import 'package:equatable/equatable.dart';
import 'package:uuid/uuid.dart';

import '../../core/constants.dart';
import '../../data/ble/ble_heart_rate_service.dart';
import '../../data/storage/session_storage.dart';
import '../../data/storage/settings_storage.dart';
import '../../data/audio/notification_audio_service.dart';
import '../../domain/models/hr_reading.dart';
import '../../domain/models/hr_session.dart';
import '../../domain/models/hr_zones.dart';

part 'home_event.dart';
part 'home_state.dart';

class HomeBloc extends Bloc<HomeEvent, HomeState> {
  HomeBloc({
    required BleHeartRateService bleService,
    required SessionStorage sessionStorage,
    required NotificationAudioService audioService,
    required SettingsStorage settingsStorage,
  })  : _bleService = bleService,
        _sessionStorage = sessionStorage,
        _audioService = audioService,
        _settingsStorage = settingsStorage,
        super(HomeState(
          zones: settingsStorage.zones,
          chartWindowMinutes: settingsStorage.chartWindowMinutes,
          timerMode: _timerModeFromSettings(settingsStorage.timerMode),
          timerDurationSeconds: settingsStorage.timerDurationSeconds,
          timerRemainingSeconds: settingsStorage.timerDurationSeconds,
        )) {
    _audioService.setTtsLanguage(settingsStorage.ttsLanguage);
    _bleService.setMockInterval(
      Duration(milliseconds: settingsStorage.sensorPollIntervalMs),
    );
    on<HomeConnectRequested>(_onConnectRequested);
    on<HomeDisconnectRequested>(_onDisconnectRequested);
    on<HomeTestRequested>(_onTestRequested);
    on<HomeHeartRateReceived>(_onHeartRateReceived);
    on<HomeStartRecording>(_onStartRecording);
    on<HomeStopRecording>(_onStopRecording);
    on<HomeBleStatusChanged>(_onBleStatusChanged);
    on<HomeOpenSettings>(_onOpenSettings);
    on<HomeRefreshSettings>(_onRefreshSettings);
    on<HomeDismissCleanupDialog>(_onDismissCleanupDialog);
    on<HomeClearOldSessions>(_onClearOldSessions);
    on<HomeCheckStorageRequested>(_onCheckStorageRequested);
    on<HomeTimerModeChanged>(_onTimerModeChanged);
    on<HomeTimerPresetSelected>(_onTimerPresetSelected);
    on<HomeTimerCustomSet>(_onTimerCustomSet);
    on<HomeTimerStartPauseToggled>(_onTimerStartPauseToggled);
    on<HomeTimerReset>(_onTimerReset);
    on<HomeTimerTicked>(_onTimerTicked);

    _bleStatusSub = _bleService.statusStream.listen((s) {
      add(HomeBleStatusChanged(s));
    });
    _hrSub = _bleService.heartRateStream.listen((r) {
      add(HomeHeartRateReceived(r));
    });
  }

  final BleHeartRateService _bleService;
  final SessionStorage _sessionStorage;
  final NotificationAudioService _audioService;
  final SettingsStorage _settingsStorage;

  StreamSubscription<BleConnectionStatus>? _bleStatusSub;
  StreamSubscription<HrReading>? _hrSub;
  final List<HrReading> _sessionReadings = [];
  Timer? _timerTicker;

  static WorkoutTimerMode _timerModeFromSettings(String mode) {
    return mode == 'stopwatch'
        ? WorkoutTimerMode.stopwatch
        : WorkoutTimerMode.timer;
  }

  Future<void> _onConnectRequested(
    HomeConnectRequested event,
    Emitter<HomeState> emit,
  ) async {
    if (state.bleStatus == BleConnectionStatus.connected) return;

    emit(state.copyWith(
      bleStatus: BleConnectionStatus.scanning,
      isTestMode: false,
    ));

    try {
      await _bleService.connect();
    } catch (e) {
      emit(state.copyWith(
        bleStatus: BleConnectionStatus.error,
        errorMessage: e.toString(),
      ));
    }
  }

  Future<void> _onDisconnectRequested(
    HomeDisconnectRequested event,
    Emitter<HomeState> emit,
  ) async {
    await _bleService.disconnect();
    await _audioService.updateZoneState(
      inDanger: false,
      inCustomEmergency: false,
      aboveTarget: false,
      belowTarget: false,
    );
    emit(state.copyWith(
      bleStatus: BleConnectionStatus.disconnected,
      isTestMode: false,
    ));
  }

  Future<void> _onTestRequested(
    HomeTestRequested event,
    Emitter<HomeState> emit,
  ) async {
    if (state.isTestMode) {
      await _bleService.disconnect();
      emit(state.copyWith(
        bleStatus: BleConnectionStatus.disconnected,
        isTestMode: false,
      ));
      return;
    }
    _bleService.setMockInterval(
      Duration(milliseconds: _settingsStorage.sensorPollIntervalMs),
    );
    await _bleService.startMockMode();
    emit(state.copyWith(
      isTestMode: true,
      errorMessage: null,
    ));
  }

  void _onBleStatusChanged(
      HomeBleStatusChanged event, Emitter<HomeState> emit) {
    if (event.status == BleConnectionStatus.connected && !state.isRecording) {
      add(const HomeStartRecording());
    }
    if (event.status == BleConnectionStatus.disconnected && state.isRecording) {
      add(const HomeStopRecording());
    }
    emit(state.copyWith(
      bleStatus: event.status,
      isTestMode: event.status == BleConnectionStatus.disconnected
          ? false
          : state.isTestMode,
    ));
  }

  void _onHeartRateReceived(
      HomeHeartRateReceived event, Emitter<HomeState> emit) {
    final zones = _settingsStorage.zones;
    final reading = event.reading;

    final newReadings = List<HrReading>.from(state.readings)..add(reading);

    HrSession? session = state.session;
    if (session != null && state.isRecording) {
      _sessionReadings.add(reading);
      session =
          session.copyWith(readings: List<HrReading>.from(_sessionReadings));
    }

    // Ограничиваем readings для графика (последние N минут)
    final chartMinutes = _settingsStorage.chartWindowMinutes;
    final cutoff = DateTime.now().subtract(
      Duration(minutes: chartMinutes),
    );
    final chartReadings =
        newReadings.where((r) => r.timestamp.isAfter(cutoff)).toList();
    final pollMs = _settingsStorage.sensorPollIntervalMs;
    final expectedPoints = ((chartMinutes * 60 * 1000) / pollMs).ceil() + 20;
    final maxPoints = expectedPoints.clamp(120, 4000);
    final lightweightChartReadings = chartReadings.length <= maxPoints
        ? chartReadings
        : chartReadings.sublist(chartReadings.length - maxPoints);

    // Оповещения
    _audioService.soundEnabled = _settingsStorage.soundEnabled;
    _audioService.ttsEnabled = _settingsStorage.ttsEnabled;
    _audioService.setTtsLanguage(_settingsStorage.ttsLanguage);
    final useRangeAlert = _settingsStorage.enableRangeAlert;
    final rangeMin = _settingsStorage.rangeAlertMinBpm;
    final rangeMax = _settingsStorage.rangeAlertMaxBpm;
    final aboveGuidance =
        useRangeAlert ? reading.heartRate > rangeMax : zones.isAboveTarget(reading.heartRate);
    final belowGuidance =
        useRangeAlert ? reading.heartRate < rangeMin : zones.isBelowTarget(reading.heartRate);
    _audioService.updateZoneState(
      inDanger: zones.isInDangerZone(reading.heartRate),
      inCustomEmergency: false,
      aboveTarget: aboveGuidance,
      belowTarget: belowGuidance,
    );

    emit(state.copyWith(
      currentHeartRate: reading.heartRate,
      readings: lightweightChartReadings,
      session: session ?? state.session,
      zones: zones,
    ));
  }

  Future<void> _onStartRecording(
    HomeStartRecording event,
    Emitter<HomeState> emit,
  ) async {
    final zones = _settingsStorage.zones;
    final session = HrSession(
      id: const Uuid().v4(),
      startedAt: DateTime.now(),
      zones: zones,
      readings: const [],
    );
    _sessionReadings.clear();

    emit(state.copyWith(
      isRecording: true,
      session: session,
      readings: const [], // Начинаем новую запись
    ));
  }

  Future<void> _onStopRecording(
    HomeStopRecording event,
    Emitter<HomeState> emit,
  ) async {
    final session = state.session?.copyWith(endedAt: DateTime.now());
    if (session != null && session.readings.isNotEmpty) {
      await _sessionStorage.saveSession(session);
      final suggestCleanup = await _sessionStorage.shouldSuggestCleanup();
      emit(state.copyWith(
        isRecording: false,
        session: null,
        shouldShowCleanupDialog: suggestCleanup,
      ));
    } else {
      emit(state.copyWith(
        isRecording: false,
        session: null,
      ));
    }
    _sessionReadings.clear();
  }

  void _onDismissCleanupDialog(
      HomeDismissCleanupDialog event, Emitter<HomeState> emit) {
    emit(state.copyWith(shouldShowCleanupDialog: false));
  }

  Future<void> _onClearOldSessions(
      HomeClearOldSessions event, Emitter<HomeState> emit) async {
    await _sessionStorage.clearOldSessions();
    emit(state.copyWith(shouldShowCleanupDialog: false));
  }

  Future<void> _onCheckStorageRequested(
    HomeCheckStorageRequested event,
    Emitter<HomeState> emit,
  ) async {
    final suggest = await _sessionStorage.shouldSuggestCleanup();
    if (suggest) {
      emit(state.copyWith(shouldShowCleanupDialog: true));
    }
  }

  void _onOpenSettings(HomeOpenSettings event, Emitter<HomeState> emit) {
    // Навигация обрабатывается в UI
  }

  void _onRefreshSettings(HomeRefreshSettings event, Emitter<HomeState> emit) {
    _bleService.setMockInterval(
      Duration(milliseconds: _settingsStorage.sensorPollIntervalMs),
    );
    _audioService.setTtsLanguage(_settingsStorage.ttsLanguage);
    emit(state.copyWith(
      zones: _settingsStorage.zones,
      chartWindowMinutes: _settingsStorage.chartWindowMinutes,
      timerMode: _timerModeFromSettings(_settingsStorage.timerMode),
      timerDurationSeconds: _settingsStorage.timerDurationSeconds,
      timerRemainingSeconds: state.isTimerRunning
          ? state.timerRemainingSeconds
          : _settingsStorage.timerDurationSeconds,
      settingsVersion: state.settingsVersion + 1,
    ));
  }

  void _onTimerModeChanged(
    HomeTimerModeChanged event,
    Emitter<HomeState> emit,
  ) {
    _settingsStorage.timerMode =
        event.mode == WorkoutTimerMode.timer ? 'timer' : 'stopwatch';
    _stopTimerTicker();
    emit(state.copyWith(
      timerMode: event.mode,
      isTimerRunning: false,
      timerElapsedSeconds: 0,
      timerRemainingSeconds:
          event.mode == WorkoutTimerMode.timer ? state.timerDurationSeconds : 0,
      timerStartedAt: null,
    ));
  }

  void _onTimerPresetSelected(
    HomeTimerPresetSelected event,
    Emitter<HomeState> emit,
  ) {
    final durationSeconds = (event.minutes * 60).clamp(10, 24 * 3600);
    _settingsStorage.timerDurationSeconds = durationSeconds;
    _stopTimerTicker();
    emit(state.copyWith(
      timerDurationSeconds: durationSeconds,
      timerRemainingSeconds: durationSeconds,
      timerElapsedSeconds: 0,
      isTimerRunning: false,
      timerStartedAt: null,
    ));
  }

  void _onTimerCustomSet(
    HomeTimerCustomSet event,
    Emitter<HomeState> emit,
  ) {
    final durationSeconds = event.seconds.clamp(10, 24 * 3600);
    _settingsStorage.timerDurationSeconds = durationSeconds;
    _stopTimerTicker();
    emit(state.copyWith(
      timerDurationSeconds: durationSeconds,
      timerRemainingSeconds: durationSeconds,
      timerElapsedSeconds: 0,
      isTimerRunning: false,
      timerStartedAt: null,
    ));
  }

  void _onTimerStartPauseToggled(
    HomeTimerStartPauseToggled event,
    Emitter<HomeState> emit,
  ) {
    if (state.isTimerRunning) {
      _stopTimerTicker();
      emit(state.copyWith(
        isTimerRunning: false,
        timerElapsedSeconds: 0,
        timerRemainingSeconds: state.timerDurationSeconds,
        timerStartedAt: null,
      ));
      return;
    }
    _startTimerTicker();
    emit(state.copyWith(
      isTimerRunning: true,
      timerStartedAt: state.timerStartedAt ?? DateTime.now(),
    ));
  }

  void _onTimerReset(
    HomeTimerReset event,
    Emitter<HomeState> emit,
  ) {
    _stopTimerTicker();
    emit(state.copyWith(
      isTimerRunning: false,
      timerElapsedSeconds: 0,
      timerRemainingSeconds: state.timerDurationSeconds,
      timerStartedAt: null,
    ));
  }

  Future<void> _onTimerTicked(
    HomeTimerTicked event,
    Emitter<HomeState> emit,
  ) async {
    if (!state.isTimerRunning) return;
    if (state.timerMode == WorkoutTimerMode.stopwatch) {
      emit(state.copyWith(timerElapsedSeconds: state.timerElapsedSeconds + 1));
      return;
    }
    if (state.timerRemainingSeconds <= 0) {
      _stopTimerTicker();
      emit(state.copyWith(isTimerRunning: false));
      return;
    }
    final nextRemaining = state.timerRemainingSeconds - 1;
    if (nextRemaining <= 0) {
      _stopTimerTicker();
      emit(state.copyWith(
        timerRemainingSeconds: state.timerDurationSeconds,
        timerElapsedSeconds: 0,
        isTimerRunning: false,
        timerStartedAt: null,
      ));
      await _audioService.notifyTimerFinished(useVoice: true);
      return;
    }
    emit(state.copyWith(
      timerRemainingSeconds: nextRemaining,
      timerElapsedSeconds: state.timerElapsedSeconds + 1,
      isTimerRunning: true,
    ));
  }

  void _startTimerTicker() {
    _stopTimerTicker();
    _timerTicker = Timer.periodic(const Duration(seconds: 1), (_) {
      add(const HomeTimerTicked());
    });
  }

  void _stopTimerTicker() {
    _timerTicker?.cancel();
    _timerTicker = null;
  }

  @override
  Future<void> close() {
    _stopTimerTicker();
    _bleStatusSub?.cancel();
    _hrSub?.cancel();
    _bleService.dispose();
    _audioService.dispose();
    return super.close();
  }
}
