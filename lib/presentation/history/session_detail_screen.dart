import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../core/app_strings.dart';
import '../../data/storage/history_repository.dart';
import '../../data/storage/settings_storage.dart';

class SessionDetailScreen extends StatefulWidget {
  const SessionDetailScreen({
    super.key,
    required this.summary,
  });

  static const String routeName = '/history/detail';
  final SessionSummary summary;

  @override
  State<SessionDetailScreen> createState() => _SessionDetailScreenState();
}

class _SessionDetailScreenState extends State<SessionDetailScreen> {
  late Future<SessionDetail> _future;

  @override
  void initState() {
    super.initState();
    _future = context.read<HistoryRepository>().loadDetail(widget.summary);
  }

  String _formatDuration(Duration d) {
    final h = d.inHours;
    final m = d.inMinutes.remainder(60).toString().padLeft(2, '0');
    final s = d.inSeconds.remainder(60).toString().padLeft(2, '0');
    if (h > 0) return '$h:$m:$s';
    return '$m:$s';
  }

  @override
  Widget build(BuildContext context) {
    final languageCode = context.read<SettingsStorage>().uiLanguage;
    return Scaffold(
      appBar: AppBar(title: Text(AppStrings.sessionDetails(languageCode))),
      body: FutureBuilder<SessionDetail>(
        future: _future,
        builder: (context, snapshot) {
          if (!snapshot.hasData) {
            return const Center(child: CircularProgressIndicator());
          }
          final detail = snapshot.data!;
          final readings = detail.readings;
          if (readings.length < 2) {
            return Center(
                child: Text(AppStrings.insufficientData(languageCode)));
          }
          final minY = readings
                  .map((r) => r.heartRate)
                  .reduce((a, b) => a < b ? a : b)
                  .toDouble() -
              10;
          final maxY = readings
                  .map((r) => r.heartRate)
                  .reduce((a, b) => a > b ? a : b)
                  .toDouble() +
              10;
          final sampled = readings.length <= 300
              ? readings
              : [
                  for (int i = 0;
                      i < readings.length;
                      i += (readings.length / 300).ceil())
                    readings[i],
                ];
          final spots = sampled
              .asMap()
              .entries
              .map(
                  (e) => FlSpot(e.key.toDouble(), e.value.heartRate.toDouble()))
              .toList();

          return ListView(
            padding: const EdgeInsets.all(16),
            children: [
              Text(
                '${AppStrings.durationLabel(languageCode)}: ${_formatDuration(detail.summary.duration)}',
                style: const TextStyle(fontWeight: FontWeight.w600),
              ),
              const SizedBox(height: 8),
              Text(
                AppStrings.hrAvgMaxMin(
                  languageCode,
                  detail.summary.averageHr,
                  detail.summary.maxHr,
                  detail.summary.minHr,
                ),
              ),
              const SizedBox(height: 16),
              SizedBox(
                height: 220,
                child: LineChart(
                  LineChartData(
                    minX: 0,
                    maxX: (sampled.length - 1).toDouble(),
                    minY: minY,
                    maxY: maxY,
                    titlesData: FlTitlesData(
                      show: true,
                      leftTitles: AxisTitles(
                        sideTitles: SideTitles(
                          showTitles: true,
                          reservedSize: 34,
                          interval: 20,
                          getTitlesWidget: (value, _) => Text(
                            value.round().toString(),
                            style: const TextStyle(
                                fontSize: 10, color: Colors.white70),
                          ),
                        ),
                      ),
                      bottomTitles: AxisTitles(
                        sideTitles: SideTitles(
                          showTitles: true,
                          reservedSize: 20,
                          getTitlesWidget: (value, _) {
                            final last = (sampled.length - 1).toDouble();
                            if ((value - 0).abs() < 0.5) {
                              return Text(
                                AppStrings.start(languageCode),
                                style: TextStyle(
                                    fontSize: 10, color: Colors.white70),
                              );
                            }
                            if ((value - last / 2).abs() < 0.5) {
                              return Text(
                                AppStrings.middle(languageCode),
                                style: TextStyle(
                                    fontSize: 10, color: Colors.white70),
                              );
                            }
                            if ((value - last).abs() < 0.5) {
                              return Text(
                                AppStrings.finish(languageCode),
                                style: TextStyle(
                                    fontSize: 10, color: Colors.white70),
                              );
                            }
                            return const SizedBox.shrink();
                          },
                        ),
                      ),
                      rightTitles: const AxisTitles(
                        sideTitles: SideTitles(showTitles: false),
                      ),
                      topTitles: const AxisTitles(
                        sideTitles: SideTitles(showTitles: false),
                      ),
                    ),
                    borderData: FlBorderData(show: false),
                    gridData: FlGridData(
                      show: true,
                      drawVerticalLine: false,
                      horizontalInterval: 20,
                      getDrawingHorizontalLine: (_) => FlLine(
                        color: Colors.white.withOpacity(0.08),
                        strokeWidth: 1,
                      ),
                    ),
                    lineBarsData: [
                      LineChartBarData(
                        spots: spots,
                        isCurved: false,
                        barWidth: 2,
                        color: Colors.tealAccent,
                        dotData: const FlDotData(show: false),
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 16),
              Text(
                AppStrings.timeInZones(languageCode),
                style: const TextStyle(fontWeight: FontWeight.w600),
              ),
              const SizedBox(height: 8),
              ...detail.timeInZones.entries.map(
                (e) => Padding(
                  padding: const EdgeInsets.symmetric(vertical: 2),
                  child: Text(
                    '${_localizedZoneName(languageCode, e.key)}: ${_formatDuration(e.value)}',
                  ),
                ),
              ),
            ],
          );
        },
      ),
    );
  }

  String _localizedZoneName(String languageCode, String raw) {
    if (AppStrings.isRu(languageCode)) return raw;
    switch (raw) {
      case 'Восстановление':
        return 'Recovery';
      case 'Жиросжигание':
        return 'Fat-burning';
      case 'Аэробная':
        return 'Aerobic';
      case 'Анаэробная':
        return 'Anaerobic';
      case 'Максимум':
        return 'Maximum';
      default:
        return raw;
    }
  }
}
