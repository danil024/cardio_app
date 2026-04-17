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
import '../../domain/models/metronome_preset.dart';
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

    final isBackgroundState =
        state == AppLifecycleState.paused || state == AppLifecycleState.detached;

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
            final showZoneCard = state.currentHeartRate != null && state.zones != null;
            final chartHeightFactor = _chartHeightFactorForLayout(
              settings: settings,
              showZoneCard: showZoneCard,
            );
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
                  SizedBox(
                    height: MediaQuery.of(context).size.height * chartHeightFactor,
                    child: Stack(
                      children: [
                        Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 16),
                          child: HrChart(
                            readings: state.readings,
                            connectionGaps: state.connectionGaps,
                            activeConnectionGapStartedAt:
                                state.activeConnectionGapStartedAt,
                            chartWindowMinutes: state.chartWindowMinutes,
                            showTimerMarker: state.isTimerRunning &&
                                state.timerMode == WorkoutTimerMode.timer,
                            timerMarkerTimestamp: state.timerStartedAt,
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

  double _chartHeightFactorForLayout({
    required SettingsStorage settings,
    required bool showZoneCard,
  }) {
    var units = 0.0;
    if (showZoneCard) units += 1.0;
    if (settings.enableMusicControls) units += 1.0;
    if (settings.enableTimerStopwatch) units += 1.0;
    if (settings.enableMetronome) units += 1.8;
    final factor = 0.72 - (units * 0.08);
    return factor.clamp(0.36, 0.70);
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
    final enableMetronome = settings.enableMetronome;
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        if (enableMusicControls) _buildMusicControlsCard(context),
        if (enableMusicControls && enableMetronome)
          const SizedBox(height: _moduleGap),
        if (enableMetronome) _buildMetronomeCard(context, state, languageCode),
        if (enableTimerStopwatch && enableMetronome)
          const SizedBox(height: _moduleGap),
        if (enableTimerStopwatch)
          _buildTimerStopwatchCard(context, state, languageCode),
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

  Widget _buildMetronomeCard(
    BuildContext context,
    HomeState state,
    String languageCode,
  ) {
    final presets = state.metronomePresets;
    final selectedId = state.selectedMetronomePresetId;
    final selected = selectedId == null
        ? null
        : presets.cast<MetronomePreset?>().firstWhere(
              (p) => p?.id == selectedId,
              orElse: () => null,
            );
    final noPresetText = AppStrings.isRu(languageCode) ? 'Создать пресет' : 'Create preset';

    return _buildUnifiedModuleCard(
      height: _moduleHeight,
      child: Row(
        children: [
          Expanded(
            flex: 3,
            child: OutlinedButton(
              style: _moduleButtonStyle(minHeight: 44),
              onPressed: () {
                final base = selected ??
                    MetronomePreset(
                      id: DateTime.now().microsecondsSinceEpoch.toString(),
                      name: 'Preset ${presets.length + 1}',
                    );
                _showMetronomePresetEditor(
                  context,
                  languageCode,
                  initial: base,
                );
              },
              onLongPress: () => _showMetronomePresetManager(context, languageCode),
              child: Text(
                selected?.name ?? noPresetText,
                style: const TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                ),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ),
          ),
          const SizedBox(width: 6),
          Expanded(
            flex: 2,
            child: OutlinedButton(
              style: _moduleButtonStyle(minHeight: 44),
              onPressed: null,
              child: Text(
                _formatDurationSeconds(state.metronomePhaseRemainingSec),
                style: const TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
          ),
          const SizedBox(width: 6),
          Expanded(
            flex: 2,
            child: OutlinedButton(
              style: _moduleButtonStyle(minHeight: 44),
              onPressed: state.isMetronomeSessionRunning
                  ? () => context
                      .read<HomeBloc>()
                      .add(const HomeMetronomeSessionStopped())
                  : null,
              child: Text(
                '${state.metronomeCompletedCycles}/${state.metronomeTargetCycles ?? '∞'}',
                style: const TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
          ),
          const SizedBox(width: 6),
          Expanded(
            flex: 2,
            child: OutlinedButton(
              style: _moduleButtonStyle(
                selected: state.isMetronomeSessionRunning,
                minHeight: 44,
              ),
              onPressed: selected == null
                  ? null
                  : () => context.read<HomeBloc>().add(
                        !state.isMetronomeSessionRunning
                            ? const HomeMetronomeSessionStarted()
                            : const HomeMetronomeSessionPauseToggled(),
                      ),
              child: Text(
                !state.isMetronomeSessionRunning
                    ? AppStrings.metronomeStart(languageCode)
                    : AppStrings.metronomePauseResume(
                        languageCode,
                        state.isMetronomeSessionPaused,
                      ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _showMetronomePresetManager(
    BuildContext context,
    String languageCode,
  ) async {
    await showModalBottomSheet<void>(
      context: context,
      showDragHandle: true,
      isScrollControlled: true,
      builder: (ctx) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 24),
          child: BlocBuilder<HomeBloc, HomeState>(
            builder: (context, currentState) {
              final presets = currentState.metronomePresets;
              return Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    AppStrings.metronomePresets(languageCode),
                    style: const TextStyle(fontWeight: FontWeight.w700),
                  ),
                  const SizedBox(height: 12),
                  Flexible(
                    child: ListView(
                      shrinkWrap: true,
                      children: [
                        for (final preset in presets)
                          ListTile(
                            dense: true,
                            title: Text(preset.name),
                            subtitle: Text(
                              'C:${preset.countdownSec} N:${preset.negativeSec} P:${preset.pauseSec} '
                              'Pr:${preset.pressSec} R:${preset.restSec}',
                            ),
                            onTap: () {
                              context
                                  .read<HomeBloc>()
                                  .add(HomeMetronomePresetSelected(preset.id));
                              Navigator.pop(ctx);
                            },
                            trailing: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                IconButton(
                                  tooltip: AppStrings.save(languageCode),
                                  icon: const Icon(Icons.edit_outlined),
                                  onPressed: () {
                                    Navigator.pop(ctx);
                                    Future<void>.microtask(() {
                                      if (!context.mounted) return;
                                      _showMetronomePresetEditor(
                                        context,
                                        languageCode,
                                        initial: preset,
                                      );
                                    });
                                  },
                                ),
                                IconButton(
                                  icon: const Icon(Icons.delete_outline),
                                  onPressed: () => context
                                      .read<HomeBloc>()
                                      .add(HomeMetronomePresetDeleted(preset.id)),
                                ),
                              ],
                            ),
                          ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 8),
                  FilledButton.tonalIcon(
                    onPressed: () {
                      Navigator.pop(ctx);
                      Future<void>.microtask(() {
                        if (!context.mounted) return;
                        _showMetronomePresetEditor(
                          context,
                          languageCode,
                          initial: MetronomePreset(
                            id: DateTime.now().microsecondsSinceEpoch.toString(),
                            name: 'Preset ${presets.length + 1}',
                          ),
                        );
                      });
                    },
                    icon: const Icon(Icons.add),
                    label: Text(AppStrings.save(languageCode)),
                  ),
                ],
              );
            },
          ),
        ),
      ),
    );
  }

  Future<void> _showMetronomePresetEditor(
    BuildContext context,
    String languageCode, {
    required MetronomePreset initial,
  }) async {
    final nameCtrl = TextEditingController(text: initial.name);
    var countdownSec = initial.countdownSec;
    var negativeSec = initial.negativeSec;
    var pauseSec = initial.pauseSec;
    var pressSec = initial.pressSec;
    var restSec = initial.restSec;
    var fixedCycles = initial.fixedCycles;
    var cycleMode = initial.cycleMode;
    var countdownEnabled = initial.countdownSec > 0;
    var negativeEnabled = initial.negativeSec > 0;
    var pauseEnabled = initial.pauseSec > 0;
    var pressEnabled = initial.pressSec > 0;
    var restEnabled = initial.restSec > 0;

    final saved = await showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      enableDrag: false,
      isDismissible: false,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setModalState) => SafeArea(
          child: Padding(
            padding: EdgeInsets.fromLTRB(
              16,
              12,
              16,
              24 + MediaQuery.of(ctx).viewInsets.bottom,
            ),
            child: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  TextField(
                    controller: nameCtrl,
                    decoration: InputDecoration(
                      labelText: AppStrings.isRu(languageCode)
                          ? 'Название пресета'
                          : 'Preset name',
                    ),
                  ),
                  const SizedBox(height: 10),
                  Align(
                    alignment: Alignment.centerLeft,
                    child: Text(
                      AppStrings.isRu(languageCode)
                          ? 'Фазы'
                          : 'Phases',
                      style: const TextStyle(
                        fontWeight: FontWeight.w700,
                        color: Colors.white70,
                      ),
                    ),
                  ),
                  const SizedBox(height: 8),
                  _buildPhaseRow(
                    languageCode: languageCode,
                    phaseKey: 'countdown',
                    enabled: countdownEnabled,
                    valueSec: countdownSec,
                    onEnabledChanged: (v) =>
                        setModalState(() => countdownEnabled = v),
                    onPickValue: () async {
                      final picked = await _showIntegerPickerSheet(
                        context,
                        languageCode: languageCode,
                        title: AppStrings.isRu(languageCode)
                            ? 'Обратный отсчёт (сек)'
                            : 'Countdown (sec)',
                        initialValue: countdownSec,
                        minValue: 0,
                        maxValue: 600,
                      );
                      if (picked != null && ctx.mounted) {
                        setModalState(() => countdownSec = picked);
                      }
                    },
                  ),
                  _buildPhaseRow(
                    languageCode: languageCode,
                    phaseKey: 'negative',
                    enabled: negativeEnabled,
                    valueSec: negativeSec,
                    onEnabledChanged: (v) =>
                        setModalState(() => negativeEnabled = v),
                    onPickValue: () async {
                      final picked = await _showIntegerPickerSheet(
                        context,
                        languageCode: languageCode,
                        title: AppStrings.isRu(languageCode)
                            ? 'Негатив (сек)'
                            : 'Negative (sec)',
                        initialValue: negativeSec,
                        minValue: 0,
                        maxValue: 600,
                      );
                      if (picked != null && ctx.mounted) {
                        setModalState(() => negativeSec = picked);
                      }
                    },
                  ),
                  _buildPhaseRow(
                    languageCode: languageCode,
                    phaseKey: 'pause',
                    enabled: pauseEnabled,
                    valueSec: pauseSec,
                    onEnabledChanged: (v) => setModalState(() => pauseEnabled = v),
                    onPickValue: () async {
                      final picked = await _showIntegerPickerSheet(
                        context,
                        languageCode: languageCode,
                        title: AppStrings.isRu(languageCode)
                            ? 'Пауза (сек)'
                            : 'Pause (sec)',
                        initialValue: pauseSec,
                        minValue: 0,
                        maxValue: 600,
                      );
                      if (picked != null && ctx.mounted) {
                        setModalState(() => pauseSec = picked);
                      }
                    },
                  ),
                  _buildPhaseRow(
                    languageCode: languageCode,
                    phaseKey: 'press',
                    enabled: pressEnabled,
                    valueSec: pressSec,
                    onEnabledChanged: (v) => setModalState(() => pressEnabled = v),
                    onPickValue: () async {
                      final picked = await _showIntegerPickerSheet(
                        context,
                        languageCode: languageCode,
                        title: AppStrings.isRu(languageCode)
                            ? 'Жим/подъём (сек)'
                            : 'Press (sec)',
                        initialValue: pressSec,
                        minValue: 0,
                        maxValue: 600,
                      );
                      if (picked != null && ctx.mounted) {
                        setModalState(() => pressSec = picked);
                      }
                    },
                  ),
                  _buildPhaseRow(
                    languageCode: languageCode,
                    phaseKey: 'rest',
                    enabled: restEnabled,
                    valueSec: restSec,
                    onEnabledChanged: (v) => setModalState(() => restEnabled = v),
                    onPickValue: () async {
                      final picked = await _showIntegerPickerSheet(
                        context,
                        languageCode: languageCode,
                        title: AppStrings.isRu(languageCode)
                            ? 'Отдых (сек)'
                            : 'Rest (sec)',
                        initialValue: restSec,
                        minValue: 0,
                        maxValue: 600,
                      );
                      if (picked != null && ctx.mounted) {
                        setModalState(() => restSec = picked);
                      }
                    },
                  ),
                  const SizedBox(height: 8),
                  SegmentedButton<MetronomeCycleMode>(
                    segments: [
                      ButtonSegment(
                        value: MetronomeCycleMode.fixed,
                        label: Text(AppStrings.isRu(languageCode)
                            ? 'Фикс. циклы'
                            : 'Fixed cycles'),
                      ),
                      ButtonSegment(
                        value: MetronomeCycleMode.untilStopped,
                        label: Text(AppStrings.isRu(languageCode)
                            ? 'До стопа'
                            : 'Until stop'),
                      ),
                    ],
                    selected: {cycleMode},
                    onSelectionChanged: (s) =>
                        setModalState(() => cycleMode = s.first),
                  ),
                  const SizedBox(height: 8),
                  if (cycleMode == MetronomeCycleMode.fixed)
                    _buildCycleRow(
                      languageCode: languageCode,
                      value: fixedCycles,
                      onPickValue: () async {
                        final picked = await _showIntegerPickerSheet(
                          context,
                          languageCode: languageCode,
                          title: AppStrings.isRu(languageCode)
                              ? 'Количество циклов'
                              : 'Number of cycles',
                          initialValue: fixedCycles,
                          minValue: 1,
                          maxValue: 999,
                        );
                        if (picked != null && ctx.mounted) {
                          setModalState(() => fixedCycles = picked);
                        }
                      },
                    ),
                  const SizedBox(height: 12),
                  Row(
                    children: [
                      Expanded(
                        child: OutlinedButton(
                          onPressed: () => Navigator.pop(ctx, false),
                          child: Text(AppStrings.cancel(languageCode)),
                        ),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: FilledButton(
                          onPressed: () => Navigator.pop(ctx, true),
                          child: Text(AppStrings.save(languageCode)),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );

    if (saved == true && context.mounted) {
      final updated = initial.copyWith(
        name: nameCtrl.text.trim().isEmpty
            ? initial.name
            : nameCtrl.text.trim(),
        countdownSec: countdownEnabled ? countdownSec.clamp(0, 600) : 0,
        negativeSec: negativeEnabled ? negativeSec.clamp(0, 600) : 0,
        pauseSec: pauseEnabled ? pauseSec.clamp(0, 600) : 0,
        pressSec: pressEnabled ? pressSec.clamp(0, 600) : 0,
        restSec: restEnabled ? restSec.clamp(0, 600) : 0,
        cycleMode: cycleMode,
        fixedCycles: fixedCycles.clamp(1, 999),
      );
      context.read<HomeBloc>().add(HomeMetronomePresetSaved(updated));
    }

    nameCtrl.dispose();
  }

  Widget _buildPhaseRow({
    required String languageCode,
    required String phaseKey,
    required bool enabled,
    required int valueSec,
    required ValueChanged<bool> onEnabledChanged,
    required VoidCallback onPickValue,
  }) {
    final isRu = AppStrings.isRu(languageCode);
    final phaseLabel = _phaseEditorLabel(languageCode, phaseKey);
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(
        children: [
          Expanded(
            child: Row(
              children: [
                Switch.adaptive(
                  value: enabled,
                  onChanged: onEnabledChanged,
                ),
                const SizedBox(width: 6),
                Expanded(
                  child: Text(
                    phaseLabel,
                    style: TextStyle(
                      fontSize: 14,
                      color: enabled ? Colors.white : Colors.white54,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 8),
          SizedBox(
            width: 110,
            child: OutlinedButton(
              onPressed: enabled ? onPickValue : null,
              style: _moduleButtonStyle(minHeight: 40),
              child: Text(
                '$valueSec ${isRu ? 'сек' : 'sec'}',
                textAlign: TextAlign.center,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildCycleRow({
    required String languageCode,
    required int value,
    required VoidCallback onPickValue,
  }) {
    final isRu = AppStrings.isRu(languageCode);
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(
        children: [
          Expanded(
            child: Text(
              isRu ? 'Количество циклов' : 'Number of cycles',
              style: const TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w600,
                color: Colors.white70,
              ),
            ),
          ),
          const SizedBox(width: 8),
          SizedBox(
            width: 110,
            child: OutlinedButton(
              onPressed: onPickValue,
              style: _moduleButtonStyle(minHeight: 40),
              child: Text(
                '$value',
                textAlign: TextAlign.center,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Future<int?> _showIntegerPickerSheet(
    BuildContext context, {
    required String languageCode,
    required String title,
    required int initialValue,
    required int minValue,
    required int maxValue,
  }) async {
    var current = initialValue.clamp(minValue, maxValue);
    final itemCount = maxValue - minValue + 1;
    final controller = FixedExtentScrollController(initialItem: current - minValue);
    final picked = await showCupertinoModalPopup<int>(
      context: context,
      builder: (ctx) => SafeArea(
        child: Material(
          color: Colors.black.withValues(alpha: 0.85),
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
                        title,
                        style: const TextStyle(fontWeight: FontWeight.w600),
                      ),
                      FilledButton(
                        onPressed: () => Navigator.pop(ctx, current),
                        child: Text(AppStrings.done(languageCode)),
                      ),
                    ],
                  ),
                ),
                Expanded(
                  child: CupertinoPicker(
                    scrollController: controller,
                    itemExtent: 36,
                    onSelectedItemChanged: (idx) => current = minValue + idx,
                    children: [
                      for (var i = 0; i < itemCount; i++)
                        Center(child: Text('${minValue + i}')),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
    controller.dispose();
    return picked;
  }

  String _phaseEditorLabel(String languageCode, String phaseKey) {
    final ru = AppStrings.isRu(languageCode);
    switch (phaseKey) {
      case 'countdown':
        return ru ? 'Обратный отсчёт' : 'Countdown';
      case 'negative':
        return ru ? 'Негатив' : 'Negative';
      case 'pause':
        return ru ? 'Пауза' : 'Pause';
      case 'press':
        return ru ? 'Жим/подъём' : 'Press';
      case 'rest':
        return ru ? 'Отдых' : 'Rest';
      default:
        return phaseKey;
    }
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
