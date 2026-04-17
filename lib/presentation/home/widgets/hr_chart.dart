import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../../core/app_strings.dart';
import '../../../../core/constants.dart';
import '../../../../data/storage/settings_storage.dart';
import '../../../../domain/models/hr_reading.dart';
import '../home_bloc.dart';

class HrChart extends StatelessWidget {
  const HrChart({
    super.key,
    required this.readings,
    this.connectionGaps = const [],
    this.activeConnectionGapStartedAt,
    this.chartWindowMinutes = AppConstants.defaultChartWindowMinutes,
    this.timerMarkerTimestamp,
    this.showTimerMarker = false,
  });

  final List<HrReading> readings;
  final List<ConnectionGap> connectionGaps;
  final DateTime? activeConnectionGapStartedAt;
  final int chartWindowMinutes;
  final DateTime? timerMarkerTimestamp;
  final bool showTimerMarker;

  @override
  Widget build(BuildContext context) {
    final languageCode = context.read<SettingsStorage>().uiLanguage;
    final effectiveChartWindowMinutes =
        chartWindowMinutes < 30 ? 30 : chartWindowMinutes;
    final nowMs = DateTime.now().millisecondsSinceEpoch;
    final now = DateTime.fromMillisecondsSinceEpoch((nowMs ~/ 1000) * 1000);
    final cutoff = now.subtract(
      Duration(minutes: effectiveChartWindowMinutes),
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

    final maxX =
        Duration(minutes: effectiveChartWindowMinutes).inSeconds.toDouble();
    // Draw actual visible points over the selected time window so the chart
    // always reflects newest values and continuously drops old ones.
    final spots = filtered
        .map((reading) {
          final seconds =
              reading.timestamp.difference(cutoff).inMilliseconds / 1000;
          if (seconds < 0 || seconds > maxX) {
            return null;
          }
          return FlSpot(seconds.toDouble(), reading.heartRate.toDouble());
        })
        .whereType<FlSpot>()
        .toList();
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
    final segmentedSpots = <List<FlSpot>>[];
    var currentSegment = <FlSpot>[];
    for (var i = 0; i < spots.length; i++) {
      final current = spots[i];
      if (currentSegment.isEmpty) {
        currentSegment.add(current);
        continue;
      }
      final gapSeconds = current.x - currentSegment.last.x;
      if (gapSeconds > 3.5) {
        if (currentSegment.length >= 2) {
          segmentedSpots.add(currentSegment);
        }
        currentSegment = <FlSpot>[current];
      } else {
        currentSegment.add(current);
      }
    }
    if (currentSegment.length >= 2) {
      segmentedSpots.add(currentSegment);
    }
    if (segmentedSpots.isEmpty) {
      segmentedSpots.add(spots);
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
    final gapLines = connectionGaps
        .expand((gap) sync* {
          final startX = (gap.startedAt.difference(cutoff).inMilliseconds / 1000)
              .toDouble();
          final endX = (gap.endedAt.difference(cutoff).inMilliseconds / 1000)
              .toDouble();
          if (startX >= 0 && startX <= maxX) {
            yield VerticalLine(
              x: startX,
              color: Colors.orange.withValues(alpha: 0.45),
              strokeWidth: 1.4,
              dashArray: const [4, 4],
            );
          }
          if (endX >= 0 && endX <= maxX) {
            yield VerticalLine(
              x: endX,
              color: Colors.orange.withValues(alpha: 0.45),
              strokeWidth: 1.4,
              dashArray: const [4, 4],
            );
          }
        })
        .toList();
    final activeGapStartX = activeConnectionGapStartedAt == null
        ? null
        : (activeConnectionGapStartedAt!.difference(cutoff).inMilliseconds / 1000)
            .toDouble();
    if (activeGapStartX != null && activeGapStartX >= 0 && activeGapStartX <= maxX) {
      gapLines.add(
        VerticalLine(
          x: activeGapStartX,
          color: Colors.redAccent.withValues(alpha: 0.9),
          strokeWidth: 2.6,
          dashArray: const [2, 2],
        ),
      );
    }
    final gapTopLabels = <_GapTopLabel>[
      ...connectionGaps
          .map((gap) {
            final startX = (gap.startedAt.difference(cutoff).inMilliseconds / 1000)
                .toDouble();
            if (startX < 0 || startX > maxX) {
              return null;
            }
            return _GapTopLabel(
              x: startX,
              text: _formatGapDuration(gap.durationSeconds),
              color: Colors.orange.withValues(alpha: 0.86),
            );
          })
          .whereType<_GapTopLabel>(),
    ];
    final activeGapVisible = activeConnectionGapStartedAt != null &&
        activeGapStartX != null &&
        activeGapStartX >= 0 &&
        activeGapStartX <= maxX;
    final activeGapElapsed = activeGapVisible
        ? now.difference(activeConnectionGapStartedAt!).inSeconds
        : 0;
    if (activeGapVisible) {
      final activeX = activeGapStartX;
      gapTopLabels.add(
        _GapTopLabel(
          x: activeX,
          text: 'LIVE ${_formatGapDuration(activeGapElapsed)}',
          color: Colors.redAccent,
        ),
      );
    }
    final timerLines = showTimerMarker && markerX != null
        ? [
            VerticalLine(
              x: markerX,
              color: Colors.white.withValues(alpha: 0.44),
              strokeWidth: 2.3,
              dashArray: const [7, 5],
            ),
          ]
        : const <VerticalLine>[];

    return LayoutBuilder(
      builder: (context, constraints) {
        final activeX = activeGapStartX ?? 0.0;
        final overlayLeft = activeGapVisible
            ? ((activeX / maxX) * constraints.maxWidth - 40)
                .clamp(4.0, constraints.maxWidth - 84.0)
            : 0.0;
        return Stack(
          children: [
            LineChart(
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
                    '-$effectiveChartWindowMinutes:00',
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
          topTitles: AxisTitles(
            sideTitles: SideTitles(
              showTitles: true,
              reservedSize: 20,
              interval: 1,
              getTitlesWidget: (value, meta) {
                _GapTopLabel? label;
                for (final candidate in gapTopLabels) {
                  if ((candidate.x - value).abs() < 0.35) {
                    label = candidate;
                    break;
                  }
                }
                if (label == null) {
                  return const SizedBox.shrink();
                }
                return Padding(
                  padding: const EdgeInsets.only(bottom: 2),
                  child: Text(
                    label.text,
                    style: TextStyle(
                      fontSize: 10,
                      fontWeight: FontWeight.w700,
                      color: label.color,
                    ),
                  ),
                );
              },
            ),
          ),
        ),
        borderData: FlBorderData(show: false),
        minX: 0,
        maxX: maxX,
        minY: chartMin,
        maxY: chartMax,
        lineBarsData: segmentedSpots
            .map(
              (segment) => LineChartBarData(
                spots: segment,
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
            )
            .toList(),
                extraLinesData: ExtraLinesData(
                  verticalLines: [...gapLines, ...timerLines],
                ),
              ),
            ),
            if (activeGapVisible)
              Positioned(
                top: 2,
                left: overlayLeft,
                child: DecoratedBox(
                  decoration: BoxDecoration(
                    color: Colors.black.withValues(alpha: 0.6),
                    borderRadius: BorderRadius.circular(6),
                    border: Border.all(color: Colors.redAccent.withValues(alpha: 0.8)),
                  ),
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                    child: Text(
                      _formatGapDuration(activeGapElapsed),
                      style: const TextStyle(
                        fontSize: 10,
                        fontWeight: FontWeight.w700,
                        color: Colors.redAccent,
                      ),
                    ),
                  ),
                ),
              ),
          ],
        );
      },
    );
  }
}

String _formatGapDuration(int totalSeconds) {
  final safe = totalSeconds.clamp(0, 24 * 3600);
  final minutes = (safe ~/ 60).toString().padLeft(2, '0');
  final seconds = (safe % 60).toString().padLeft(2, '0');
  return '$minutes:$seconds';
}

class _GapTopLabel {
  const _GapTopLabel({
    required this.x,
    required this.text,
    required this.color,
  });

  final double x;
  final String text;
  final Color color;
}
