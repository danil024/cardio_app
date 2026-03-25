import 'dart:convert';
import 'dart:io';

import 'package:path_provider/path_provider.dart';

import '../../core/constants.dart';
import '../../domain/models/hr_session.dart';
import 'settings_storage.dart';

/// Сохранение сессий в CSV и JSON
class SessionStorage {
  SessionStorage({SettingsStorage? settingsStorage})
      : _settingsStorage = settingsStorage;

  final SettingsStorage? _settingsStorage;

  Future<Directory> _getSessionsDir() async {
    final customPath = _settingsStorage?.sessionsCustomDirPath;
    if (customPath != null && customPath.isNotEmpty) {
      final customDir = Directory(customPath);
      try {
        if (!await customDir.exists()) {
          await customDir.create(recursive: true);
        }
        final probe = File('${customDir.path}/.write_test');
        await probe.writeAsString('ok');
        await probe.delete();
        return customDir;
      } catch (_) {
        // Fall back to default path strategy when custom path is unavailable.
      }
    }

    if (Platform.isAndroid) {
      // Пробуем сохранить логи в понятный публичный каталог телефона.
      final publicDir = Directory(AppConstants.androidPublicLogsFolder);
      try {
        if (!await publicDir.exists()) {
          await publicDir.create(recursive: true);
        }
        final probe = File('${publicDir.path}/.write_test');
        await probe.writeAsString('ok');
        await probe.delete();
        return publicDir;
      } catch (_) {
        // Если Android запретил запись в корень, используем внешний каталог приложения.
      }

      final external = await getExternalStorageDirectory();
      if (external != null) {
        final dir =
            Directory('${external.path}/${AppConstants.sessionsFolder}');
        if (!await dir.exists()) {
          await dir.create(recursive: true);
        }
        return dir;
      }
    }

    final base = await getApplicationDocumentsDirectory();
    final dir = Directory('${base.path}/${AppConstants.sessionsFolder}');
    if (!await dir.exists()) {
      await dir.create(recursive: true);
    }
    return dir;
  }

  Future<Directory> getSessionsDirectory() => _getSessionsDir();

  /// Сохранить сессию в CSV и JSON
  Future<String> saveSession(HrSession session) async {
    final dir = await _getSessionsDir();
    final baseName =
        '${session.id}_${session.startedAt.millisecondsSinceEpoch}';

    await _saveCsv(dir, baseName, session);
    await _saveJson(dir, baseName, session);

    return dir.path;
  }

  Future<void> _saveCsv(
      Directory dir, String baseName, HrSession session) async {
    final file = File('${dir.path}/$baseName.csv');
    final sb = StringBuffer();
    sb.writeln('timestamp,heart_rate,bpm');

    for (final r in session.readings) {
      sb.writeln(
        '${r.timestamp.toIso8601String()},${r.heartRate},${r.heartRate}',
      );
    }

    await file.writeAsString(sb.toString());
  }

  Future<void> _saveJson(
      Directory dir, String baseName, HrSession session) async {
    final file = File('${dir.path}/$baseName.json');
    final json = session.toJson();
    await file.writeAsString(const JsonEncoder.withIndent('  ').convert(json));
  }

  Future<List<File>> listJsonSessions() async {
    final dir = await _getSessionsDir();
    if (!await dir.exists()) return [];
    final files = <File>[];
    await for (final entity in dir.list(followLinks: false)) {
      if (entity is File && entity.path.endsWith('.json')) {
        files.add(entity);
      }
    }
    files.sort((a, b) => b.lastModifiedSync().compareTo(a.lastModifiedSync()));
    return files;
  }

  /// Размер хранилища сессий в байтах
  Future<int> getStorageSize() async {
    final dir = await _getSessionsDir();
    if (!await dir.exists()) return 0;
    int total = 0;
    await for (final entity in dir.list(recursive: true, followLinks: false)) {
      if (entity is File) {
        total += await entity.length();
      }
    }
    return total;
  }

  /// Нужно ли предложить очистку (превышен порог)
  Future<bool> shouldSuggestCleanup() async {
    final size = await getStorageSize();
    return size >= AppConstants.storageCleanupThresholdBytes;
  }

  /// Удалить старые сессии (оставить последние N по дате)
  Future<int> clearOldSessions({int keepLast = 20}) async {
    final dir = await _getSessionsDir();
    if (!await dir.exists()) return 0;

    final sessions = <String, List<File>>{};
    await for (final entity in dir.list(followLinks: false)) {
      if (entity is File &&
          (entity.path.endsWith('.csv') || entity.path.endsWith('.json'))) {
        final baseName = entity.path
            .split('/')
            .last
            .replaceAll(RegExp(r'\.(csv|json)$'), '');
        sessions.putIfAbsent(baseName, () => []).add(entity);
      }
    }

    final sorted = sessions.keys.toList()
      ..sort((a, b) {
        final filesA = sessions[a]!;
        final filesB = sessions[b]!;
        final timeA = filesA.first.lastModifiedSync();
        final timeB = filesB.first.lastModifiedSync();
        return timeB.compareTo(timeA);
      });

    if (sorted.length <= keepLast) return 0;

    var deleted = 0;
    for (var i = keepLast; i < sorted.length; i++) {
      for (final f in sessions[sorted[i]]!) {
        await f.delete();
        deleted++;
      }
    }
    return deleted;
  }
}
