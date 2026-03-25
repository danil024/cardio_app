import 'package:flutter/material.dart';

import '../../core/app_strings.dart';

enum HistoryFileAction {
  shareCsv,
  shareJson,
  sharePng,
  exportPng,
  copyCsv,
  copyJson,
  delete,
}

Future<HistoryFileAction?> showHistoryFileActionsSheet({
  required BuildContext context,
  required String languageCode,
  bool includePngActions = false,
}) {
  return showModalBottomSheet<HistoryFileAction>(
    context: context,
    builder: (ctx) {
      return SafeArea(
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
            if (includePngActions)
              ListTile(
                leading: const Icon(Icons.image_outlined),
                title: Text(AppStrings.exportChartPngFile(languageCode)),
                onTap: () => Navigator.pop(ctx, HistoryFileAction.exportPng),
              ),
            if (includePngActions)
              ListTile(
                leading: const Icon(Icons.ios_share),
                title: Text(AppStrings.exportChartPngShare(languageCode)),
                onTap: () => Navigator.pop(ctx, HistoryFileAction.sharePng),
              ),
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
            const Divider(height: 1),
            ListTile(
              leading: const Icon(Icons.delete_outline),
              title: Text(AppStrings.deleteLog(languageCode)),
              onTap: () => Navigator.pop(ctx, HistoryFileAction.delete),
            ),
          ],
        ),
      );
    },
  );
}

