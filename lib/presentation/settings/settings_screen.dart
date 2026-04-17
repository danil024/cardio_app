import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:file_picker/file_picker.dart';

import '../../core/app_strings.dart';
import '../../core/constants.dart';
import '../../domain/models/hr_zones.dart';
import '../../data/storage/settings_storage.dart';
import '../../domain/services/zones_calculator.dart';
import '../home/home_bloc.dart';

class SettingsScreen extends StatelessWidget {
  const SettingsScreen({
    super.key,
    required this.onComplete,
  });

  final VoidCallback onComplete;

  @override
  Widget build(BuildContext context) {
    final settings = context.read<SettingsStorage>();
    return _SettingsContent(
      settings: settings,
      onComplete: onComplete,
    );
  }
}

class _SettingsContent extends StatefulWidget {
  const _SettingsContent({
    required this.settings,
    required this.onComplete,
  });

  final SettingsStorage settings;
  final VoidCallback onComplete;

  @override
  State<_SettingsContent> createState() => _SettingsContentState();
}

class _SettingsContentState extends State<_SettingsContent> {
  late int _age;
  late double _targetZoneMinPercent;
  late double _targetZoneMaxPercent;
  late bool _keepScreenOn;
  late int _chartWindowMinutes;
  late String _uiLanguage;
  late String _hrRangeMode;
  late bool _zoneRangeBeepEnabled;
  late bool _zoneRangeVoiceEnabled;
  late bool _manualRangeBeepEnabled;
  late bool _manualRangeVoiceEnabled;
  late int _rangeAlertMinBpm;
  late int _rangeAlertMaxBpm;
  late bool _enableTimerStopwatch;
  late bool _enableMusicControls;
  late bool _enableMetronome;
  late bool _metronomeVoiceCuesEnabled;
  String? _sessionsCustomDirPath;
  late FixedExtentScrollController _agePickerController;
  late List<({HrZoneType type, double min, double max})> _presets;
  late HrZones _zones;

  @override
  void initState() {
    super.initState();
    _age = widget.settings.age;
    _targetZoneMinPercent = widget.settings.targetZoneMinPercent;
    _targetZoneMaxPercent = widget.settings.targetZoneMaxPercent;
    _keepScreenOn = widget.settings.keepScreenOn;
    _chartWindowMinutes = widget.settings.chartWindowMinutes;
    _uiLanguage = widget.settings.uiLanguage;
    _hrRangeMode = widget.settings.hrRangeMode;
    _zoneRangeBeepEnabled = widget.settings.zoneRangeBeepEnabled;
    _zoneRangeVoiceEnabled = widget.settings.zoneRangeVoiceEnabled;
    _manualRangeBeepEnabled = widget.settings.manualRangeBeepEnabled;
    _manualRangeVoiceEnabled = widget.settings.manualRangeVoiceEnabled;
    _rangeAlertMinBpm = widget.settings.rangeAlertMinBpm;
    _rangeAlertMaxBpm = widget.settings.rangeAlertMaxBpm;
    _enableTimerStopwatch = widget.settings.enableTimerStopwatch;
    _enableMusicControls = widget.settings.enableMusicControls;
    _enableMetronome = widget.settings.enableMetronome;
    _metronomeVoiceCuesEnabled = widget.settings.metronomeVoiceCuesEnabled;
    _sessionsCustomDirPath = widget.settings.sessionsCustomDirPath;
    _agePickerController =
        FixedExtentScrollController(initialItem: _age - AppConstants.minAge);
    _presets = <({HrZoneType type, double min, double max})>[
      (type: HrZoneType.recovery, min: 0.50, max: 0.60),
      (type: HrZoneType.fatBurning, min: 0.60, max: 0.70),
      (type: HrZoneType.aerobic, min: 0.70, max: 0.80),
      (type: HrZoneType.anaerobic, min: 0.80, max: 0.90),
      (type: HrZoneType.max, min: 0.90, max: 1.00),
    ];
    _recalculateZones();
  }

  @override
  void dispose() {
    _agePickerController.dispose();
    super.dispose();
  }

  void _recalculateZones() {
    _zones = ZonesCalculator.calculate(
      age: _age,
      targetZoneMinPercent: _targetZoneMinPercent,
      targetZoneMaxPercent: _targetZoneMaxPercent,
    );
  }

