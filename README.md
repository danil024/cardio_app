# Cardio Pulse

Тренировочное мобильное приложение для BLE-пульсометра  
`GEOID HS500` и совместимых heart-rate датчиков.

## Возможности

- BLE подключение к HR-датчику с устойчивым fallback-сканированием.
- Крупный текущий BPM поверх графика.
- Детальный график пульса с сеткой и динамическим диапазоном.
- 5 зон пульса: `Recovery`, `Fat-burning`, `Aerobic`, `Anaerobic`, `Maximum`.
- Цветовая индикация зон и danger-сценарий.
- Автосохранение тренировок в `CSV` и `JSON`.
- История сессий: просмотр и удаление логов.
- Таймер/секундомер с iOS-style roller (`mm:ss`).
- Медиа-кнопки (`prev/play/pause/next`) через системные Android media events.
- Звуковые + голосовые уведомления (EN/RU), связанный язык UI/TTS.

## Быстрый старт (разработка)

```bash
flutter pub get
flutter run
```

## Сборка release APK

```bash
flutter build apk --release
```

Готовый файл:

- `build/app/outputs/flutter-apk/app-release.apk`

## Скачать готовые файлы

Готовые файлы хранятся в `releases/`:

- `releases/CardioPulse-v1.0.0-release.apk`
- `releases/CardioPulse-v1.0.0-release.aab`
- `releases/CardioPulse-iOS-source-v1.0.0.zip`

Прямые ссылки:

- [CardioPulse-v1.0.0-release.apk](https://github.com/danil024/cardio_app/raw/main/releases/CardioPulse-v1.0.0-release.apk)
- [CardioPulse-v1.0.0-release.aab](https://github.com/danil024/cardio_app/raw/main/releases/CardioPulse-v1.0.0-release.aab)
- [CardioPulse-iOS-source-v1.0.0.zip](https://github.com/danil024/cardio_app/raw/main/releases/CardioPulse-iOS-source-v1.0.0.zip)

Важно:

- `APK/AAB` — готовые Android-артефакты.
- Для iOS из Linux нельзя собрать `.ipa` (нужен macOS + Xcode).
- Для iOS добавлен готовый source-архив для сборки на Mac.
- История изменений: `CHANGELOG.md`.
- Текущие релиз-заметки: `RELEASE_NOTES_v1.0.0.md`.

## Установка на Android через ADB

```bash
adb install -r "build/app/outputs/flutter-apk/app-release.apk"
```

## Требования

- Flutter SDK >= 3.2.0
- Android (основная поддержка)
- iOS слой подготовлен архитектурно, но Android является приоритетным таргетом

## Структура проекта

- `lib/data/ble/` — BLE сканирование/подключение/чтение HR
- `lib/data/audio/` — тональные и голосовые уведомления
- `lib/data/storage/` — настройки, сессии, история
- `lib/data/media/` — Android media controls
- `lib/domain/` — модели и расчет зон
- `lib/presentation/` — Home / Settings / History UI
- `releases/` — готовые скачиваемые артефакты
