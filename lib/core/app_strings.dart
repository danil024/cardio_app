import '../domain/models/hr_zones.dart';

class AppStrings {
  AppStrings._();

  static const String en = 'en';
  static const String ru = 'ru';

  static bool isRu(String languageCode) => languageCode == ru;

  static String appTitle(String languageCode) =>
      isRu(languageCode) ? 'Кардио пульс' : 'Cardio Pulse';

  static String settingsTitle(String languageCode) =>
      isRu(languageCode) ? 'Настройки' : 'Settings';

  static String done(String languageCode) =>
      isRu(languageCode) ? 'Готово' : 'Done';
  static String save(String languageCode) =>
      isRu(languageCode) ? 'Сохранить' : 'Save';

  static String age(String languageCode) =>
      isRu(languageCode) ? 'Возраст' : 'Age';
  static String heartRateZones(String languageCode) => isRu(languageCode)
      ? 'Зоны пульса и целевая зона'
      : 'Heart rate zones and target zone';
  static String currentTargetZone(String languageCode, String label) =>
      isRu(languageCode)
          ? 'Текущая целевая зона: $label.'
          : 'Current target zone: $label.';
  static String sensorPollRate(String languageCode) => isRu(languageCode)
      ? 'Скорость опроса датчика'
      : 'Sensor polling interval';
  static String chartWindow(String languageCode) =>
      isRu(languageCode) ? 'Окно графика (минуты)' : 'Chart window (minutes)';
  static String testMode(String languageCode) =>
      isRu(languageCode) ? 'Режим теста' : 'Test mode';
  static String startTest(String languageCode) =>
      isRu(languageCode) ? 'Запустить тест' : 'Start test';
  static String stopTest(String languageCode) =>
      isRu(languageCode) ? 'Остановить тест' : 'Stop test';
  static String keepScreenOnTitle(String languageCode) => isRu(languageCode)
      ? 'Не блокировать экран при тренировке'
      : 'Keep screen on during workout';
  static String keepScreenOnSubtitle(String languageCode) => isRu(languageCode)
      ? 'Экран остаётся включённым при подключённом пульсометре'
      : 'Screen stays on while heart monitor is connected';
  static String alerts(String languageCode) =>
      isRu(languageCode) ? 'Оповещения' : 'Alerts';
  static String soundAlerts(String languageCode) =>
      isRu(languageCode) ? 'Звуковые сигналы' : 'Sound alerts';
  static String ttsAlerts(String languageCode) =>
      isRu(languageCode) ? 'Голосовые сообщения (TTS)' : 'Voice messages (TTS)';
  static String rangeAlertTitle(String languageCode) =>
      isRu(languageCode) ? 'Диапазонный алерт по пульсу' : 'Heart rate range alert';
  static String rangeAlertSubtitle(String languageCode) => isRu(languageCode)
      ? 'Сигнал, если пульс ниже минимума или выше максимума'
      : 'Alert when HR is below minimum or above maximum';
  static String allowedRangeLabel(String languageCode, int minBpm, int maxBpm) =>
      isRu(languageCode)
          ? 'Допустимый диапазон: $minBpm-$maxBpm уд/мин'
          : 'Allowed range: $minBpm-$maxBpm bpm';
  static String timerPickerTitle(String languageCode) =>
      isRu(languageCode) ? 'Время (мм:сс)' : 'Time (mm:ss)';
  static String interfaceLanguage(String languageCode) => isRu(languageCode)
      ? 'Язык интерфейса и голоса'
      : 'Interface and voice language';
  static String voiceLanguage(String languageCode) =>
      isRu(languageCode) ? 'Язык голоса' : 'Voice language';
  static String english(String languageCode) =>
      isRu(languageCode) ? 'Английский' : 'English';
  static String russian(String languageCode) =>
      isRu(languageCode) ? 'Русский' : 'Russian';

  static String disconnected(String languageCode) =>
      isRu(languageCode) ? 'Отключено' : 'Disconnected';
  static String scanning(String languageCode) =>
      isRu(languageCode) ? 'Поиск...' : 'Scanning...';
  static String connecting(String languageCode) =>
      isRu(languageCode) ? 'Подключение...' : 'Connecting...';
  static String connected(String languageCode) =>
      isRu(languageCode) ? 'Подключено' : 'Connected';
  static String error(String languageCode) =>
      isRu(languageCode) ? 'Ошибка' : 'Error';
  static String disconnect(String languageCode) =>
      isRu(languageCode) ? 'Отключить' : 'Disconnect';
  static String connect(String languageCode) =>
      isRu(languageCode) ? 'Подключить' : 'Connect';

