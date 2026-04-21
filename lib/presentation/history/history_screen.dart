import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:share_plus/share_plus.dart';

import '../../core/app_strings.dart';
import '../../data/storage/history_repository.dart';
import '../../data/storage/settings_storage.dart';
import 'history_file_actions.dart';
import 'session_detail_screen.dart';

class HistoryScreen extends StatefulWidget {
  const HistoryScreen({super.key});

  @override
  State<HistoryScreen> createState() => _HistoryScreenState();
}

class _HistoryScreenState extends State<HistoryScreen> {
  late Future<List<SessionSummary>> _future;
  String? _logsPath;
  final Set<String> _selectedIds = <String>{};

  bool get _isSelectionMode => _selectedIds.isNotEmpty;

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
    final path = await context.read<HistoryRepository>().logsFolderPath();
    if (!mounted) return;
    setState(() {
      _logsPath = path;
      _future = context.read<HistoryRepository>().loadSummaries();
    });
  }

  Future<void> _deleteSession(SessionSummary summary) async {
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

    await repository.deleteSession(summary);
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(AppStrings.logDeleted(languageCode))),
    );
    await _reload();
  }

  Future<void> _deleteAllSessions() async {
    final languageCode = context.read<SettingsStorage>().uiLanguage;
    final repository = context.read<HistoryRepository>();
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

    final count = await repository.deleteAllSessions();
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(AppStrings.deletedFiles(languageCode, count))),
    );
    await _reload();
  }

  Future<void> _copyCsvContent(SessionSummary summary) async {
    final languageCode = context.read<SettingsStorage>().uiLanguage;
    final repository = context.read<HistoryRepository>();
    final content = await repository.loadCoachSummaryContent(summary);
    await Clipboard.setData(ClipboardData(text: content));
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(AppStrings.copiedCsvContent(languageCode))),
    );
  }

  Future<void> _copyJsonContent(SessionSummary summary) async {
    final languageCode = context.read<SettingsStorage>().uiLanguage;
    final repository = context.read<HistoryRepository>();
    final content = await repository.loadCoachSummaryContent(summary);
    await Clipboard.setData(ClipboardData(text: content));
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(AppStrings.copiedJsonContent(languageCode))),
    );
  }

  void _toggleSelected(SessionSummary summary) {
    setState(() {
      if (_selectedIds.contains(summary.id)) {
        _selectedIds.remove(summary.id);
      } else {
        _selectedIds.add(summary.id);
      }
    });
  }

  void _clearSelection() {
    setState(_selectedIds.clear);
  }

  List<SessionSummary> _selectedSessions(List<SessionSummary> sessions) {
    return sessions.where((s) => _selectedIds.contains(s.id)).toList();
  }

  Future<void> _handleSingleAction(SessionSummary summary) async {
    final languageCode = context.read<SettingsStorage>().uiLanguage;
    final action = await showHistoryFileActionsSheet(
      context: context,
      languageCode: languageCode,
    );
    if (action == null) return;
    switch (action) {
      case HistoryFileAction.shareCsv:
        await SharePlus.instance.share(
          ShareParams(files: [XFile(summary.coachSummaryPath)]),
        );
        break;
      case HistoryFileAction.shareJson:
        await SharePlus.instance.share(
          ShareParams(files: [XFile(summary.coachSummaryPath)]),
        );
        break;
      case HistoryFileAction.sharePng:
      case HistoryFileAction.exportPng:
        // PNG actions are shown only in session details.
        break;
      case HistoryFileAction.copyCsv:
        await _copyCsvContent(summary);
        break;
      case HistoryFileAction.copyJson:
        await _copyJsonContent(summary);
        break;
      case HistoryFileAction.delete:
        await _deleteSession(summary);
        break;
    }
  }

  Future<void> _bulkShare(List<SessionSummary> selected) async {
    final languageCode = context.read<SettingsStorage>().uiLanguage;
    final action = await showModalBottomSheet<HistoryFileAction>(
      context: context,
      builder: (ctx) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              leading: const Icon(Icons.table_chart_outlined),
              title: Text(AppStrings.shareCsv(languageCode)),
              onTap: () => Navigator.pop(ctx, HistoryFileAction.shareCsv),
            ),
            ListTile(
              leading: const Icon(Icons.data_object),
              title: Text(AppStrings.shareJson(languageCode)),
              onTap: () => Navigator.pop(ctx, HistoryFileAction.shareJson),
            ),
          ],
        ),
      ),
    );
    if (action == null) return;
    final files = action == HistoryFileAction.shareCsv
        ? selected.map((s) => XFile(s.coachSummaryPath)).toList()
        : selected.map((s) => XFile(s.coachSummaryPath)).toList();
    await SharePlus.instance.share(ShareParams(files: files));
  }

  Future<void> _bulkCopy(List<SessionSummary> selected) async {
    final languageCode = context.read<SettingsStorage>().uiLanguage;
    final repository = context.read<HistoryRepository>();
    final action = await showModalBottomSheet<HistoryFileAction>(
      context: context,
      builder: (ctx) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              leading: const Icon(Icons.content_copy_outlined),
              title: Text(AppStrings.copyCsvContent(languageCode)),
              onTap: () => Navigator.pop(ctx, HistoryFileAction.copyCsv),
            ),
            ListTile(
              leading: const Icon(Icons.copy_all_outlined),
              title: Text(AppStrings.copyJsonContent(languageCode)),
              onTap: () => Navigator.pop(ctx, HistoryFileAction.copyJson),
            ),
          ],
        ),
      ),
    );
    if (action == null) return;

    final sb = StringBuffer();
    for (final s in selected) {
      final content = action == HistoryFileAction.copyCsv
          ? await repository.loadCoachSummaryContent(s)
          : await repository.loadCoachSummaryContent(s);
      sb.writeln('=== ${s.id} ===');
      sb.writeln(content);
      sb.writeln();
    }
    await Clipboard.setData(ClipboardData(text: sb.toString()));
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          action == HistoryFileAction.copyCsv
              ? AppStrings.copiedBulkCsvContent(languageCode, selected.length)
              : AppStrings.copiedBulkJsonContent(languageCode, selected.length),
        ),
      ),
    );
  }

  Future<void> _bulkDelete(List<SessionSummary> selected) async {
    final languageCode = context.read<SettingsStorage>().uiLanguage;
    final repository = context.read<HistoryRepository>();
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(AppStrings.bulkDeleteTitle(languageCode, selected.length)),
        content: Text(AppStrings.bulkDeleteDescription(languageCode)),
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
    for (final s in selected) {
      await repository.deleteSession(s);
    }
    if (!mounted) return;
    _clearSelection();
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
        title: Text(
          _isSelectionMode
              ? AppStrings.selectedCount(languageCode, _selectedIds.length)
              : AppStrings.historyTitle(languageCode),
        ),
        actions: _isSelectionMode
            ? [
                IconButton(
                  tooltip: AppStrings.selectAll(languageCode),
                  icon: const Icon(Icons.select_all),
                  onPressed: () async {
                    final sessions = await _future;
                    if (!mounted) return;
                    setState(() {
                      _selectedIds
                        ..clear()
                        ..addAll(sessions.map((s) => s.id));
                    });
                  },
                ),
                IconButton(
                  tooltip: AppStrings.bulkCopy(languageCode),
                  icon: const Icon(Icons.copy_all_outlined),
                  onPressed: () async {
                    final sessions = await _future;
                    final selected = _selectedSessions(sessions);
                    if (selected.isEmpty) return;
                    await _bulkCopy(selected);
                  },
                ),
                IconButton(
                  tooltip: AppStrings.bulkExport(languageCode),
                  icon: const Icon(Icons.ios_share),
                  onPressed: () async {
                    final sessions = await _future;
                    final selected = _selectedSessions(sessions);
                    if (selected.isEmpty) return;
                    await _bulkShare(selected);
                  },
                ),
                IconButton(
                  tooltip: AppStrings.bulkDelete(languageCode),
                  icon: const Icon(Icons.delete_outline),
                  onPressed: () async {
                    final sessions = await _future;
                    final selected = _selectedSessions(sessions);
                    if (selected.isEmpty) return;
                    await _bulkDelete(selected);
                  },
                ),
                IconButton(
                  tooltip: AppStrings.clearSelection(languageCode),
                  icon: const Icon(Icons.close),
                  onPressed: _clearSelection,
                ),
              ]
            : [
                IconButton(
                  icon: const Icon(Icons.delete_sweep),
                  onPressed: _deleteAllSessions,
                ),
                IconButton(
                  icon: const Icon(Icons.folder),
                  onPressed: () async {
                    final repository = context.read<HistoryRepository>();
                    final messenger = ScaffoldMessenger.of(context);
                    final path = _logsPath ?? await repository.logsFolderPath();
                    if (!context.mounted) return;
                    await Clipboard.setData(ClipboardData(text: path));
                    messenger.showSnackBar(
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
                      leading: _isSelectionMode
                          ? Checkbox(
                              value: _selectedIds.contains(s.id),
                              onChanged: (_) => _toggleSelected(s),
                            )
                          : null,
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
                      onTap: _isSelectionMode
                          ? () => _toggleSelected(s)
                          : () {
                              Navigator.push(
                                context,
                                MaterialPageRoute(
                                  builder: (_) => SessionDetailScreen(summary: s),
                                ),
                              );
                            },
                      onLongPress: () => _toggleSelected(s),
                      trailing: _isSelectionMode
                          ? null
                          : IconButton(
                              icon: const Icon(Icons.more_vert),
                              onPressed: () => _handleSingleAction(s),
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
        color: Colors.white.withValues(alpha: 0.04),
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
