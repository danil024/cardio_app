# Cardio Pulse

Мобильное приложение для тренировок с BLE-пульсометром (GEOID HS500 и совместимые HRM).

## Что умеет сейчас

- Подключение к BLE датчику пульса с fallback-логикой сканирования
- Крупное текущее BPM поверх графика
- Временной график пульса с масштабируемой шкалой и сеткой
- Пять зон пульса: recovery / fat-burning / aerobic / anaerobic / maximum
- Цветовая индикация по зоне и отдельный danger-сценарий
- Автосохранение тренировок в CSV и JSON
- История сессий: просмотр, удаление одной или всех записей
- Таймер/секундомер с iOS-style roller (`mm:ss`)
- Медиа-кнопки (prev/play/pause/next) через системные Android media key events
- Звуковые и голосовые уведомления (EN/RU)
- Связанный переключатель языка интерфейса и TTS

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

## APK для скачивания

Готовая сборка хранится в репозитории:

- `releases/CardioPulse-v1.0.0-release.apk`

После публикации изменений файл можно скачать напрямую по ссылке:

- `https://github.com/danil024/cardio_app/raw/main/releases/CardioPulse-v1.0.0-release.apk`

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
