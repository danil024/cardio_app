import 'dart:io';
import 'dart:ui' as ui;

import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';

import '../../core/app_strings.dart';
import '../../data/platform/media_export_service.dart';
import '../../data/storage/history_repository.dart';
import '../../data/storage/settings_storage.dart';
import 'history_file_actions.dart';

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
  final GlobalKey _chartBoundaryKey = GlobalKey();

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

  Future<void> _shareCsv() async {
    await SharePlus.instance.share(
      ShareParams(files: [XFile(widget.summary.csvPath)]),
    );
  }

  Future<void> _shareJson() async {
    await SharePlus.instance.share(
      ShareParams(files: [XFile(widget.summary.jsonPath)]),
    );
  }

  Future<void> _copyCsvToClipboard() async {
    final languageCode = context.read<SettingsStorage>().uiLanguage;
    final content =
        await context.read<HistoryRepository>().loadCsvContent(widget.summary);
    await Clipboard.setData(ClipboardData(text: content));
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(AppStrings.copiedCsvContent(languageCode))),
    );
  }

  Future<void> _copyJsonToClipboard() async {
    final languageCode = context.read<SettingsStorage>().uiLanguage;
    final content =
        await context.read<HistoryRepository>().loadJsonContent(widget.summary);
    await Clipboard.setData(ClipboardData(text: content));
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(AppStrings.copiedJsonContent(languageCode))),
    );
  }

  Future<Uint8List?> _captureChartPngBytes() async {
    final boundaryContext = _chartBoundaryKey.currentContext;
    if (boundaryContext == null) return null;
    final render = boundaryContext.findRenderObject();
    if (render is! RenderRepaintBoundary) return null;

    final image = await render.toImage(pixelRatio: 3.0);
    final byteData = await image.toByteData(format: ui.ImageByteFormat.png);
    if (byteData == null) return null;
    return byteData.buffer.asUint8List();
  }

  Future<File?> _saveChartPngToScreenshots() async {
    final mediaExport =
        Platform.isAndroid ? context.read<MediaExportService>() : null;
    final bytes = await _captureChartPngBytes();
    if (bytes == null) return null;
    final filename = 'hr_chart_${widget.summary.startedAt.millisecondsSinceEpoch}.png';
    if (Platform.isAndroid) {
      final savedRef = await mediaExport!.savePngToGallery(
        bytes: bytes,
        fileName: filename,
        albumName: 'CardioApp Export',
      );
      if (savedRef == null || savedRef.isEmpty) {
        return null;
      }
      // Return a pseudo-file reference for consistent UI messaging.
      return File(savedRef);
    }

    final fallback = await getApplicationDocumentsDirectory();
    final targetDir = Directory('${fallback.path}/CardioApp Export');
    if (!await targetDir.exists()) {
      await targetDir.create(recursive: true);
    }
    final outFile = File('${targetDir.path}/$filename');
    await outFile.writeAsBytes(bytes, flush: true);
    return outFile;
  }

  Future<File?> _saveChartPngToLocalExport() async {
    final bytes = await _captureChartPngBytes();
    if (bytes == null) return null;
    final fallback = await getApplicationDocumentsDirectory();
    final targetDir = Directory('${fallback.path}/CardioApp Export');
    if (!await targetDir.exists()) {
      await targetDir.create(recursive: true);
    }
    final filename = 'hr_chart_${widget.summary.startedAt.millisecondsSinceEpoch}.png';
    final outFile = File('${targetDir.path}/$filename');
    await outFile.writeAsBytes(bytes, flush: true);
    return outFile;
  }

  Future<void> _exportChartPngFile() async {
    final languageCode = context.read<SettingsStorage>().uiLanguage;
    try {
      final file = await _saveChartPngToScreenshots();
      if (!mounted) return;
      if (file == null) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(AppStrings.chartPngSaveFailed(languageCode))),
        );
        return;
      }
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(AppStrings.chartPngSaved(languageCode, file.path))),
      );
    } catch (_) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(AppStrings.chartPngSaveFailed(languageCode))),
      );
    }
  }

  Future<void> _shareChartPngFile() async {
    final file = await _saveChartPngToLocalExport();
    if (file == null) return;
    await SharePlus.instance.share(
      ShareParams(files: [XFile(file.path)]),
    );
  }

  Future<void> _deleteCurrentSession() async {
    final languageCode = context.read<SettingsStorage>().uiLanguage;
    final repository = context.read<HistoryRepository>();
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(AppStrings.deleteLogQuestion(languageCode)),
        content: Text(AppStrings.deleteLogDescription(languageCode)),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: Text(AppStrings.cancel(languageCode)),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: Text(AppStrings.delete(languageCode)),
          ),
        ],
      ),
    );
    if (confirmed != true) return;
    await repository.deleteSession(widget.summary);
    if (!mounted) return;
    Navigator.pop(context);
  }

  Future<void> _showFileActionsSheet() async {
    final languageCode = context.read<SettingsStorage>().uiLanguage;
    final action = await showHistoryFileActionsSheet(
      context: context,
      languageCode: languageCode,
      includePngActions: true,
    );
    if (action == null) return;
    switch (action) {
      case HistoryFileAction.shareCsv:
        await _shareCsv();
        break;
      case HistoryFileAction.shareJson:
        await _shareJson();
        break;
      case HistoryFileAction.sharePng:
        await _shareChartPngFile();
        break;
      case HistoryFileAction.exportPng:
        await _exportChartPngFile();
        break;
      case HistoryFileAction.copyCsv:
        await _copyCsvToClipboard();
        break;
      case HistoryFileAction.copyJson:
        await _copyJsonToClipboard();
        break;
      case HistoryFileAction.delete:
        await _deleteCurrentSession();
        break;
    }
  }

  @override
  Widget build(BuildContext context) {
    final languageCode = context.read<SettingsStorage>().uiLanguage;
    return Scaffold(
      appBar: AppBar(
        title: Text(AppStrings.sessionDetails(languageCode)),
        actions: [
          IconButton(
            onPressed: _showFileActionsSheet,
            icon: const Icon(Icons.more_vert),
            tooltip: AppStrings.export(languageCode),
          ),
        ],
      ),
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
              RepaintBoundary(
                key: _chartBoundaryKey,
                child: SizedBox(
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
                                  style: const TextStyle(
                                      fontSize: 10, color: Colors.white70),
                                );
                              }
                              if ((value - last / 2).abs() < 0.5) {
                                return Text(
                                  AppStrings.middle(languageCode),
                                  style: const TextStyle(
                                      fontSize: 10, color: Colors.white70),
                                );
                              }
                              if ((value - last).abs() < 0.5) {
                                return Text(
                                  AppStrings.finish(languageCode),
                                  style: const TextStyle(
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
                          color: Colors.white.withValues(alpha: 0.08),
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
