import 'dart:async';

import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:wakelock_plus/wakelock_plus.dart';

import '../../core/app_strings.dart';
import '../../data/ble/ble_heart_rate_service.dart';
import '../../data/media/media_control_service.dart';
import '../../data/platform/app_control_service.dart';
import '../../data/storage/settings_storage.dart';
import '../../domain/models/hr_zones.dart';
import '../history/history_screen.dart';
import '../settings/settings_screen.dart';
import 'home_bloc.dart';
import 'widgets/hr_chart.dart';
import 'widgets/hr_display.dart';
import 'widgets/zone_indicator.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen>
    with WidgetsBindingObserver {
  static const double _moduleHeight = 80;
  static const double _moduleGap = 8;
  Timer? _clockTicker;
  DateTime _now = DateTime.now();
  bool _pauseCheckpointRequested = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      context.read<HomeBloc>().add(const HomeCheckStorageRequested());
    });
    _clockTicker = Timer.periodic(const Duration(seconds: 1), (_) {
      if (mounted) {
        setState(() {
          _now = DateTime.now();
        });
      }
    });
  }

  @override
  void dispose() {
    _clockTicker?.cancel();
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      _pauseCheckpointRequested = false;
      return;
    }

    final isBackgroundState = state == AppLifecycleState.paused ||
        state == AppLifecycleState.inactive ||
        state == AppLifecycleState.detached;

    if (!isBackgroundState || _pauseCheckpointRequested) {
      return;
    }

    _pauseCheckpointRequested = true;
    if (!context.mounted) return;
    context
        .read<HomeBloc>()
        .add(const HomeAppPausedCheckpointRequested());
  }

  @override
  Widget build(BuildContext context) {
    final settings = context.read<SettingsStorage>();
    final languageCode = settings.uiLanguage;
    return BlocListener<HomeBloc, HomeState>(
      listenWhen: (prev, curr) =>
          prev.bleStatus != curr.bleStatus ||
          prev.settingsVersion != curr.settingsVersion ||
          (curr.shouldShowCleanupDialog && !prev.shouldShowCleanupDialog) ||
          (!prev.shouldForceCloseApp && curr.shouldForceCloseApp),
      listener: (context, state) {
        final keepOn = context.read<SettingsStorage>().keepScreenOn;
        if (state.bleStatus == BleConnectionStatus.connected && keepOn) {
          WakelockPlus.enable();
        } else if (state.bleStatus != BleConnectionStatus.connected) {
          WakelockPlus.disable();
        }
        if (state.shouldShowCleanupDialog) {
          _showCleanupDialog(context, languageCode);
        }
        if (state.shouldForceCloseApp) {
          context.read<HomeBloc>().add(const HomeForceCloseHandled());
          unawaited(context.read<AppControlService>().forceExit());
        }
      },
      child: PopScope(
        canPop: false,
        onPopInvokedWithResult: (didPop, _) {
          if (!didPop) {
            unawaited(context.read<AppControlService>().minimizeApp());
          }
        },
        child: Scaffold(
          body: BlocBuilder<HomeBloc, HomeState>(
          builder: (context, state) {
            return SafeArea(
              child: Column(
                children: [
                  Padding(
                    padding: const EdgeInsets.symmetric(vertical: 8),
                    child: _buildHeader(
                      context,
                      state,
                      languageCode,
                      settings,
                    ),
                  ),
                  Expanded(
                    child: Stack(
                      children: [
                        Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 16),
                          child: HrChart(
                            readings: state.readings,
                            chartWindowMinutes: state.chartWindowMinutes,
                            showTimerMarker: state.isTimerRunning &&
                                state.timerMode == WorkoutTimerMode.timer,
                            timerMarkerTimestamp: state.timerEndsAt,
                          ),
                        ),
                        Positioned.fill(
                          child: Align(
                            alignment: const Alignment(0, 0.52),
                            child: IgnorePointer(
                              child: _buildPulseBlock(state),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                  _buildBottomArea(
                    context: context,
                    state: state,
                    languageCode: languageCode,
                    settings: settings,
                  ),
                ],
              ),
            );
          },
        ),
      ),
      ),
    );
  }

  Widget _buildBottomArea({
    required BuildContext context,
    required HomeState state,
    required String languageCode,
    required SettingsStorage settings,
  }) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(12, 8, 12, 8),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          _buildZoneUnderChart(state),
          const SizedBox(height: _moduleGap),
          _buildBottomPanel(context, state, languageCode, settings),
        ],
      ),
    );
  }

  Widget _buildPulseBlock(HomeState state) {
    final hr = state.currentHeartRate;
    final zones = state.zones;
    final settings = context.read<SettingsStorage>();
    final style = _pulseStyle(hr, zones, settings);
    return HrDisplay(
      heartRate: hr,
      color: style.color,
      useGradient: style.useGradient,
      fontSize: 112,
    );
  }

  Widget _buildZoneUnderChart(HomeState state) {
    final hr = state.currentHeartRate;
    final zones = state.zones;
    if (hr == null || zones == null) return const SizedBox.shrink();
    final settings = context.read<SettingsStorage>();
    final style = _pulseStyle(hr, zones, settings);
    return _buildUnifiedModuleCard(
      height: _moduleHeight,
      child: Center(
        child: ZoneIndicator(
          heartRate: hr,
          zones: zones,
          color: style.color,
          useGradient: style.useGradient,
        ),
      ),
    );
  }

  _PulseStyle _pulseStyle(int? hr, HrZones? zones, SettingsStorage settings) {
    if (hr == null || zones == null) {
      return const _PulseStyle(color: Colors.white);
    }
    if (settings.hrRangeMode == 'manual') {
      final minBpm = settings.rangeAlertMinBpm;
      final maxBpm = settings.rangeAlertMaxBpm;
      if (hr < minBpm) {
        return const _PulseStyle(color: Colors.yellow);
      }
      if (hr > maxBpm) {
        return const _PulseStyle(color: Colors.red);
      }
      return const _PulseStyle(color: Colors.green);
    }
    final below50 = hr < (zones.maxHr * 0.50).round();
    if (below50) {
      return const _PulseStyle(color: Colors.white, useGradient: true);
    }
    if (hr >= (zones.maxHr * 0.90).round()) {
      return const _PulseStyle(color: Colors.red);
    }
    final zone = zones.zoneFor(hr);
    if (zone?.type == HrZoneType.recovery) {
      return const _PulseStyle(color: Colors.blue);
    }
    if (zones.isInTargetZone(hr)) return const _PulseStyle(color: Colors.green);
    if (zones.isAboveTarget(hr)) return const _PulseStyle(color: Colors.orange);
    return const _PulseStyle(color: Colors.yellow);
  }

  void _showCleanupDialog(BuildContext context, String languageCode) {
    showDialog<void>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(
          AppStrings.isRu(languageCode)
              ? 'Много сохранённых сессий'
              : 'Many saved sessions',
        ),
        content: Text(
          AppStrings.isRu(languageCode)
              ? 'Хранилище сессий заполнено. Удалить старые записи, оставив последние 20?'
              : 'Session storage is full. Delete old records and keep the latest 20?',
        ),
        actions: [
          TextButton(
            onPressed: () {
              context.read<HomeBloc>().add(const HomeDismissCleanupDialog());
              Navigator.pop(ctx);
            },
            child: Text(AppStrings.isRu(languageCode) ? 'Позже' : 'Later'),
          ),
          FilledButton(
            onPressed: () {
              context.read<HomeBloc>().add(const HomeClearOldSessions());
              Navigator.pop(ctx);
            },
            child: Text(AppStrings.isRu(languageCode) ? 'Очистить' : 'Clear'),
          ),
        ],
      ),
    );
  }

  Widget _buildHeader(
    BuildContext context,
    HomeState state,
    String languageCode,
    SettingsStorage settings,
  ) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
      child: Row(
        children: [
          _buildCompactConnectControl(
            context: context,
            state: state,
            languageCode: languageCode,
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Center(
              child: Text(
                _formatClock(_now),
                style: const TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
          ),
          const SizedBox(width: 4),
          _headerIconButton(
            tooltip: AppStrings.saveHistory(languageCode),
            icon: Icons.save_alt,
            onPressed: () {
              final hasData = state.isRecording &&
                  state.currentHeartRate != null &&
                  (state.session != null);
              if (!hasData) {
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: Text(
                      AppStrings.historySaveUnavailable(languageCode),
                    ),
                  ),
                );
                return;
              }
              context.read<HomeBloc>().add(const HomeSaveHistoryRequested());
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(
                  content: Text(AppStrings.historySaved(languageCode)),
                ),
              );
            },
          ),
          const SizedBox(width: 2),
          _headerIconButton(
            tooltip: AppStrings.historyTitle(languageCode),
            icon: Icons.history,
            onPressed: () => Navigator.push(
              context,
              MaterialPageRoute(builder: (_) => const HistoryScreen()),
            ),
          ),
          const SizedBox(width: 2),
          _headerIconButton(
            tooltip: AppStrings.settingsTitle(languageCode),
            icon: Icons.settings,
            onPressed: () async {
              await Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (_) => SettingsScreen(onComplete: () {}),
                ),
              );
              if (context.mounted) {
                context.read<HomeBloc>().add(const HomeRefreshSettings());
              }
            },
          ),
        ],
      ),
    );
  }

  Widget _headerIconButton({
    required String tooltip,
    required IconData icon,
    required VoidCallback onPressed,
  }) {
    return IconButton(
      tooltip: tooltip,
      icon: Icon(icon, size: 20),
      padding: EdgeInsets.zero,
      constraints: const BoxConstraints.tightFor(width: 34, height: 34),
      visualDensity: VisualDensity.compact,
      splashRadius: 18,
      onPressed: onPressed,
    );
  }

  Color _bleStatusColor(BleConnectionStatus status) {
    switch (status) {
      case BleConnectionStatus.connected:
        return Colors.green;
      case BleConnectionStatus.error:
        return Colors.red;
      default:
        return Colors.grey;
    }
  }

  IconData _bleStatusIcon(BleConnectionStatus status) {
    switch (status) {
      case BleConnectionStatus.connected:
        return Icons.bluetooth_connected;
      case BleConnectionStatus.scanning:
      case BleConnectionStatus.connecting:
        return Icons.bluetooth_searching;
      case BleConnectionStatus.error:
        return Icons.bluetooth_disabled;
      case BleConnectionStatus.disconnected:
        return Icons.bluetooth;
    }
  }

  Widget _buildBottomPanel(
    BuildContext context,
    HomeState state,
    String languageCode,
    SettingsStorage settings,
  ) {
    final enableTimerStopwatch = settings.enableTimerStopwatch;
    final enableMusicControls = settings.enableMusicControls;

    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        if (enableTimerStopwatch)
          _buildTimerStopwatchCard(context, state, languageCode),
        if (enableTimerStopwatch && enableMusicControls)
          const SizedBox(height: _moduleGap),
        if (enableMusicControls) _buildMusicControlsCard(context),
      ],
    );
  }

  Widget _buildTimerStopwatchCard(
    BuildContext context,
    HomeState state,
    String languageCode,
  ) {
    final isTimerMode = state.timerMode == WorkoutTimerMode.timer;
    final activeSeconds =
        isTimerMode ? state.timerRemainingSeconds : state.timerElapsedSeconds;
    final shownSeconds = state.isTimerRunning
        ? activeSeconds
        : (isTimerMode ? state.timerDurationSeconds : state.timerElapsedSeconds);
    return _buildUnifiedModuleCard(
      height: _moduleHeight,
      child: Row(
        children: [
          Expanded(
            child: Row(
              children: [
                Expanded(
                  child: _timerModeButton(
                    icon: Icons.timer_outlined,
                    selected: state.timerMode == WorkoutTimerMode.timer,
                    onPressed: () => context
                        .read<HomeBloc>()
                        .add(const HomeTimerModeChanged(WorkoutTimerMode.timer)),
                  ),
                ),
                const SizedBox(width: 6),
                Expanded(
                  child: _timerModeButton(
                    icon: Icons.av_timer,
                    selected: state.timerMode == WorkoutTimerMode.stopwatch,
                    onPressed: () => context.read<HomeBloc>().add(
                        const HomeTimerModeChanged(WorkoutTimerMode.stopwatch)),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: OutlinedButton(
              style: _moduleButtonStyle(),
              onPressed: (state.isTimerRunning || !isTimerMode)
                  ? null
                  : () => _showDurationPickerSheet(context, state, languageCode),
              child: FittedBox(
                fit: BoxFit.scaleDown,
                child: Text(
                  _formatDurationSeconds(shownSeconds),
                  style: TextStyle(
                    fontWeight: FontWeight.w700,
                    fontSize: 22,
                    color: state.isTimerRunning
                        ? Colors.white
                        : Colors.white.withValues(alpha: 0.45),
                  ),
                ),
              ),
            ),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: OutlinedButton(
              style: _moduleButtonStyle(selected: state.isTimerRunning),
              onPressed: () =>
                  context.read<HomeBloc>().add(const HomeTimerStartPauseToggled()),
              child: Icon(state.isTimerRunning ? Icons.stop : Icons.play_arrow),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildMusicControlsCard(BuildContext context) {
    final media = context.read<MediaControlService>();
    return _buildUnifiedModuleCard(
      height: _moduleHeight,
      child: Row(
        children: [
          Expanded(child: _mediaButton(Icons.skip_previous, () => media.previous())),
          const SizedBox(width: 8),
          Expanded(child: _mediaButton(Icons.play_arrow, () => media.play())),
          const SizedBox(width: 8),
          Expanded(child: _mediaButton(Icons.pause, () => media.pause())),
          const SizedBox(width: 8),
          Expanded(child: _mediaButton(Icons.skip_next, () => media.next())),
        ],
      ),
    );
  }

  Widget _buildUnifiedModuleCard({
    required Widget child,
    double height = _moduleHeight,
    EdgeInsetsGeometry padding =
        const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
  }) {
    return Container(
      width: double.infinity,
      height: height,
      padding: padding,
      decoration: BoxDecoration(
        color: Colors.black.withValues(alpha: 0.25),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: Colors.white24),
      ),
      child: child,
    );
  }

  Widget _mediaButton(IconData icon, VoidCallback onPressed) {
    return OutlinedButton(
      style: _moduleButtonStyle(
        minHeight: 44,
      ),
      onPressed: onPressed,
      child: Icon(icon),
    );
  }

  Widget _timerModeButton({
    required IconData icon,
    required bool selected,
    required VoidCallback onPressed,
  }) {
    return OutlinedButton(
      style: _moduleButtonStyle(selected: selected),
      onPressed: onPressed,
      child: Icon(icon),
    );
  }

  ButtonStyle _moduleButtonStyle({
    bool selected = false,
    bool dense = false,
    double minWidth = 0,
    double minHeight = 44,
  }) {
    return OutlinedButton.styleFrom(
      minimumSize: Size(minWidth, minHeight),
      padding: dense
          ? EdgeInsets.zero
          : const EdgeInsets.symmetric(horizontal: 10),
      side: BorderSide(
        color: selected ? Colors.white54 : Colors.white24,
      ),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
      ),
      backgroundColor:
          selected ? Colors.white.withValues(alpha: 0.12) : Colors.transparent,
    );
  }

  Future<void> _showDurationPickerSheet(
    BuildContext context,
    HomeState state,
    String languageCode,
  ) async {
    final initial = state.timerDurationSeconds.clamp(10, 24 * 3600);
    var minutes = initial ~/ 60;
    var seconds = initial % 60;
    final minCtrl = FixedExtentScrollController(initialItem: minutes);
    final secCtrl = FixedExtentScrollController(initialItem: seconds);
    final picked = await showModalBottomSheet<int>(
      context: context,
      showDragHandle: true,
      builder: (ctx) => SafeArea(
        child: SizedBox(
          height: 300,
          child: Column(
            children: [
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    TextButton(
                      onPressed: () => Navigator.pop(ctx),
                      child: Text(AppStrings.cancel(languageCode)),
                    ),
                    Text(
                      AppStrings.timerPickerTitle(languageCode),
                      style: const TextStyle(fontWeight: FontWeight.w600),
                    ),
                    FilledButton(
                      onPressed: () {
                        final total = (minutes * 60 + seconds).clamp(10, 24 * 3600);
                        Navigator.pop(ctx, total);
                      },
                      child: Text(AppStrings.done(languageCode)),
                    ),
                  ],
                ),
              ),
              Expanded(
                child: Row(
                  children: [
                    Expanded(
                      child: CupertinoPicker(
                        scrollController: minCtrl,
                        itemExtent: 36,
                        onSelectedItemChanged: (v) => minutes = v,
                        children: [
                          for (var i = 0; i < 60; i++)
                            Center(child: Text(i.toString().padLeft(2, '0'))),
                        ],
                      ),
                    ),
                    const Text(':', style: TextStyle(fontSize: 24)),
                    Expanded(
                      child: CupertinoPicker(
                        scrollController: secCtrl,
                        itemExtent: 36,
                        onSelectedItemChanged: (v) => seconds = v,
                        children: [
                          for (var i = 0; i < 60; i++)
                            Center(child: Text(i.toString().padLeft(2, '0'))),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
    minCtrl.dispose();
    secCtrl.dispose();
    if (picked != null) {
      if (!context.mounted) return;
      context.read<HomeBloc>().add(HomeTimerCustomSet(picked));
    }
  }

  String _formatDurationSeconds(int seconds) {
    final h = seconds ~/ 3600;
    final m = (seconds % 3600) ~/ 60;
    final s = seconds % 60;
    if (h > 0) {
      return '${h.toString().padLeft(2, '0')}:${m.toString().padLeft(2, '0')}:${s.toString().padLeft(2, '0')}';
    }
    return '${m.toString().padLeft(2, '0')}:${s.toString().padLeft(2, '0')}';
  }

  String _formatClock(DateTime dt) {
    final h = dt.hour.toString().padLeft(2, '0');
    final m = dt.minute.toString().padLeft(2, '0');
    final s = dt.second.toString().padLeft(2, '0');
    return '$h:$m:$s';
  }

  Widget _buildCompactConnectControl({
    required BuildContext context,
    required HomeState state,
    required String languageCode,
  }) {
    final isConnected = state.bleStatus == BleConnectionStatus.connected;
    final isBusy = state.bleStatus == BleConnectionStatus.scanning ||
        state.bleStatus == BleConnectionStatus.connecting;
    return InkWell(
      borderRadius: BorderRadius.circular(14),
      onTap: isBusy
          ? null
          : () {
              if (isConnected) {
                context.read<HomeBloc>().add(const HomeDisconnectRequested());
              } else {
                context.read<HomeBloc>().add(const HomeConnectRequested());
              }
            },
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 5),
        decoration: BoxDecoration(
          color: Colors.white.withValues(alpha: 0.08),
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: Colors.white24),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              _bleStatusIcon(state.bleStatus),
              size: 16,
              color: Colors.white70,
            ),
            const SizedBox(width: 6),
            Container(
              width: 7,
              height: 7,
              decoration: BoxDecoration(
                color: _bleStatusColor(state.bleStatus),
                shape: BoxShape.circle,
              ),
            ),
            const SizedBox(width: 6),
            Text(
              isConnected
                  ? AppStrings.disconnectCompact(languageCode)
                  : AppStrings.connectCompact(languageCode),
              style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600),
            ),
          ],
        ),
      ),
    );
  }
}

class _PulseStyle {
  const _PulseStyle({
    required this.color,
    this.useGradient = false,
  });

  final Color color;
  final bool useGradient;
}
