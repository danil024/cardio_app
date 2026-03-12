import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:share_plus/share_plus.dart';

import '../../core/app_strings.dart';
import '../../data/storage/history_repository.dart';
import '../../data/storage/settings_storage.dart';
import 'session_detail_screen.dart';

class HistoryScreen extends StatefulWidget {
  const HistoryScreen({super.key});

  @override
  State<HistoryScreen> createState() => _HistoryScreenState();
}

class _HistoryScreenState extends State<HistoryScreen> {
  late Future<List<SessionSummary>> _future;
  String? _logsPath;

  @override
  void initState() {
    super.initState();
    _future = context.read<HistoryRepository>().loadSummaries();
    context.read<HistoryRepository>().logsFolderPath().then((value) {
      if (mounted) {
        setState(() => _logsPath = value);
      }
    });
  }

  Future<void> _reload() async {
    setState(() {
      _future = context.read<HistoryRepository>().loadSummaries();
    });
  }

  Future<void> _deleteSession(SessionSummary summary) async {
    final languageCode = context.read<SettingsStorage>().uiLanguage;
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

    await context.read<HistoryRepository>().deleteSession(summary);
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(AppStrings.logDeleted(languageCode))),
    );
    await _reload();
  }

  Future<void> _deleteAllSessions() async {
    final languageCode = context.read<SettingsStorage>().uiLanguage;
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(AppStrings.deleteAllTitle(languageCode)),
        content: Text(AppStrings.deleteAllDescription(languageCode)),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: Text(AppStrings.cancel(languageCode)),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: Text(AppStrings.deleteAll(languageCode)),
          ),
        ],
      ),
    );
    if (confirmed != true) return;

    final count = await context.read<HistoryRepository>().deleteAllSessions();
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(AppStrings.deletedFiles(languageCode, count))),
    );
    await _reload();
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
      appBar: AppBar(
        title: Text(AppStrings.historyTitle(languageCode)),
        actions: [
          IconButton(
            icon: const Icon(Icons.delete_sweep),
            onPressed: _deleteAllSessions,
          ),
          IconButton(
            icon: const Icon(Icons.folder),
            onPressed: () async {
              final path = _logsPath ??
                  await context.read<HistoryRepository>().logsFolderPath();
              if (!context.mounted) return;
              await Clipboard.setData(ClipboardData(text: path));
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(
                    content:
                        Text(AppStrings.copiedLogsPath(languageCode, path))),
              );
            },
          ),
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: _reload,
          ),
        ],
      ),
      body: FutureBuilder<List<SessionSummary>>(
        future: _future,
        builder: (context, snapshot) {
          if (!snapshot.hasData) {
            return const Center(child: CircularProgressIndicator());
          }
          final sessions = snapshot.data!;
          if (sessions.isEmpty) {
            return Column(
              children: [
                _buildLogsHint(languageCode),
                Expanded(
                  child:
                      Center(child: Text(AppStrings.noSessions(languageCode))),
                ),
              ],
            );
          }
          return Column(
            children: [
              _buildLogsHint(languageCode),
              Expanded(
                child: ListView.separated(
                  itemCount: sessions.length,
                  separatorBuilder: (_, __) => const Divider(height: 1),
                  itemBuilder: (context, index) {
                    final s = sessions[index];
                    return ListTile(
                      title: Text(
                        '${s.startedAt.day.toString().padLeft(2, '0')}.'
                        '${s.startedAt.month.toString().padLeft(2, '0')}.'
                        '${s.startedAt.year} '
                        '${s.startedAt.hour.toString().padLeft(2, '0')}:'
                        '${s.startedAt.minute.toString().padLeft(2, '0')}',
                      ),
                      subtitle: Text(
                        '${AppStrings.durationLabel(languageCode)}: ${_formatDuration(s.duration)} | '
                        '${AppStrings.hrAvgMaxMin(languageCode, s.averageHr, s.maxHr, s.minHr)}',
                      ),
                      onTap: () {
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (_) => SessionDetailScreen(summary: s),
                          ),
                        );
                      },
                      trailing: PopupMenuButton<String>(
                        onSelected: (value) async {
                          if (value == 'copy') {
                            await Clipboard.setData(
                                ClipboardData(text: s.csvPath));
                            if (context.mounted) {
                              ScaffoldMessenger.of(context).showSnackBar(
                                SnackBar(
                                  content: Text(
                                      AppStrings.copiedCsvPath(languageCode)),
                                ),
                              );
                            }
                          } else if (value == 'share') {
                            await Share.shareXFiles([XFile(s.csvPath)]);
                          } else if (value == 'delete') {
                            await _deleteSession(s);
                          }
                        },
                        itemBuilder: (_) => [
                          PopupMenuItem(
                            value: 'copy',
                            child: Text(AppStrings.copyCsvPath(languageCode)),
                          ),
                          PopupMenuItem(
                            value: 'share',
                            child: Text(AppStrings.shareCsv(languageCode)),
                          ),
                          PopupMenuItem(
                            value: 'delete',
                            child: Text(AppStrings.deleteLog(languageCode)),
                          ),
                        ],
                      ),
                    );
                  },
                ),
              ),
            ],
          );
        },
      ),
    );
  }

  Widget _buildLogsHint(String languageCode) {
    final path = _logsPath ?? '...';
    return Container(
      width: double.infinity,
      margin: const EdgeInsets.fromLTRB(12, 12, 12, 6),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.04),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.white24),
      ),
      child: Text(
        AppStrings.logsHint(languageCode, path),
        style: const TextStyle(fontSize: 12, color: Colors.white70),
      ),
    );
  }
}
