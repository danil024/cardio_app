part of 'home_bloc.dart';

enum HomeStatus { initial, connected, recording }

enum WorkoutTimerMode { timer, stopwatch }

class ConnectionGap extends Equatable {
  const ConnectionGap({
    required this.startedAt,
    required this.endedAt,
  });

  final DateTime startedAt;
  final DateTime endedAt;

  int get durationSeconds => endedAt.difference(startedAt).inSeconds.clamp(0, 24 * 3600);

  @override
  List<Object?> get props => [startedAt, endedAt];
}

class HomeState extends Equatable {
  static const Object _unset = Object();

  const HomeState({
    this.bleStatus = BleConnectionStatus.disconnected,
    this.currentHeartRate,
    this.readings = const [],
    this.session,
    this.isRecording = false,
    this.isTestMode = false,
    this.zones,
    this.errorMessage,
    this.chartWindowMinutes = AppConstants.defaultChartWindowMinutes,
    this.shouldShowCleanupDialog = false,
    this.settingsVersion = 0,
    this.timerMode = WorkoutTimerMode.timer,
    this.timerDurationSeconds = 60,
    this.timerRemainingSeconds = 60,
    this.timerElapsedSeconds = 0,
    this.isTimerRunning = false,
    this.timerStartedAt,
    this.timerEndsAt,
    this.shouldForceCloseApp = false,
    this.historySaveVersion = 0,
    this.metronomeBpm = 120,
    this.isMetronomeRunning = false,
    this.metronomePresets = const [],
    this.selectedMetronomePresetId,
    this.metronomePhase = MetronomePhase.finished,
    this.metronomePhaseRemainingSec = 0,
    this.metronomeCompletedCycles = 0,
    this.metronomeTargetCycles,
    this.isMetronomeSessionRunning = false,
    this.isMetronomeSessionPaused = false,
    this.metronomeVibrationEnabled = true,
    this.metronomeVoiceCuesEnabled = true,
    this.lastConnectionGapSeconds,
    this.connectionGaps = const [],
    this.activeConnectionGapStartedAt,
  });

  final BleConnectionStatus bleStatus;
  final int? currentHeartRate;
  final List<HrReading> readings;
  final HrSession? session;
  final bool isRecording;
  final bool isTestMode;
  final HrZones? zones;
  final String? errorMessage;
  final int chartWindowMinutes;
  final bool shouldShowCleanupDialog;
  final int settingsVersion;
  final WorkoutTimerMode timerMode;
  final int timerDurationSeconds;
  final int timerRemainingSeconds;
  final int timerElapsedSeconds;
  final bool isTimerRunning;
  final DateTime? timerStartedAt;
  final DateTime? timerEndsAt;
  final bool shouldForceCloseApp;
  final int historySaveVersion;
  final int metronomeBpm;
  final bool isMetronomeRunning;
  final List<MetronomePreset> metronomePresets;
  final String? selectedMetronomePresetId;
  final MetronomePhase metronomePhase;
  final int metronomePhaseRemainingSec;
  final int metronomeCompletedCycles;
  final int? metronomeTargetCycles;
  final bool isMetronomeSessionRunning;
  final bool isMetronomeSessionPaused;
  final bool metronomeVibrationEnabled;
  final bool metronomeVoiceCuesEnabled;
  final int? lastConnectionGapSeconds;
  final List<ConnectionGap> connectionGaps;
  final DateTime? activeConnectionGapStartedAt;

  static const HomeState initial = HomeState();