  void _persistSettings() {
    widget.settings.age = _age;
    widget.settings.targetZoneMinPercent = _targetZoneMinPercent;
    widget.settings.targetZoneMaxPercent = _targetZoneMaxPercent;
    widget.settings.keepScreenOn = _keepScreenOn;
    widget.settings.chartWindowMinutes = _chartWindowMinutes;
    widget.settings.uiLanguage = _uiLanguage;
    // UI language and voice language are linked by one selector.
    widget.settings.ttsLanguage = _uiLanguage;
    widget.settings.hrRangeMode = _hrRangeMode;
    widget.settings.zoneRangeBeepEnabled = _zoneRangeBeepEnabled;
    widget.settings.zoneRangeVoiceEnabled = _zoneRangeVoiceEnabled;
    widget.settings.manualRangeBeepEnabled = _manualRangeBeepEnabled;
    widget.settings.manualRangeVoiceEnabled = _manualRangeVoiceEnabled;
    widget.settings.enableRangeAlert = _hrRangeMode == 'manual';
    widget.settings.rangeAlertMinBpm = _rangeAlertMinBpm;
    widget.settings.rangeAlertMaxBpm = _rangeAlertMaxBpm;
    widget.settings.enableTimerStopwatch = _enableTimerStopwatch;
    widget.settings.enableMusicControls = _enableMusicControls;
    widget.settings.enableMetronome = _enableMetronome;
    widget.settings.metronomeVoiceCuesEnabled = _metronomeVoiceCuesEnabled;
    widget.settings.sessionsCustomDirPath = _sessionsCustomDirPath;
    context.read<HomeBloc>().add(const HomeRefreshSettings());
  }