  static String historyTitle(String languageCode) =>
      isRu(languageCode) ? 'История тренировок' : 'Workout history';
  static String noSessions(String languageCode) =>
      isRu(languageCode) ? 'Сессий пока нет' : 'No sessions yet';
  static String deleteLogQuestion(String languageCode) =>
      isRu(languageCode) ? 'Удалить лог?' : 'Delete log?';
  static String deleteLogDescription(String languageCode) => isRu(languageCode)
      ? 'Будут удалены CSV и JSON файлы этой сессии.'
      : 'CSV and JSON files for this session will be deleted.';
  static String cancel(String languageCode) =>
      isRu(languageCode) ? 'Отмена' : 'Cancel';
  static String delete(String languageCode) =>
      isRu(languageCode) ? 'Удалить' : 'Delete';
  static String deleteAll(String languageCode) =>
      isRu(languageCode) ? 'Удалить все' : 'Delete all';
  static String deleteAllTitle(String languageCode) =>
      isRu(languageCode) ? 'Удалить все логи?' : 'Delete all logs?';
  static String deleteAllDescription(String languageCode) => isRu(languageCode)
      ? 'Все CSV и JSON файлы истории будут удалены безвозвратно.'
      : 'All CSV and JSON history files will be deleted permanently.';
  static String logDeleted(String languageCode) =>
      isRu(languageCode) ? 'Лог удалён' : 'Log deleted';
  static String deletedFiles(String languageCode, int count) =>
      isRu(languageCode) ? 'Удалено файлов: $count' : 'Deleted files: $count';
  static String copiedLogsPath(String languageCode, String path) =>
      isRu(languageCode)
          ? 'Путь к логам скопирован: $path'
          : 'Logs path copied: $path';
  static String copiedCsvPath(String languageCode) =>
      isRu(languageCode) ? 'Путь CSV скопирован' : 'CSV path copied';
  static String copyCsvPath(String languageCode) =>
      isRu(languageCode) ? 'Копировать путь CSV' : 'Copy CSV path';
  static String shareCsv(String languageCode) =>
      isRu(languageCode) ? 'Переслать CSV' : 'Share CSV';
  static String deleteLog(String languageCode) =>
      isRu(languageCode) ? 'Удалить лог' : 'Delete log';
  static String logsHint(String languageCode, String path) => isRu(languageCode)
      ? 'Логи сохраняются автоматически при остановке/отключении сессии.\n'
          'Для каждой сессии создаются 2 файла: CSV и JSON.\n'
          'Папка логов: $path'
      : 'Logs are saved automatically when the session stops/disconnects.\n'
          'Each session creates 2 files: CSV and JSON.\n'
          'Logs folder: $path';
  static String durationLabel(String languageCode) =>
      isRu(languageCode) ? 'Длительность' : 'Duration';
  static String hrAvgMaxMin(String languageCode, int avg, int max, int min) =>
      isRu(languageCode)
          ? 'Пульс ср/макс/мин: $avg/$max/$min'
          : 'HR avg/max/min: $avg/$max/$min';

  static String sessionDetails(String languageCode) =>
      isRu(languageCode) ? 'Детали сессии' : 'Session details';
  static String insufficientData(String languageCode) =>
      isRu(languageCode) ? 'Недостаточно данных' : 'Not enough data';
  static String start(String languageCode) =>
      isRu(languageCode) ? 'старт' : 'start';
  static String middle(String languageCode) =>
      isRu(languageCode) ? 'середина' : 'middle';
  static String finish(String languageCode) =>
      isRu(languageCode) ? 'финиш' : 'finish';
  static String timeInZones(String languageCode) =>
      isRu(languageCode) ? 'Время в зонах' : 'Time in zones';

  static String zoneName(String languageCode, HrZoneType type) {
    final ru = isRu(languageCode);
    switch (type) {
      case HrZoneType.recovery:
        return ru ? 'Восстановление' : 'Recovery';
      case HrZoneType.fatBurning:
        return ru ? 'Жиросжигание' : 'Fat-burning';
      case HrZoneType.aerobic:
        return ru ? 'Аэробная' : 'Aerobic';
      case HrZoneType.anaerobic:
        return ru ? 'Анаэробная' : 'Anaerobic';
      case HrZoneType.max:
        return ru ? 'Максимум' : 'Maximum';
    }
  }
}
