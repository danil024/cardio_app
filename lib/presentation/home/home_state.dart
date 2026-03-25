part of 'home_bloc.dart';

enum HomeStatus { initial, connected, recording }

enum WorkoutTimerMode { timer, stopwatch }

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
      ];
}