  HomeState copyWith({
    BleConnectionStatus? bleStatus,
    int? currentHeartRate,
    List<HrReading>? readings,
    HrSession? session,
    bool? isRecording,
    bool? isTestMode,
    HrZones? zones,
    String? errorMessage,
    int? chartWindowMinutes,
    bool? shouldShowCleanupDialog,
    int? settingsVersion,
    WorkoutTimerMode? timerMode,
    int? timerDurationSeconds,
    int? timerRemainingSeconds,
    int? timerElapsedSeconds,
    bool? isTimerRunning,
    Object? timerStartedAt = _unset,
    Object? timerEndsAt = _unset,
    bool? shouldForceCloseApp,
    int? historySaveVersion,
    int? metronomeBpm,
    bool? isMetronomeRunning,
    List<MetronomePreset>? metronomePresets,
    Object? selectedMetronomePresetId = _unset,
    MetronomePhase? metronomePhase,
    int? metronomePhaseRemainingSec,
    int? metronomeCompletedCycles,
    Object? metronomeTargetCycles = _unset,
    bool? isMetronomeSessionRunning,
    bool? isMetronomeSessionPaused,
    bool? metronomeVibrationEnabled,
    bool? metronomeVoiceCuesEnabled,
    Object? lastConnectionGapSeconds = _unset,
    List<ConnectionGap>? connectionGaps,
    Object? activeConnectionGapStartedAt = _unset,
  }) {
    return HomeState(
      bleStatus: bleStatus ?? this.bleStatus,
      currentHeartRate: currentHeartRate ?? this.currentHeartRate,
      readings: readings ?? this.readings,
      session: session ?? this.session,
      isRecording: isRecording ?? this.isRecording,
      isTestMode: isTestMode ?? this.isTestMode,
      zones: zones ?? this.zones,
      errorMessage: errorMessage,
      chartWindowMinutes: chartWindowMinutes ?? this.chartWindowMinutes,
      shouldShowCleanupDialog:
          shouldShowCleanupDialog ?? this.shouldShowCleanupDialog,
      settingsVersion: settingsVersion ?? this.settingsVersion,
      timerMode: timerMode ?? this.timerMode,
      timerDurationSeconds: timerDurationSeconds ?? this.timerDurationSeconds,
      timerRemainingSeconds:
          timerRemainingSeconds ?? this.timerRemainingSeconds,
      timerElapsedSeconds: timerElapsedSeconds ?? this.timerElapsedSeconds,
      isTimerRunning: isTimerRunning ?? this.isTimerRunning,
      timerStartedAt: identical(timerStartedAt, _unset)
          ? this.timerStartedAt
          : timerStartedAt as DateTime?,
      timerEndsAt: identical(timerEndsAt, _unset)
          ? this.timerEndsAt
          : timerEndsAt as DateTime?,
      shouldForceCloseApp: shouldForceCloseApp ?? this.shouldForceCloseApp,
      historySaveVersion: historySaveVersion ?? this.historySaveVersion,
      metronomeBpm: metronomeBpm ?? this.metronomeBpm,
      isMetronomeRunning: isMetronomeRunning ?? this.isMetronomeRunning,
      metronomePresets: metronomePresets ?? this.metronomePresets,
      selectedMetronomePresetId:
          identical(selectedMetronomePresetId, _unset)
              ? this.selectedMetronomePresetId
              : selectedMetronomePresetId as String?,
      metronomePhase: metronomePhase ?? this.metronomePhase,
      metronomePhaseRemainingSec:
          metronomePhaseRemainingSec ?? this.metronomePhaseRemainingSec,
      metronomeCompletedCycles:
          metronomeCompletedCycles ?? this.metronomeCompletedCycles,
      metronomeTargetCycles: identical(metronomeTargetCycles, _unset)
          ? this.metronomeTargetCycles
          : metronomeTargetCycles as int?,
      isMetronomeSessionRunning:
          isMetronomeSessionRunning ?? this.isMetronomeSessionRunning,
      isMetronomeSessionPaused:
          isMetronomeSessionPaused ?? this.isMetronomeSessionPaused,
      metronomeVibrationEnabled:
          metronomeVibrationEnabled ?? this.metronomeVibrationEnabled,
      metronomeVoiceCuesEnabled:
          metronomeVoiceCuesEnabled ?? this.metronomeVoiceCuesEnabled,
      lastConnectionGapSeconds: identical(lastConnectionGapSeconds, _unset)
          ? this.lastConnectionGapSeconds
          : lastConnectionGapSeconds as int?,
      connectionGaps: connectionGaps ?? this.connectionGaps,
      activeConnectionGapStartedAt: identical(activeConnectionGapStartedAt, _unset)
          ? this.activeConnectionGapStartedAt
          : activeConnectionGapStartedAt as DateTime?,
    );
  }

  @override
  List<Object?> get props => [
        bleStatus,
        currentHeartRate,
        readings,
        session,
        isRecording,
        isTestMode,
        zones,
        errorMessage,
        chartWindowMinutes,
        shouldShowCleanupDialog,
        settingsVersion,
        timerMode,
        timerDurationSeconds,
        timerRemainingSeconds,
        timerElapsedSeconds,
        isTimerRunning,
        timerStartedAt,
        timerEndsAt,
        shouldForceCloseApp,
        historySaveVersion,
        metronomeBpm,
        isMetronomeRunning,
        metronomePresets,
        selectedMetronomePresetId,
        metronomePhase,
        metronomePhaseRemainingSec,
        metronomeCompletedCycles,
        metronomeTargetCycles,
        isMetronomeSessionRunning,
        isMetronomeSessionPaused,
        metronomeVibrationEnabled,
        metronomeVoiceCuesEnabled,
        lastConnectionGapSeconds,
        connectionGaps,
        activeConnectionGapStartedAt,
      ];
}
