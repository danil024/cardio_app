import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

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
  late bool _soundEnabled;
  late bool _ttsEnabled;
  late bool _keepScreenOn;
  late int _chartWindowMinutes;
  late int _sensorPollIntervalMs;
  late String _uiLanguage;
  late bool _enableRangeAlert;
  late int _rangeAlertMinBpm;
  late int _rangeAlertMaxBpm;
  late bool _enableTimerStopwatch;
  late bool _enableMusicControls;
  late TextEditingController _ageController;
  late List<({HrZoneType type, double min, double max})> _presets;
  late HrZones _zones;

  @override
  void initState() {
    super.initState();
    _age = widget.settings.age;
    _targetZoneMinPercent = widget.settings.targetZoneMinPercent;
    _targetZoneMaxPercent = widget.settings.targetZoneMaxPercent;
    _soundEnabled = widget.settings.soundEnabled;
    _ttsEnabled = widget.settings.ttsEnabled;
    _keepScreenOn = widget.settings.keepScreenOn;
    _chartWindowMinutes = widget.settings.chartWindowMinutes;
    _sensorPollIntervalMs = widget.settings.sensorPollIntervalMs;
    _uiLanguage = widget.settings.uiLanguage;
    _enableRangeAlert = widget.settings.enableRangeAlert;
    _rangeAlertMinBpm = widget.settings.rangeAlertMinBpm;
    _rangeAlertMaxBpm = widget.settings.rangeAlertMaxBpm;
    _enableTimerStopwatch = widget.settings.enableTimerStopwatch;
    _enableMusicControls = widget.settings.enableMusicControls;
    _ageController = TextEditingController(text: _age.toString());
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
    _ageController.dispose();
    super.dispose();
  }

  void _updateAgeFromField() {
    final n = int.tryParse(_ageController.text);
    if (n != null) {
      setState(() {
        _age = n.clamp(AppConstants.minAge, AppConstants.maxAge);
        _ageController.text = _age.toString();
        _recalculateZones();
        _persistSettings();
      });
    }
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
    widget.settings.soundEnabled = _soundEnabled;
    widget.settings.ttsEnabled = _ttsEnabled;
    widget.settings.keepScreenOn = _keepScreenOn;
    widget.settings.chartWindowMinutes = _chartWindowMinutes;
    widget.settings.sensorPollIntervalMs = _sensorPollIntervalMs;
    widget.settings.uiLanguage = _uiLanguage;
    // UI language and voice language are linked by one selector.
    widget.settings.ttsLanguage = _uiLanguage;
    widget.settings.enableRangeAlert = _enableRangeAlert;
    widget.settings.rangeAlertMinBpm = _rangeAlertMinBpm;
    widget.settings.rangeAlertMaxBpm = _rangeAlertMaxBpm;
    widget.settings.enableTimerStopwatch = _enableTimerStopwatch;
    widget.settings.enableMusicControls = _enableMusicControls;
    context.read<HomeBloc>().add(const HomeRefreshSettings());
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
          Row(
            children: [
              Expanded(
                flex: 2,
                child: Slider(
                  value: _age.toDouble(),
                  min: AppConstants.minAge.toDouble(),
                  max: AppConstants.maxAge.toDouble(),
                  divisions: AppConstants.maxAge - AppConstants.minAge,
                  label: _age.toString(),
                  onChanged: (v) {
                    setState(() {
                      _age = v.round();
                      _ageController.text = _age.toString();
                      _recalculateZones();
                      _persistSettings();
                    });
                  },
                ),
              ),
              SizedBox(
                width: 56,
                child: TextField(
                  keyboardType: TextInputType.number,
                  textAlign: TextAlign.center,
                  decoration: const InputDecoration(
                    border: OutlineInputBorder(),
                    contentPadding:
                        EdgeInsets.symmetric(horizontal: 8, vertical: 12),
                  ),
                  controller: _ageController,
                  onSubmitted: (_) => _updateAgeFromField(),
                ),
              ),
            ],
          ),
          const SizedBox(height: 24),
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
          const SizedBox(height: 24),
          Text(
            AppStrings.sensorPollRate(languageCode),
            style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w500),
          ),
          const SizedBox(height: 8),
          SegmentedButton<int>(
            segments: AppConstants.sensorPollIntervalOptionsMs
                .map((ms) => ButtonSegment<int>(
                      value: ms,
                      label: Text(
                          '$ms${AppStrings.isRu(languageCode) ? 'мс' : 'ms'}'),
                    ))
                .toList(),
            selected: {_sensorPollIntervalMs},
            onSelectionChanged: (s) => setState(() {
              _sensorPollIntervalMs = s.first;
              _persistSettings();
            }),
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
          SwitchListTile(
            title: Text(AppStrings.keepScreenOnTitle(languageCode)),
            subtitle: Text(AppStrings.keepScreenOnSubtitle(languageCode)),
            value: _keepScreenOn,
            onChanged: (v) => setState(() {
              _keepScreenOn = v;
              _persistSettings();
            }),
          ),
          const SizedBox(height: 24),
          Text(
            AppStrings.alerts(languageCode),
            style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w500),
          ),
          SwitchListTile(
            title: Text(AppStrings.soundAlerts(languageCode)),
            value: _soundEnabled,
            onChanged: (v) => setState(() {
              _soundEnabled = v;
              _persistSettings();
            }),
          ),
          SwitchListTile(
            title: Text(AppStrings.ttsAlerts(languageCode)),
            value: _ttsEnabled,
            onChanged: (v) => setState(() {
              _ttsEnabled = v;
              _persistSettings();
            }),
          ),
          const SizedBox(height: 24),
          Text(
            AppStrings.isRu(languageCode)
                ? 'Дополнительные функции'
                : 'Additional features',
            style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w500),
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
            title: Text(AppStrings.rangeAlertTitle(languageCode)),
            subtitle: Text(AppStrings.rangeAlertSubtitle(languageCode)),
            value: _enableRangeAlert,
            onChanged: (v) => setState(() {
              _enableRangeAlert = v;
              _persistSettings();
            }),
          ),
          if (_enableRangeAlert) ...[
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
          ],
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
