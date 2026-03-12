import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../../core/app_strings.dart';
import '../../../../core/constants.dart';
import '../../../../data/storage/settings_storage.dart';
import '../../../../domain/models/hr_reading.dart';

class HrChart extends StatelessWidget {
  const HrChart({
    super.key,
    required this.readings,
    this.chartWindowMinutes = AppConstants.defaultChartWindowMinutes,
    this.timerMarkerTimestamp,
    this.showTimerMarker = false,
  });

  final List<HrReading> readings;
  final int chartWindowMinutes;
  final DateTime? timerMarkerTimestamp;
  final bool showTimerMarker;

  @override
  Widget build(BuildContext context) {
    final languageCode = context.read<SettingsStorage>().uiLanguage;
    final now = DateTime.now();
    final cutoff = now.subtract(
      Duration(minutes: chartWindowMinutes),
    );
    final filtered =
        readings.where((r) => r.timestamp.isAfter(cutoff)).toList();

    if (filtered.length < 2) {
      return Center(
        child: Text(
          AppStrings.isRu(languageCode)
              ? 'Ожидание данных...'
              : 'Waiting for data...',
          style: TextStyle(color: Colors.grey[600], fontSize: 14),
        ),
      );
    }

    final minHr =
        filtered.map((r) => r.heartRate).reduce((a, b) => a < b ? a : b);
    final maxHr =
        filtered.map((r) => r.heartRate).reduce((a, b) => a > b ? a : b);
    // Pin lower chart bound to the minimal visible HR value so the
    // waveform visually rests on the bottom axis without extra gap.
    var chartMin = minHr.toDouble();
    var chartMax = (maxHr + 8).toDouble();
    if (chartMax - chartMin < 18) {
      chartMax = chartMin + 18;
    }
    chartMin = chartMin.clamp(40.0, 220.0);
    chartMax = chartMax.clamp(60.0, 240.0);

    final sampled = filtered.length <= 120
        ? filtered
        : [
            for (int i = 0;
                i < filtered.length;
                i += (filtered.length / 120).ceil())
              filtered[i],
          ];

    final maxX = Duration(minutes: chartWindowMinutes).inSeconds.toDouble();
    final spots = sampled.map((reading) {
      final seconds =
          reading.timestamp.difference(cutoff).inMilliseconds / 1000;
      return FlSpot(
          seconds.clamp(0, maxX).toDouble(), reading.heartRate.toDouble());
    }).toList();
    final timeIntervalSec = chartWindowMinutes <= 5
        ? 30.0
        : chartWindowMinutes <= 10
            ? 60.0
            : 120.0;
    final markerX = timerMarkerTimestamp == null
        ? null
        : (timerMarkerTimestamp!.difference(cutoff).inMilliseconds / 1000)
            .clamp(0, maxX)
            .toDouble();

    return LineChart(
      LineChartData(
        gridData: FlGridData(
          show: true,
          drawVerticalLine: true,
          drawHorizontalLine: true,
          horizontalInterval: 10,
          verticalInterval: timeIntervalSec,
          getDrawingHorizontalLine: (_) => FlLine(
            color: Colors.white.withValues(alpha: 0.10),
            strokeWidth: 1,
          ),
          getDrawingVerticalLine: (_) => FlLine(
            color: Colors.white.withValues(alpha: 0.08),
            strokeWidth: 1,
          ),
        ),
        titlesData: FlTitlesData(
          show: true,
          leftTitles: AxisTitles(
            axisNameWidget: const Padding(
              padding: EdgeInsets.only(bottom: 6),
              child: Text(
                'BPM',
                style: TextStyle(fontSize: 10, color: Colors.white60),
              ),
            ),
            sideTitles: SideTitles(
              showTitles: true,
              reservedSize: 36,
              interval: 10,
              getTitlesWidget: (value, meta) => Text(
                value.round().toString(),
                style: const TextStyle(fontSize: 10, color: Colors.white70),
              ),
            ),
          ),
          bottomTitles: AxisTitles(
            axisNameWidget: const SizedBox.shrink(),
            sideTitles: SideTitles(
              showTitles: true,
              reservedSize: 28,
              interval: timeIntervalSec,
              getTitlesWidget: (value, meta) {
                if ((value - maxX).abs() < 1) {
                  return const Text(
                    'now',
                    style: TextStyle(fontSize: 10, color: Colors.white70),
                  );
                }
                final secondsAgo = (maxX - value).round();
                final m = (secondsAgo ~/ 60).abs();
                final s = (secondsAgo % 60).abs().toString().padLeft(2, '0');
                return Text(
                  '-$m:$s',
                  style: const TextStyle(fontSize: 10, color: Colors.white70),
                );
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
        minX: 0,
        maxX: maxX,
        minY: chartMin,
        maxY: chartMax,
        lineBarsData: [
          LineChartBarData(
            spots: spots,
            isCurved: false,
            color: Colors.green.withValues(alpha: 0.6),
            barWidth: 2,
            isStrokeCapRound: true,
            dotData: const FlDotData(show: false),
            belowBarData: BarAreaData(
              show: true,
              color: Colors.green.withValues(alpha: 0.1),
            ),
          ),
        ],
        extraLinesData: ExtraLinesData(
          verticalLines: showTimerMarker && markerX != null
              ? [
                  VerticalLine(
                    x: markerX,
                    color: Colors.white.withValues(alpha: 0.30),
                    strokeWidth: 2,
                    dashArray: const [6, 6],
                  ),
                ]
              : const [],
        ),
      ),
    );
  }
}
