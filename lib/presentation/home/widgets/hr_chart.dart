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
    final nowMs = DateTime.now().millisecondsSinceEpoch;
    final now = DateTime.fromMillisecondsSinceEpoch((nowMs ~/ 1000) * 1000);
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

    final maxX = Duration(minutes: chartWindowMinutes).inSeconds.toDouble();
    // Stable aggregation by fixed time buckets prevents old peaks from
    // "changing" when new points arrive.
    final bucketSizeSec = chartWindowMinutes <= 5
        ? 1
        : chartWindowMinutes <= 10
            ? 2
            : 4;
    final cutoffEpochSec = cutoff.millisecondsSinceEpoch ~/ 1000;
    final maxByBucket = <int, int>{};
    for (final reading in filtered) {
      final tsSec = reading.timestamp.millisecondsSinceEpoch ~/ 1000;
      final bucketStartSec = tsSec - (tsSec % bucketSizeSec);
      final currentMax = maxByBucket[bucketStartSec];
      if (currentMax == null || reading.heartRate > currentMax) {
        maxByBucket[bucketStartSec] = reading.heartRate;
      }
    }
    final bucketStarts = maxByBucket.keys.toList()..sort();
    final spots = <FlSpot>[
      for (final bucketStartSec in bucketStarts)
        if ((bucketStartSec - cutoffEpochSec) >= 0 &&
            (bucketStartSec - cutoffEpochSec) <= maxX)
          FlSpot(
            (bucketStartSec - cutoffEpochSec).toDouble(),
            maxByBucket[bucketStartSec]!.toDouble(),
          ),
    ];
    if (spots.length < 2) {
      return Center(
        child: Text(
          AppStrings.isRu(languageCode)
              ? 'Ожидание данных...'
              : 'Waiting for data...',
          style: TextStyle(color: Colors.grey[600], fontSize: 14),
        ),
      );
    }
    final gridIntervalSec = chartWindowMinutes <= 5
        ? 30.0
        : chartWindowMinutes <= 10
            ? 60.0
            : 120.0;
    final xLabelIntervalSec = chartWindowMinutes <= 5
        ? 60.0
        : chartWindowMinutes <= 10
            ? 120.0
            : 300.0;
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
          verticalInterval: gridIntervalSec,
          getDrawingHorizontalLine: (_) => FlLine(
            color: Colors.white.withValues(alpha: 0.10),
            strokeWidth: 1,
          ),
          getDrawingVerticalLine: (_) => FlLine(
            color: Colors.white.withValues(alpha: 0.06),
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
              interval: xLabelIntervalSec,
              getTitlesWidget: (value, meta) {
                if (value < 0 || value > maxX) {
                  return const SizedBox.shrink();
                }
                if (value <= 1) {
                  return Text(
                    '-$chartWindowMinutes:00',
                    style: const TextStyle(fontSize: 10, color: Colors.white70),
                  );
                }
                if ((value - maxX).abs() < 1) {
                  return const Text(
                    'now',
                    style: TextStyle(fontSize: 10, color: Colors.white70),
                  );
                }
                final nearestTick =
                    (value / xLabelIntervalSec).round() * xLabelIntervalSec;
                if ((value - nearestTick).abs() > 0.6) {
                  return const SizedBox.shrink();
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
                    color: Colors.white.withValues(alpha: 0.44),
                    strokeWidth: 2.3,
                    dashArray: const [7, 5],
                  ),
                ]
              : const [],
        ),
      ),
    );
  }
}