  Future<void> _pickSessionsFolder() async {
    final languageCode = _uiLanguage;
    try {
      final selected = await FilePicker.platform.getDirectoryPath();
      if (selected == null || selected.trim().isEmpty) {
        return;
      }
      if (!mounted) return;
      setState(() {
        _sessionsCustomDirPath = selected;
        _persistSettings();
      });
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(AppStrings.storagePathUpdated(languageCode))),
      );
    } catch (_) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(AppStrings.storagePathUpdateFailed(languageCode))),
      );
    }
  }

  void _resetSessionsFolder() {
    final languageCode = _uiLanguage;
    setState(() {
      _sessionsCustomDirPath = null;
      _persistSettings();
    });
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(AppStrings.defaultStoragePathUsed(languageCode))),
    );
  }

  void _completeAndClose() {
    widget.onComplete();
    if (Navigator.canPop(context)) {
      Navigator.pop(context);
    }
  }

  @override
  Widget build(BuildContext context) {
    final languageCode = _uiLanguage;
    final zones = _zones;
    final selectedPreset = _presets.indexWhere(
      (p) =>
          (p.min - _targetZoneMinPercent).abs() < 0.001 &&
          (p.max - _targetZoneMaxPercent).abs() < 0.001,
    );

    return Scaffold(
      appBar: AppBar(
        title: Text(AppStrings.settingsTitle(languageCode)),
        actions: [
          TextButton(
            onPressed: _completeAndClose,
            child: Text(AppStrings.done(languageCode)),
          ),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.all(24),
        children: [
          Text(
            AppStrings.age(languageCode),
            style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w500),
          ),
          const SizedBox(height: 8),
          SizedBox(
            height: 120,
            child: CupertinoPicker(
              scrollController: _agePickerController,
              itemExtent: 36,
              onSelectedItemChanged: (index) {
                setState(() {
                  _age = AppConstants.minAge + index;
                  _recalculateZones();
                  _persistSettings();
                });
              },
              children: [
                for (var age = AppConstants.minAge;
                    age <= AppConstants.maxAge;
                    age++)
                  Center(child: Text(age.toString())),
              ],
            ),
          ),
          const SizedBox(height: 24),
          Text(
            AppStrings.hrAlertModeTitle(languageCode),
            style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w500),
          ),
          const SizedBox(height: 8),
          SegmentedButton<String>(
            segments: [
              ButtonSegment<String>(
                value: 'zone',
                label: Text(AppStrings.hrAlertModeZone(languageCode)),
              ),
              ButtonSegment<String>(
                value: 'manual',
                label: Text(AppStrings.hrAlertModeManual(languageCode)),
              ),
            ],
            selected: {_hrRangeMode},
            onSelectionChanged: (s) => setState(() {
              _hrRangeMode = s.first;
              if (_hrRangeMode == 'zone') {
                // In target zone mode, beep and voice are always active.
                _zoneRangeBeepEnabled = true;
                _zoneRangeVoiceEnabled = true;
              }
              _persistSettings();
            }),
          ),
          const SizedBox(height: 12),
          if (_hrRangeMode == 'zone') ...[
            Text(
              AppStrings.heartRateZones(languageCode),
              style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w500),
            ),
            const SizedBox(height: 8),
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: List.generate(zones.zones.length, (i) {
                final z = zones.zones[i];
                final p = _presets[i];
                final isSelected =
                    i == (selectedPreset == -1 ? 1 : selectedPreset);
                return InkWell(
                  onTap: () {
                    setState(() {
                      _targetZoneMinPercent = p.min;
                      _targetZoneMaxPercent = p.max;
                      _recalculateZones();
                      _persistSettings();
                    });
                  },
                  child: Padding(
                    padding: const EdgeInsets.symmetric(vertical: 6),
                    child: Row(
                      children: [
                        Icon(
                          isSelected
                              ? Icons.radio_button_checked
                              : Icons.radio_button_off,
                          color: isSelected ? Colors.green : Colors.grey,
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            '${AppStrings.zoneName(languageCode, p.type)}: '
                            '${z.minBpm}–${z.maxBpm} ${AppStrings.isRu(languageCode) ? 'уд/мин' : 'bpm'}',
                          ),
                        ),
                        Text(
                            '${(p.min * 100).round()}-${(p.max * 100).round()}%'),
                      ],
                    ),
                  ),
                );
              }),
            ),
            const SizedBox(height: 4),
            Text(
              AppStrings.currentTargetZone(
                languageCode,
                AppStrings.zoneName(
                  languageCode,
                  _presets[selectedPreset == -1 ? 1 : selectedPreset].type,
                ),
              ),
              style: TextStyle(color: Colors.grey[600], fontSize: 12),
            ),
          ],
          if (_hrRangeMode == 'manual') ...[
            Text(
              AppStrings.allowedRangeLabel(
                languageCode,
                _rangeAlertMinBpm,
                _rangeAlertMaxBpm,
              ),
            ),
            RangeSlider(
              min: 50,
              max: 230,
              divisions: 180,
              values: RangeValues(
                _rangeAlertMinBpm.toDouble(),
                _rangeAlertMaxBpm.toDouble(),
              ),
              labels: RangeLabels(
                _rangeAlertMinBpm.toString(),
                _rangeAlertMaxBpm.toString(),
              ),
              onChanged: (v) => setState(() {
                final start = v.start.round();
                final end = v.end.round();
                if (start >= end) return;
                _rangeAlertMinBpm = start;
                _rangeAlertMaxBpm = end;
                _persistSettings();
              }),
            ),
            SwitchListTile(
              title: Text(AppStrings.manualRangeBeepToggle(languageCode)),
              value: _manualRangeBeepEnabled,
              onChanged: (v) => setState(() {
                _manualRangeBeepEnabled = v;
                _persistSettings();
              }),
            ),
            SwitchListTile(
              title: Text(AppStrings.manualRangeVoiceToggle(languageCode)),
              value: _manualRangeVoiceEnabled,
              onChanged: (v) => setState(() {
                _manualRangeVoiceEnabled = v;
                _persistSettings();
              }),
            ),
          ],
          if (_hrRangeMode == 'zone') ...[
            ListTile(
              leading: const Icon(Icons.volume_up_outlined),
              title: Text(AppStrings.zoneModeAudioInfoTitle(languageCode)),
              subtitle: Text(AppStrings.zoneModeAudioInfoSubtitle(languageCode)),
            ),
          ],
          const SizedBox(height: 24),
          Text(
            AppStrings.isRu(languageCode)
                ? 'Дополнительные настройки'
                : 'Additional settings',
            style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w500),
          ),
          SwitchListTile(
            title: Text(AppStrings.keepScreenOnTitle(languageCode)),
            subtitle: Text(AppStrings.keepScreenOnSubtitle(languageCode)),
            value: _keepScreenOn,
            onChanged: (v) => setState(() {
              _keepScreenOn = v;
              _persistSettings();
            }),
          ),
          SwitchListTile(
            title: Text(AppStrings.isRu(languageCode)
                ? 'Таймер/секундомер на главном'
                : 'Timer/stopwatch on home'),
            value: _enableTimerStopwatch,
            onChanged: (v) => setState(() {
              _enableTimerStopwatch = v;
              _persistSettings();
            }),
          ),
          SwitchListTile(
            title: Text(AppStrings.isRu(languageCode)
                ? 'Управление музыкой'
                : 'Music controls'),
            subtitle: Text(AppStrings.isRu(languageCode)
                ? 'Кнопки предыдущий/пауза/следующий'
                : 'Previous/play-pause/next buttons'),
            value: _enableMusicControls,
            onChanged: (v) => setState(() {
              _enableMusicControls = v;
              _persistSettings();
            }),
          ),
          SwitchListTile(
            title: Text(AppStrings.metronomeHomeToggle(languageCode)),
            value: _enableMetronome,
            onChanged: (v) => setState(() {
              _enableMetronome = v;
              _persistSettings();
            }),
          ),
          if (_enableMetronome)
            SwitchListTile(
              title: Text(AppStrings.isRu(languageCode)
                  ? 'Озвучка фаз (английский)'
                  : 'Phase voice cues (English)'),
              value: _metronomeVoiceCuesEnabled,
              onChanged: (v) => setState(() {
                _metronomeVoiceCuesEnabled = v;
                _persistSettings();
              }),
            ),
          const SizedBox(height: 8),
          Text(
            AppStrings.storagePathTitle(languageCode),
            style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w500),
          ),
          const SizedBox(height: 8),
          Text(
            _sessionsCustomDirPath == null
                ? AppStrings.defaultStoragePathUsed(languageCode)
                : AppStrings.currentStoragePath(
                    languageCode,
                    _sessionsCustomDirPath!,
                  ),
            style: TextStyle(color: Colors.grey[400], fontSize: 12),
          ),
          const SizedBox(height: 8),
          Row(
            children: [
              Expanded(
                child: OutlinedButton.icon(
                  onPressed: _pickSessionsFolder,
                  icon: const Icon(Icons.folder_open),
                  label: Text(AppStrings.chooseStoragePath(languageCode)),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: OutlinedButton.icon(
                  onPressed:
                      _sessionsCustomDirPath == null ? null : _resetSessionsFolder,
                  icon: const Icon(Icons.restart_alt),
                  label: Text(AppStrings.resetStoragePath(languageCode)),
                ),
              ),
            ],
          ),
          const SizedBox(height: 24),
          Text(
            AppStrings.chartWindow(languageCode),
            style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w500),
          ),
          const SizedBox(height: 8),
          SegmentedButton<int>(
            segments: AppConstants.chartWindowOptions
                .map((m) => ButtonSegment<int>(
                      value: m,
                      label: Text(
                          '$m ${AppStrings.isRu(languageCode) ? 'мин' : 'min'}'),
                    ))
                .toList(),
            selected: {_chartWindowMinutes},
            onSelectionChanged: (s) => setState(() {
              _chartWindowMinutes = s.first;
              _persistSettings();
            }),
          ),
          const SizedBox(height: 24),
          Text(
            AppStrings.interfaceLanguage(languageCode),
            style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w500),
          ),
          const SizedBox(height: 8),
          SegmentedButton<String>(
            segments: [
              ButtonSegment<String>(
                value: AppStrings.en,
                label: Text(AppStrings.english(languageCode)),
              ),
              ButtonSegment<String>(
                value: AppStrings.ru,
                label: Text(AppStrings.russian(languageCode)),
              ),
            ],
            selected: {_uiLanguage},
            onSelectionChanged: (s) => setState(() {
              _uiLanguage = s.first;
              _persistSettings();
            }),
          ),
          const SizedBox(height: 24),
          Text(
            AppStrings.testMode(languageCode),
            style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w500),
          ),
          const SizedBox(height: 8),
          BlocBuilder<HomeBloc, HomeState>(
            builder: (context, homeState) {
              return FilledButton.tonalIcon(
                onPressed: () =>
                    context.read<HomeBloc>().add(const HomeTestRequested()),
                icon: Icon(homeState.isTestMode ? Icons.stop : Icons.science),
                label: Text(
                  homeState.isTestMode
                      ? AppStrings.stopTest(languageCode)
                      : AppStrings.startTest(languageCode),
                ),
              );
            },
          ),
          const SizedBox(height: 24),
        ],
      ),
    );
  }
}
