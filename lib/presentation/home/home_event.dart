part of 'home_bloc.dart';

abstract class HomeEvent extends Equatable {
  const HomeEvent();

  @override
  List<Object?> get props => [];
}

class HomeConnectRequested extends HomeEvent {
  const HomeConnectRequested();
}

class HomeDisconnectRequested extends HomeEvent {
  const HomeDisconnectRequested();
}

class HomeTestRequested extends HomeEvent {
  const HomeTestRequested();
}

class HomeHeartRateReceived extends HomeEvent {
  const HomeHeartRateReceived(this.reading);

  final HrReading reading;

  @override
  List<Object?> get props => [reading];
}

class HomeStartRecording extends HomeEvent {
  const HomeStartRecording();
}

class HomeStopRecording extends HomeEvent {
  const HomeStopRecording();
}

class HomeBleStatusChanged extends HomeEvent {
  const HomeBleStatusChanged(this.status);

  final BleConnectionStatus status;

  @override
  List<Object?> get props => [status];
}

class HomeOpenSettings extends HomeEvent {
  const HomeOpenSettings();
}

class HomeRefreshSettings extends HomeEvent {
  const HomeRefreshSettings();
}

class HomeDismissCleanupDialog extends HomeEvent {
  const HomeDismissCleanupDialog();
}

class HomeClearOldSessions extends HomeEvent {
  const HomeClearOldSessions();
}

class HomeCheckStorageRequested extends HomeEvent {
  const HomeCheckStorageRequested();
}

class HomeTimerModeChanged extends HomeEvent {
  const HomeTimerModeChanged(this.mode);

  final WorkoutTimerMode mode;

  @override
  List<Object?> get props => [mode];
}

class HomeTimerPresetSelected extends HomeEvent {
  const HomeTimerPresetSelected(this.minutes);

  final int minutes;

  @override
  List<Object?> get props => [minutes];
}

class HomeTimerCustomSet extends HomeEvent {
  const HomeTimerCustomSet(this.seconds);

  final int seconds;

  @override
  List<Object?> get props => [seconds];
}

class HomeTimerStartPauseToggled extends HomeEvent {
  const HomeTimerStartPauseToggled();
}

class HomeTimerReset extends HomeEvent {
  const HomeTimerReset();
}

class HomeTimerTicked extends HomeEvent {
  const HomeTimerTicked();
}

class HomeReconnectAttemptRequested extends HomeEvent {
  const HomeReconnectAttemptRequested();
}

class HomeReconnectSaveCheckpointReached extends HomeEvent {
  const HomeReconnectSaveCheckpointReached();
}

class HomeReconnectGiveUpReached extends HomeEvent {
  const HomeReconnectGiveUpReached();
}

class HomeForceCloseHandled extends HomeEvent {
  const HomeForceCloseHandled();
}

class HomeDataWatchdogTicked extends HomeEvent {
  const HomeDataWatchdogTicked();
}
