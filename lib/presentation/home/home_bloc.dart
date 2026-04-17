import 'dart:async';

import 'package:bloc/bloc.dart';
import 'package:equatable/equatable.dart';
import 'package:flutter/services.dart';
import 'package:uuid/uuid.dart';

import '../../core/constants.dart';
import '../../data/ble/ble_heart_rate_service.dart';
import '../../data/storage/session_storage.dart';
import '../../data/storage/settings_storage.dart';
import '../../data/audio/notification_audio_service.dart';
import '../../domain/models/hr_reading.dart';
import '../../domain/models/hr_session.dart';
import '../../domain/models/hr_zones.dart';
import '../../domain/models/metronome_preset.dart';

part 'home_event.dart';
part 'home_state.dart';

class HomeBloc extends Bloc<HomeEvent, HomeState> {
  static const int _phaseTickBpm = 60;
  static const Duration _chartRetentionWindow = Duration(minutes: 30);

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
          metronomeBpm: settingsStorage.metronomeBpm,
          metronomePresets: settingsStorage.metronomePresets,
          selectedMetronomePresetId: settingsStorage.metronomePresets.isNotEmpty
              ? settingsStorage.metronomePresets.first.id
              : null,
          metronomeVibrationEnabled: settingsStorage.metronomeVibrationEnabled,
          metronomeVoiceCuesEnabled: settingsStorage.metronomeVoiceCuesEnabled,
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
    on<HomeSaveHistoryRequested>(_onSaveHistoryRequested);
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
    on<HomeAppPausedCheckpointRequested>(_onAppPausedCheckpointRequested);
    on<HomeMetronomeBpmChanged>(_onMetronomeBpmChanged);
    on<HomeMetronomePresetSelected>(_onMetronomePresetSelected);
    on<HomeMetronomePresetSaved>(_onMetronomePresetSaved);
    on<HomeMetronomePresetDeleted>(_onMetronomePresetDeleted);
    on<HomeMetronomeSessionStarted>(_onMetronomeSessionStarted);
    on<HomeMetronomeSessionPauseToggled>(_onMetronomeSessionPauseToggled);
    on<HomeMetronomeSessionStopped>(_onMetronomeSessionStopped);
    on<HomeMetronomePhaseTicked>(_onMetronomePhaseTicked);

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
  final List<HrReading> _recentReadings = [];
  Timer? _timerTicker;
  Timer? _dataWatchdogTimer;
  Timer? _reconnectAttemptTimer;
  Timer? _reconnectSaveTimer;
  Timer? _reconnectGiveUpTimer;
  Timer? _metronomePhaseTimer;
  DateTime? _metronomePhaseEndsAt;
  bool _metronomePhaseSwitchInFlight = false;
  MetronomePreset? _activeMetronomePreset;
  MetronomePhase _activeMetronomePhase = MetronomePhase.finished;
  int _activeMetronomeCycles = 0;
  bool _manualDisconnectRequested = false;
  DateTime? _connectionGapStartedAt;
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
    if (state.isMetronomeRunning) {
      await _audioService.stopMetronome();
    }
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
      isMetronomeRunning: false,
      isMetronomeSessionRunning: false,
      isMetronomeSessionPaused: false,
      metronomePhase: MetronomePhase.finished,
      metronomePhaseRemainingSec: 0,
    ));
  }

  Future<void> _onTestRequested(
    HomeTestRequested event,
    Emitter<HomeState> emit,
  ) async {
    if (state.isTestMode) {
      if (state.isMetronomeRunning) {
        await _audioService.stopMetronome();
      }
      _manualDisconnectRequested = true;
      _cancelReconnectFlow();
      _lastHeartRateAt = null;
      await _bleService.disconnect();
      emit(state.copyWith(
        bleStatus: BleConnectionStatus.disconnected,
        isTestMode: false,
        shouldForceCloseApp: false,
        isMetronomeRunning: false,
        isMetronomeSessionRunning: false,
        isMetronomeSessionPaused: false,
        metronomePhase: MetronomePhase.finished,
        metronomePhaseRemainingSec: 0,
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
      final finishedGap = _finishConnectionGapIfAny();
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
        lastConnectionGapSeconds: finishedGap?.durationSeconds,
        connectionGaps: _trimConnectionGaps(state.connectionGaps, finishedGap),
        activeConnectionGapStartedAt: null,
      ));
      return;
    }

    final isManualDisconnect = _manualDisconnectRequested;
    if (isManualDisconnect &&
        (nextStatus == BleConnectionStatus.disconnected ||
            nextStatus == BleConnectionStatus.error)) {
      _manualDisconnectRequested = false;
      _connectionGapStartedAt = null;
      _cancelReconnectFlow();
      if (state.isRecording) {
        add(const HomeStopRecording());
      }
      emit(state.copyWith(
        bleStatus: nextStatus,
        isTestMode: false,
        shouldForceCloseApp: false,
        activeConnectionGapStartedAt: null,
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
      _markConnectionGapStarted();
      _startReconnectFlow();
    }

    emit(state.copyWith(
      bleStatus: nextStatus,
      isTestMode: nextStatus == BleConnectionStatus.disconnected
          ? false
          : state.isTestMode,
      activeConnectionGapStartedAt: _connectionGapStartedAt,
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

    HrSession? session = state.session;
    if (session != null && state.isRecording) {
      _sessionReadings.add(reading);
      session =
          session.copyWith(readings: List<HrReading>.from(_sessionReadings));
    }

    _recentReadings
      ..add(reading)
      ..removeWhere(
        (r) => DateTime.now().difference(r.timestamp) > _chartRetentionWindow,
      );
    final sourceForChart = List<HrReading>.from(_recentReadings);
    final lightweightChartReadings = _buildChartReadings(
      source: sourceForChart,
      chartMinutes: state.chartWindowMinutes,
    );

    // Оповещения
    _audioService.soundEnabled = _settingsStorage.soundEnabled;
    _audioService.ttsEnabled = _settingsStorage.ttsEnabled;
    _audioService.setTtsLanguage(_settingsStorage.ttsLanguage);
    final rangeMode = _settingsStorage.hrRangeMode;
    final useManualRange = rangeMode == 'manual';
    final useBeep = useManualRange
        ? _settingsStorage.manualRangeBeepEnabled
        : _settingsStorage.zoneRangeBeepEnabled;
    final useVoice = useManualRange
        ? _settingsStorage.manualRangeVoiceEnabled
        : _settingsStorage.zoneRangeVoiceEnabled;
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
      useBeep: useBeep,
      useVoice: useVoice,
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

  Future<void> _onSaveHistoryRequested(
    HomeSaveHistoryRequested event,
    Emitter<HomeState> emit,
  ) async {
    await _saveSegmentAndContinue(emit);
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
    final nextChartWindowMinutes = _settingsStorage.chartWindowMinutes;
    final chartSource = List<HrReading>.from(_recentReadings);
    final recalculatedReadings = _buildChartReadings(
      source: chartSource,
      chartMinutes: nextChartWindowMinutes,
    );
    final nextMetronomeEnabled = _settingsStorage.enableMetronome;
    final nextMetronomeBpm = _settingsStorage.metronomeBpm;
    final nextMetronomePresets = _settingsStorage.metronomePresets;
    final nextMetronomeVibration = _settingsStorage.metronomeVibrationEnabled;
    final nextMetronomeVoiceCues = _settingsStorage.metronomeVoiceCuesEnabled;
    if (!nextMetronomeEnabled && state.isMetronomeSessionRunning) {
      unawaited(_stopMetronomeSessionInternal(emit));
    }
    if (state.isMetronomeRunning &&
        nextMetronomeBpm != state.metronomeBpm) {
      unawaited(_audioService.updateMetronomeBpm(bpm: nextMetronomeBpm));
    }
    final nextSelected = nextMetronomePresets.any(
      (p) => p.id == state.selectedMetronomePresetId,
    )
        ? state.selectedMetronomePresetId
        : (nextMetronomePresets.isNotEmpty ? nextMetronomePresets.first.id : null);
    emit(state.copyWith(
      zones: _settingsStorage.zones,
      chartWindowMinutes: nextChartWindowMinutes,
      readings: recalculatedReadings,
      timerMode: _timerModeFromSettings(_settingsStorage.timerMode),
      timerDurationSeconds: _settingsStorage.timerDurationSeconds,
      timerRemainingSeconds: state.isTimerRunning
          ? state.timerRemainingSeconds
          : _settingsStorage.timerDurationSeconds,
      settingsVersion: state.settingsVersion + 1,
      metronomeBpm: nextMetronomeBpm,
      metronomePresets: nextMetronomePresets,
      selectedMetronomePresetId: nextSelected,
      metronomeVibrationEnabled: nextMetronomeVibration,
      metronomeVoiceCuesEnabled: nextMetronomeVoiceCues,
      isMetronomeRunning: state.isMetronomeRunning,
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
    final success = await _persistCurrentSession(emit, suggestCleanup: false);
    if (success) {
      _reconnectSaveDone = true;
    }
  }

  Future<void> _onReconnectGiveUpReached(
    HomeReconnectGiveUpReached event,
    Emitter<HomeState> emit,
  ) async {
    if (!_reconnectFlowActive ||
        state.bleStatus == BleConnectionStatus.connected ||
        _manualDisconnectRequested) {
      return;
    }
    _cancelReconnectFlow();

    // Последняя попытка сохранения перед принудительным завершением.
    // Если сохранение не удалось, не закрываем процесс, чтобы данные остались в RAM.
    final success = await _persistCurrentSession(emit, suggestCleanup: false);
    if (!success && _sessionReadings.isNotEmpty) {
      emit(state.copyWith(
        shouldForceCloseApp: false,
        bleStatus: BleConnectionStatus.error,
        isTestMode: false,
      ));
      return;
    }

    emit(state.copyWith(
      shouldForceCloseApp: false,
      errorMessage:
          'Connection lost and could not be restored within 5 minutes.',
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

  Future<void> _onAppPausedCheckpointRequested(
    HomeAppPausedCheckpointRequested event,
    Emitter<HomeState> emit,
  ) async {
    if (!state.isRecording ||
        state.bleStatus != BleConnectionStatus.connected ||
        _sessionReadings.isEmpty) {
      return;
    }
    await _saveSegmentAndContinue(emit);
  }

  Future<void> _onMetronomeBpmChanged(
    HomeMetronomeBpmChanged event,
    Emitter<HomeState> emit,
  ) async {
    final nextBpm = event.bpm.clamp(40, 220);
    _settingsStorage.metronomeBpm = nextBpm;
    if (state.isMetronomeRunning) {
      await _audioService.updateMetronomeBpm(bpm: nextBpm);
    }
    emit(state.copyWith(metronomeBpm: nextBpm));
  }

  void _onMetronomePresetSelected(
    HomeMetronomePresetSelected event,
    Emitter<HomeState> emit,
  ) {
    emit(state.copyWith(selectedMetronomePresetId: event.presetId));
  }

  Future<void> _onMetronomePresetSaved(
    HomeMetronomePresetSaved event,
    Emitter<HomeState> emit,
  ) async {
    final current = List<MetronomePreset>.from(state.metronomePresets);
    final index = current.indexWhere((p) => p.id == event.preset.id);
    if (index == -1) {
      current.add(event.preset);
    } else {
      current[index] = event.preset;
    }
    _settingsStorage.metronomePresets = current;
    emit(state.copyWith(
      metronomePresets: current,
      selectedMetronomePresetId: event.preset.id,
    ));
  }

  Future<void> _onMetronomePresetDeleted(
    HomeMetronomePresetDeleted event,
    Emitter<HomeState> emit,
  ) async {
    final current = List<MetronomePreset>.from(state.metronomePresets)
      ..removeWhere((p) => p.id == event.presetId);
    _settingsStorage.metronomePresets = current;
    final nextSelected = current.isNotEmpty ? current.first.id : null;
    if (state.isMetronomeSessionRunning &&
        state.selectedMetronomePresetId == event.presetId) {
      await _stopMetronomeSessionInternal(emit);
    }
    emit(state.copyWith(
      metronomePresets: current,
      selectedMetronomePresetId: nextSelected,
    ));
  }

  Future<void> _onMetronomeSessionStarted(
    HomeMetronomeSessionStarted event,
    Emitter<HomeState> emit,
  ) async {
    if (!_settingsStorage.enableMetronome) {
      return;
    }
    final preset = _selectedPreset();
    if (preset == null) {
      return;
    }
    await _startMetronomeSessionInternal(emit, preset);
  }

  Future<void> _onMetronomeSessionPauseToggled(
    HomeMetronomeSessionPauseToggled event,
    Emitter<HomeState> emit,
  ) async {
    if (!state.isMetronomeSessionRunning) {
      return;
    }
    final nextPaused = !state.isMetronomeSessionPaused;
    if (nextPaused) {
      await _audioService.stopMetronome();
    } else {
      await _audioService.startMetronome(
        bpm: _phaseTickBpm,
        playImmediateTick: false,
      );
    }
    emit(state.copyWith(isMetronomeSessionPaused: nextPaused));
  }

  Future<void> _onMetronomeSessionStopped(
    HomeMetronomeSessionStopped event,
    Emitter<HomeState> emit,
  ) async {
    await _stopMetronomeSessionInternal(emit);
  }

  Future<void> _onMetronomePhaseTicked(
    HomeMetronomePhaseTicked event,
    Emitter<HomeState> emit,
  ) async {
    if (!state.isMetronomeSessionRunning) return;
    final endsAt = _metronomePhaseEndsAt;
    final preset = _activeMetronomePreset;
    if (endsAt == null || preset == null) return;

    if (state.isMetronomeSessionPaused) {
      _metronomePhaseEndsAt =
          _metronomePhaseEndsAt?.add(const Duration(seconds: 1));
      return;
    }

    final remaining = endsAt.difference(DateTime.now()).inSeconds;
    if (remaining <= 0) {
      if (_metronomePhaseSwitchInFlight) {
        return;
      }
      final next = _nextPhase(preset, _activeMetronomePhase, _activeMetronomeCycles);
      _metronomePhaseSwitchInFlight = true;
      try {
        await _switchToPhase(emit, preset, next.$1, next.$2);
      } finally {
        _metronomePhaseSwitchInFlight = false;
      }
      return;
    }

    emit(state.copyWith(
      metronomePhase: _activeMetronomePhase,
      metronomePhaseRemainingSec: remaining,
      metronomeCompletedCycles: _activeMetronomeCycles,
      isMetronomeRunning: true,
    ));
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

    _markConnectionGapStarted();
    _startReconnectFlow(
      saveDelay: Duration.zero,
      giveUpDelay: const Duration(minutes: 5),
    );
    emit(state.copyWith(
      bleStatus: BleConnectionStatus.error,
      errorMessage: 'Heart rate signal lost. Reconnecting...',
      activeConnectionGapStartedAt: _connectionGapStartedAt,
    ));
  }

  void _startReconnectFlow({
    Duration saveDelay = const Duration(seconds: 5),
    Duration giveUpDelay = const Duration(minutes: 5),
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

  void _markConnectionGapStarted() {
    _connectionGapStartedAt ??= DateTime.now();
  }

  ConnectionGap? _finishConnectionGapIfAny() {
    final startedAt = _connectionGapStartedAt;
    if (startedAt == null) {
      return null;
    }
    _connectionGapStartedAt = null;
    final endedAt = DateTime.now();
    if (!endedAt.isAfter(startedAt)) {
      return null;
    }
    return ConnectionGap(startedAt: startedAt, endedAt: endedAt);
  }

  List<ConnectionGap> _trimConnectionGaps(
    List<ConnectionGap> current,
    ConnectionGap? appended,
  ) {
    final next = List<ConnectionGap>.from(current);
    if (appended != null) {
      next.add(appended);
    }
    final cutoff = DateTime.now().subtract(_chartRetentionWindow);
    next.removeWhere((gap) => gap.endedAt.isBefore(cutoff));
    return next;
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

  Future<bool> _persistCurrentSession(
    Emitter<HomeState> emit, {
    required bool suggestCleanup,
  }) async {
    final sessionBase = state.session;
    if (sessionBase == null || _sessionReadings.isEmpty) {
      emit(state.copyWith(
        isRecording: false,
        session: null,
        shouldShowCleanupDialog: false,
        errorMessage: null,
      ));
      _sessionReadings.clear();
      return false;
    }

    final currentSession = sessionBase.copyWith(
      endedAt: DateTime.now(),
      readings: List<HrReading>.from(_sessionReadings),
    );

    try {
      await _sessionStorage.saveSession(currentSession);
    } catch (e) {
      emit(state.copyWith(
        errorMessage: 'Failed to save session: $e',
      ));
      return false;
    }

    final shouldSuggestCleanup = suggestCleanup
        ? await _sessionStorage.shouldSuggestCleanup()
        : false;
    emit(state.copyWith(
      isRecording: false,
      session: null,
      shouldShowCleanupDialog: shouldSuggestCleanup,
      errorMessage: null,
    ));
    _sessionReadings.clear();
    return true;
  }

  Future<bool> _saveSegmentAndContinue(Emitter<HomeState> emit) async {
    final currentSession = state.session;
    if (!state.isRecording || currentSession == null || _sessionReadings.isEmpty) {
      return false;
    }
    final snapshot = currentSession.copyWith(
      endedAt: DateTime.now(),
      readings: List<HrReading>.from(_sessionReadings),
    );
    try {
      await _sessionStorage.saveSession(snapshot);
    } catch (e) {
      emit(state.copyWith(
        errorMessage: 'Failed to save session: $e',
      ));
      return false;
    }

    final nextSession = HrSession(
      id: const Uuid().v4(),
      startedAt: DateTime.now(),
      zones: _settingsStorage.zones,
      readings: const [],
    );
    _sessionReadings.clear();
    emit(state.copyWith(
      session: nextSession,
      isRecording: true,
      historySaveVersion: state.historySaveVersion + 1,
      errorMessage: null,
    ));
    return true;
  }

  MetronomePreset? _selectedPreset() {
    final selectedId = state.selectedMetronomePresetId;
    if (selectedId == null) return null;
    for (final preset in state.metronomePresets) {
      if (preset.id == selectedId) return preset;
    }
    return null;
  }

  Future<void> _startMetronomeSessionInternal(
    Emitter<HomeState> emit,
    MetronomePreset preset,
  ) async {
    _metronomePhaseSwitchInFlight = false;
    _metronomePhaseTimer?.cancel();
    _metronomePhaseTimer = null;
    _metronomePhaseEndsAt = null;
    emit(state.copyWith(
      isMetronomeSessionRunning: true,
      isMetronomeSessionPaused: false,
      metronomeCompletedCycles: 0,
      metronomeTargetCycles: preset.cycleMode == MetronomeCycleMode.fixed
          ? preset.fixedCycles
          : null,
    ));
    await _switchToPhase(emit, preset, MetronomePhase.countdown, 0);
  }

  Future<void> _stopMetronomeSessionInternal(Emitter<HomeState> emit) async {
    _metronomePhaseSwitchInFlight = false;
    _metronomePhaseTimer?.cancel();
    _metronomePhaseTimer = null;
    _metronomePhaseEndsAt = null;
    _activeMetronomePreset = null;
    _activeMetronomePhase = MetronomePhase.finished;
    _activeMetronomeCycles = 0;
    await _audioService.stopMetronome();
    emit(state.copyWith(
      isMetronomeSessionRunning: false,
      isMetronomeSessionPaused: false,
      isMetronomeRunning: false,
      metronomePhase: MetronomePhase.finished,
      metronomePhaseRemainingSec: 0,
      metronomeCompletedCycles: 0,
      metronomeTargetCycles: null,
    ));
  }

  Future<void> _switchToPhase(
    Emitter<HomeState> emit,
    MetronomePreset preset,
    MetronomePhase targetPhase,
    int cyclesDone,
  ) async {
    var phase = targetPhase;
    var duration = preset.durationForPhase(phase);
    var cycles = cyclesDone;

    while (duration <= 0 && phase != MetronomePhase.finished) {
      final next = _nextPhase(preset, phase, cycles);
      phase = next.$1;
      cycles = next.$2;
      duration = preset.durationForPhase(phase);
    }

    if (phase == MetronomePhase.finished) {
      await _stopMetronomeSessionInternal(emit);
      return;
    }

    await _audioService.stopMetronome();
    await _audioService.playMetronomePhaseChangeCue();

    if (state.metronomeVoiceCuesEnabled) {
      await _audioService.speakMetronomeCue(_phaseCueEn(phase));
    }

    if (state.metronomeVibrationEnabled) {
      HapticFeedback.mediumImpact();
    }

    await _audioService.startMetronome(
      bpm: _phaseTickBpm,
      playImmediateTick: false,
    );
    _activeMetronomePreset = preset;
    _activeMetronomePhase = phase;
    _activeMetronomeCycles = cycles;
    _metronomePhaseEndsAt = DateTime.now().add(Duration(seconds: duration));
    _metronomePhaseTimer?.cancel();
    _metronomePhaseTimer = Timer.periodic(
      const Duration(seconds: 1),
      (_) => add(const HomeMetronomePhaseTicked()),
    );

    emit(state.copyWith(
      metronomePhase: phase,
      metronomePhaseRemainingSec: duration,
      metronomeCompletedCycles: cycles,
      isMetronomeRunning: true,
    ));
  }

  String _phaseCueEn(MetronomePhase phase) {
    switch (phase) {
      case MetronomePhase.countdown:
        return 'Countdown';
      case MetronomePhase.negative:
        return 'Negative';
      case MetronomePhase.pause:
        return 'Pause';
      case MetronomePhase.press:
        return 'Press';
      case MetronomePhase.rest:
        return 'Rest';
      case MetronomePhase.finished:
        return 'Finished';
    }
  }

  (MetronomePhase, int) _nextPhase(
    MetronomePreset preset,
    MetronomePhase phase,
    int cyclesDone,
  ) {
    switch (phase) {
      case MetronomePhase.countdown:
        return (MetronomePhase.negative, cyclesDone);
      case MetronomePhase.negative:
        return (MetronomePhase.pause, cyclesDone);
      case MetronomePhase.pause:
        return (MetronomePhase.press, cyclesDone);
      case MetronomePhase.press:
        return (MetronomePhase.rest, cyclesDone);
      case MetronomePhase.rest:
        final nextCycles = cyclesDone + 1;
        if (preset.cycleMode == MetronomeCycleMode.fixed &&
            nextCycles >= preset.fixedCycles) {
          return (MetronomePhase.finished, nextCycles);
        }
        return (MetronomePhase.negative, nextCycles);
      case MetronomePhase.finished:
        return (MetronomePhase.finished, cyclesDone);
    }
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

  List<HrReading> _buildChartReadings({
    required List<HrReading> source,
    required int chartMinutes,
  }) {
    final effectiveChartMinutes = chartMinutes < 30 ? 30 : chartMinutes;
    final cutoff = DateTime.now().subtract(Duration(minutes: effectiveChartMinutes));
    final chartReadings = source.where((r) => r.timestamp.isAfter(cutoff)).toList();
    const maxPoints = 5000;
    return chartReadings.length <= maxPoints
        ? chartReadings
        : chartReadings.sublist(chartReadings.length - maxPoints);
  }

  @override
  Future<void> close() {
    unawaited(_audioService.stopMetronome());
    _metronomePhaseTimer?.cancel();
    _metronomePhaseTimer = null;
    _metronomePhaseEndsAt = null;
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
