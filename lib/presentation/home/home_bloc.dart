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
    on<HomeReconnectAttemptRequested>(_onReconnectAttemptRequested);
    on<HomeReconnectSaveCheckpointReached>(_onReconnectSaveCheckpointReached);
    on<HomeReconnectGiveUpReached>(_onReconnectGiveUpReached);
    on<HomeForceCloseHandled>(_onForceCloseHandled);
    on<HomeDataWatchdogTicked>(_onDataWatchdogTicked);

    _bleStatusSub = _bleService.statusStream.listen((s) {
      add(HomeBleStatusChanged(s));
    });
    _hrSub = _bleService.heartRateStream.listen((r) {
      add(HomeHeartRateReceived(r));
    });
    _startDataWatchdog();
  }

  final BleHeartRateService _bleService;
  final SessionStorage _sessionStorage;
  final NotificationAudioService _audioService;
  final SettingsStorage _settingsStorage;

  StreamSubscription<BleConnectionStatus>? _bleStatusSub;
  StreamSubscription<HrReading>? _hrSub;
  final List<HrReading> _sessionReadings = [];
  Timer? _timerTicker;
  Timer? _dataWatchdogTimer;
  Timer? _reconnectAttemptTimer;
  Timer? _reconnectSaveTimer;
  Timer? _reconnectGiveUpTimer;
  bool _manualDisconnectRequested = false;
  bool _reconnectFlowActive = false;
  bool _reconnectSaveDone = false;
  bool _reconnectAttemptInFlight = false;
  DateTime? _lastHeartRateAt;

  static const Duration _silentDropThreshold = Duration(seconds: 5);

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
    _manualDisconnectRequested = false;
    _cancelReconnectFlow();
    _lastHeartRateAt = null;

    emit(state.copyWith(
      bleStatus: BleConnectionStatus.scanning,
      isTestMode: false,
      shouldForceCloseApp: false,
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
    _manualDisconnectRequested = true;
    _cancelReconnectFlow();
    _lastHeartRateAt = null;
    await _bleService.disconnect();
    await _audioService.updateZoneState(
      inDanger: false,
      inCustomEmergency: false,
      aboveTarget: false,
      belowTarget: false,
      useBeep: false,
      useVoice: false,
    );
    emit(state.copyWith(
      bleStatus: BleConnectionStatus.disconnected,
      isTestMode: false,
      shouldForceCloseApp: false,
    ));
  }

  Future<void> _onTestRequested(
    HomeTestRequested event,
    Emitter<HomeState> emit,
  ) async {
    if (state.isTestMode) {
      _manualDisconnectRequested = true;
      _cancelReconnectFlow();
      _lastHeartRateAt = null;
      await _bleService.disconnect();
      emit(state.copyWith(
        bleStatus: BleConnectionStatus.disconnected,
        isTestMode: false,
        shouldForceCloseApp: false,
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

  Future<void> _onBleStatusChanged(
      HomeBleStatusChanged event, Emitter<HomeState> emit) async {
    final previousStatus = state.bleStatus;
    final nextStatus = event.status;

    if (nextStatus == BleConnectionStatus.connected) {
      _manualDisconnectRequested = false;
      _cancelReconnectFlow();
      _lastHeartRateAt = DateTime.now();
      if (!state.isRecording) {
        add(const HomeStartRecording());
      }
      emit(state.copyWith(
        bleStatus: nextStatus,
        errorMessage: null,
        shouldForceCloseApp: false,
      ));
      return;
    }

    final isManualDisconnect = _manualDisconnectRequested;
    if (isManualDisconnect &&
        (nextStatus == BleConnectionStatus.disconnected ||
            nextStatus == BleConnectionStatus.error)) {
      _manualDisconnectRequested = false;
      _cancelReconnectFlow();
      if (state.isRecording) {
        add(const HomeStopRecording());
      }
      emit(state.copyWith(
        bleStatus: nextStatus,
        isTestMode: false,
        shouldForceCloseApp: false,
      ));
      _lastHeartRateAt = null;
      return;
    }

    final unexpectedDrop =
        !state.isTestMode &&
        previousStatus == BleConnectionStatus.connected &&
        (nextStatus == BleConnectionStatus.disconnected ||
            nextStatus == BleConnectionStatus.error);
    if (unexpectedDrop) {
      _startReconnectFlow();
    }

    emit(state.copyWith(
      bleStatus: nextStatus,
      isTestMode: nextStatus == BleConnectionStatus.disconnected
          ? false
          : state.isTestMode,
    ));
    if (nextStatus != BleConnectionStatus.connected) {
      _lastHeartRateAt = null;
    }
  }

  void _onHeartRateReceived(
      HomeHeartRateReceived event, Emitter<HomeState> emit) {
    _lastHeartRateAt = DateTime.now();
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
    // Use the in-state value so chart axis and trimmed points
    // always use exactly the same window.
    final chartMinutes = state.chartWindowMinutes;
    final cutoff = DateTime.now().subtract(
      Duration(minutes: chartMinutes),
    );
    final chartReadings =
        newReadings.where((r) => r.timestamp.isAfter(cutoff)).toList();
    // Keep points by time window first. Do not depend on user-selected poll
    // interval here because real BLE sensors may emit at a different rate.
    // A hard cap only protects memory in pathological cases.
    const maxPoints = 5000;
    final lightweightChartReadings = chartReadings.length <= maxPoints
        ? chartReadings
        : chartReadings.sublist(chartReadings.length - maxPoints);

    // Оповещения
    _audioService.soundEnabled = _settingsStorage.soundEnabled;
    _audioService.ttsEnabled = _settingsStorage.ttsEnabled;
    _audioService.setTtsLanguage(_settingsStorage.ttsLanguage);
    final rangeMode = _settingsStorage.hrRangeMode;
    final useManualRange = rangeMode == 'manual';
    final rangeMin = _settingsStorage.rangeAlertMinBpm;
    final rangeMax = _settingsStorage.rangeAlertMaxBpm;
    final aboveGuidance = useManualRange
        ? reading.heartRate > rangeMax
        : zones.isAboveTarget(reading.heartRate);
    final belowGuidance = useManualRange
        ? reading.heartRate < rangeMin
        : zones.isBelowTarget(reading.heartRate);
    _audioService.updateZoneState(
      inDanger: zones.isInDangerZone(reading.heartRate),
      inCustomEmergency: false,
      aboveTarget: aboveGuidance,
      belowTarget: belowGuidance,
      useBeep: _settingsStorage.enableRangeBeep,
      useVoice: _settingsStorage.enableRangeVoice,
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
    await _persistCurrentSession(emit, suggestCleanup: true);
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
      timerEndsAt: null,
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
      timerEndsAt: null,
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
      timerEndsAt: null,
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
        timerEndsAt: null,
      ));
      return;
    }
    final startedAt = DateTime.now();
    final timerEndsAt = state.timerMode == WorkoutTimerMode.timer
        ? startedAt.add(Duration(seconds: state.timerRemainingSeconds))
        : null;
    _startTimerTicker();
    emit(state.copyWith(
      isTimerRunning: true,
      timerStartedAt: startedAt,
      timerEndsAt: timerEndsAt,
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
      timerEndsAt: null,
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
      emit(state.copyWith(
        isTimerRunning: false,
        timerStartedAt: null,
        timerEndsAt: null,
      ));
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
        timerEndsAt: null,
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

  Future<void> _onReconnectAttemptRequested(
    HomeReconnectAttemptRequested event,
    Emitter<HomeState> emit,
  ) async {
    if (!_reconnectFlowActive ||
        _manualDisconnectRequested ||
        state.bleStatus == BleConnectionStatus.connected ||
        state.isTestMode ||
        _reconnectAttemptInFlight) {
      return;
    }
    _reconnectAttemptInFlight = true;
    try {
      await _bleService.reconnectLastKnownDevice(force: true);
    } finally {
      _reconnectAttemptInFlight = false;
    }
  }

  Future<void> _onReconnectSaveCheckpointReached(
    HomeReconnectSaveCheckpointReached event,
    Emitter<HomeState> emit,
  ) async {
    if (!_reconnectFlowActive ||
        _reconnectSaveDone ||
        state.bleStatus == BleConnectionStatus.connected ||
        _manualDisconnectRequested) {
      return;
    }
    _reconnectSaveDone = true;
    await _persistCurrentSession(emit, suggestCleanup: false);
  }

  void _onReconnectGiveUpReached(
    HomeReconnectGiveUpReached event,
    Emitter<HomeState> emit,
  ) {
    if (!_reconnectFlowActive ||
        state.bleStatus == BleConnectionStatus.connected ||
        _manualDisconnectRequested) {
      return;
    }
    _cancelReconnectFlow();
    emit(state.copyWith(
      shouldForceCloseApp: true,
      errorMessage:
          'Connection lost and could not be restored within 25 seconds.',
      bleStatus: BleConnectionStatus.error,
      isTestMode: false,
    ));
  }

  void _onForceCloseHandled(
    HomeForceCloseHandled event,
    Emitter<HomeState> emit,
  ) {
    if (!state.shouldForceCloseApp) {
      return;
    }
    emit(state.copyWith(shouldForceCloseApp: false));
  }

  Future<void> _onDataWatchdogTicked(
    HomeDataWatchdogTicked event,
    Emitter<HomeState> emit,
  ) async {
    if (_reconnectFlowActive ||
        _manualDisconnectRequested ||
        state.isTestMode ||
        state.bleStatus != BleConnectionStatus.connected) {
      return;
    }
    final last = _lastHeartRateAt;
    if (last == null) {
      return;
    }
    if (DateTime.now().difference(last) < _silentDropThreshold) {
      return;
    }

    _startReconnectFlow(
      saveDelay: Duration.zero,
      giveUpDelay: const Duration(seconds: 20),
    );
    emit(state.copyWith(
      bleStatus: BleConnectionStatus.error,
      errorMessage: 'Heart rate signal lost. Reconnecting...',
    ));
  }

  void _startReconnectFlow({
    Duration saveDelay = const Duration(seconds: 5),
    Duration giveUpDelay = const Duration(seconds: 25),
  }) {
    if (_reconnectFlowActive) {
      return;
    }
    _reconnectFlowActive = true;
    _reconnectSaveDone = false;
    _reconnectAttemptInFlight = false;
    add(const HomeReconnectAttemptRequested());
    _reconnectAttemptTimer = Timer.periodic(const Duration(seconds: 2), (_) {
      add(const HomeReconnectAttemptRequested());
    });
    if (saveDelay == Duration.zero) {
      add(const HomeReconnectSaveCheckpointReached());
    } else {
      _reconnectSaveTimer = Timer(saveDelay, () {
        add(const HomeReconnectSaveCheckpointReached());
      });
    }
    _reconnectGiveUpTimer = Timer(giveUpDelay, () {
      add(const HomeReconnectGiveUpReached());
    });
  }

  void _cancelReconnectFlow() {
    _reconnectFlowActive = false;
    _reconnectSaveDone = false;
    _reconnectAttemptInFlight = false;
    _reconnectAttemptTimer?.cancel();
    _reconnectAttemptTimer = null;
    _reconnectSaveTimer?.cancel();
    _reconnectSaveTimer = null;
    _reconnectGiveUpTimer?.cancel();
    _reconnectGiveUpTimer = null;
  }

  Future<void> _persistCurrentSession(
    Emitter<HomeState> emit, {
    required bool suggestCleanup,
  }) async {
    final currentSession = state.session?.copyWith(endedAt: DateTime.now());
    if (currentSession == null || currentSession.readings.isEmpty) {
      emit(state.copyWith(
        isRecording: false,
        session: null,
      ));
      _sessionReadings.clear();
      return;
    }

    await _sessionStorage.saveSession(currentSession);
    final shouldSuggestCleanup = suggestCleanup
        ? await _sessionStorage.shouldSuggestCleanup()
        : false;
    emit(state.copyWith(
      isRecording: false,
      session: null,
      shouldShowCleanupDialog: shouldSuggestCleanup,
    ));
    _sessionReadings.clear();
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

  void _startDataWatchdog() {
    _dataWatchdogTimer?.cancel();
    _dataWatchdogTimer = Timer.periodic(const Duration(seconds: 1), (_) {
      add(const HomeDataWatchdogTicked());
    });
  }

  @override
  Future<void> close() {
    _stopTimerTicker();
    _dataWatchdogTimer?.cancel();
    _dataWatchdogTimer = null;
    _cancelReconnectFlow();
    _bleStatusSub?.cancel();
    _hrSub?.cancel();
    _bleService.dispose();
    _audioService.dispose();
    return super.close();
  }
}
