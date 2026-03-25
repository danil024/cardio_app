# Cardio HR Monitor

> Real-time heart rate monitor for BLE sensors — built with Flutter

[![License: MIT](https://img.shields.io/badge/License-MIT-green.svg)](LICENSE)
[![Platform](https://img.shields.io/badge/Platform-Android%20%7C%20iOS-blue.svg)](#supported-platforms)
[![Flutter](https://img.shields.io/badge/Flutter-3.41+-02569B.svg?logo=flutter)](https://flutter.dev)

---

## Download

| Platform | File | Link |
|---|---|---|
| **Android** | `CardioHR-v2.0.0.apk` | [**Download APK**](https://github.com/danil024/cardio_app/releases/download/v2.0.0/CardioHR-v2.0.0.apk) |
| **iOS** | Source archive | [**Download Source**](https://github.com/danil024/cardio_app/raw/main/releases/CardioHR-iOS-source-v2.0.0.zip) |

> **Android**: Download the APK, open it on your phone, and allow installation from unknown sources.  
> **iOS**: Requires a Mac with Xcode. See [iOS Build Instructions](#ios-build-instructions) below.

---

## Features

### Heart Rate Monitoring
- **BLE connection** to GEOID HS500 and compatible HR sensors (Polar, Garmin, Wahoo, etc.)
- **Large BPM display** overlaid on the chart — visible from across the room
- **Real-time chart** with configurable time window (5 / 10 / 20 minutes)
- **Auto-reconnect** on unexpected BLE drops with session auto-save

### Heart Rate Zones
- **5 zones** based on age: Recovery, Fat Burning, Aerobic, Anaerobic, Maximum
- **Color-coded zone indicator** below the chart
- **Two control modes**: Target Zone (age-based) or Manual Range (min–max BPM slider)
- **Independent beeper and voice alerts** for out-of-range heart rate

### Alerts & Notifications
- **Tone alerts** (beeper) with escalating cadence
- **Voice alerts** (TTS) in English or Russian — auto-detects available language
- **Custom emergency threshold** for critical heart rate
- **Start-exercise alert** when HR drops to a set threshold

### Workout Tools
- **Timer / Stopwatch** with iOS-style roller picker and quick presets (1–5 min)
- **Timer end marker** displayed on the chart
- **Music controls** (prev / play-pause / next) via system media keys
- **Current time** (HH:MM:SS) displayed in the header

### Data & History
- **Auto-save** sessions in CSV and JSON to `/storage/emulated/0/CardioAppLog`
- **History screen** — view, export (CSV/JSON), copy to clipboard, and delete past sessions
- **Storage cleanup** prompt when logs exceed 100 MB

### UX
- **Back button minimizes** (does not close) — workout continues in background
- **Screen wake lock** — prevents screen lock during workouts
- **Bilingual UI** — English (default) and Russian, linked with voice language
- **Test mode** — emulated heart rate for UI testing without a sensor
- **Dark theme** optimized for workout visibility

---

## Screenshots

<table>
<tr>
<td align="center"><b>Main Screen</b><br>Real-time chart with BPM overlay, zone indicator, timer, and media controls</td>
<td align="center"><b>Settings</b><br>Age roller, HR control mode, chart window, language selection</td>
</tr>
</table>

> To add screenshots: take them on your phone, place in a `screenshots/` folder, and update the links above.

---

## Supported Platforms

| Platform | Status | Notes |
|---|---|---|
| **Android** | Production-ready | APK available for download |
| **iOS** | Source-ready | Requires Mac + Xcode for build; BLE & TTS fully supported |

### Compatible Sensors

Any BLE heart rate monitor advertising the standard Heart Rate Service (`0x180D`):

- GEOID HS500 (primary target)
- Polar H10 / H9 / OH1
- Garmin HRM-Pro / HRM-Dual
- Wahoo TICKR / TICKR X
- Coospo, Magene, and other ANT+/BLE chest straps

---

## Installation

### Android — APK

1. Download [CardioHR-v2.0.0.apk](https://github.com/danil024/cardio_app/releases/download/v2.0.0/CardioHR-v2.0.0.apk)
2. Transfer to your phone (or open the link directly on the phone)
3. Allow installation from unknown sources when prompted
4. Open **Cardio HR Monitor** and grant Bluetooth & Location permissions
5. Put on your HR sensor and tap **Connect**

### Android — ADB

```bash
adb install -r CardioHR-v2.0.0.apk
```

### iOS Build Instructions

1. Download [CardioHR-iOS-source-v2.0.0.zip](https://github.com/danil024/cardio_app/raw/main/releases/CardioHR-iOS-source-v2.0.0.zip) or clone this repo
2. On a Mac with Xcode installed:

```bash
flutter pub get
cd ios && pod install && cd ..
flutter build ios --release
```

3. Deploy to your iPhone via Xcode or `flutter run` with the device connected

---

## Building from Source

### Prerequisites

- Flutter SDK >= 3.2.0
- Android SDK 36 with Build-Tools 28.0.3 (for Android)
- Xcode 15+ (for iOS, macOS only)

### Development

```bash
git clone https://github.com/danil024/cardio_app.git
cd cardio_app
flutter pub get
flutter run
```

### Release Build

```bash
# Android APK
flutter build apk --release

# Android App Bundle (for Play Store)
flutter build appbundle --release

# iOS (macOS only)
flutter build ios --release
```

---

## Project Architecture

Clean Architecture with BLoC state management:

```
lib/
├── core/              Constants, localization strings
├── data/
│   ├── audio/         Tone generation + TTS voice alerts
│   ├── ble/           BLE scanning, connection, HR parsing
│   ├── media/         System media key dispatch
│   ├── platform/      Native platform calls (force exit)
│   └── storage/       Settings, session persistence, history
├── domain/
│   └── models/        HrReading, HrZones, ZonesCalculator
└── presentation/
    ├── home/           Main screen, BLoC, chart, zone widget
    ├── history/        Session list, detail view
    └── settings/       Settings screen with auto-save
```

### Key Dependencies

| Package | Purpose |
|---|---|
| `flutter_blue_plus` | BLE communication |
| `flutter_bloc` | State management |
| `fl_chart` | Real-time heart rate chart |
| `flutter_tts` | Text-to-speech voice alerts |
| `audioplayers` | Generated WAV tone playback |
| `wakelock_plus` | Screen wake lock |
| `shared_preferences` | Settings persistence |
| `share_plus` | File sharing / export |

---

## Configuration

All settings are saved automatically and persist across sessions:

| Setting | Options | Default |
|---|---|---|
| Age | 18–100 (roller picker) | 35 |
| HR Control Mode | Target Zone / Manual Range | Target Zone |
| Target Zone Alerts | Beeper + Voice (always on) | On |
| Manual Range Beeper | On / Off | On |
| Manual Range Voice | On / Off | On |
| Keep Screen On | On / Off | On |
| Timer/Stopwatch | On / Off | On |
| Music Controls | On / Off | On |
| Chart Window | 5 / 10 / 20 min | 5 min |
| Language | English / Russian | English |

---

## Export Formats

Session history supports two export formats for easy import in other apps:

- `CSV`:
  - Header: `timestamp,heart_rate,bpm`
  - `timestamp` is ISO-8601
  - `heart_rate` and `bpm` contain the same value for compatibility
- `JSON`:
  - Metadata: `format`, `format_version`, `session_id`, `started_at`, `ended_at`
  - Session profile: `age`, `max_hr`, `target_zone_min`, `target_zone_max`, `heart_rate_unit`
  - Data points: `readings[]` with timestamp and heart rate values

Both CSV and JSON can be shared as files or copied to clipboard directly from the app UI.

---

## Legal

- **License**: [MIT License](LICENSE) — free for personal and commercial use
- **Privacy Policy**: [PRIVACY_POLICY.md](PRIVACY_POLICY.md) — no data leaves your device
- **Disclaimer**: This app is a fitness tool, **not a medical device**. Do not use it for medical diagnosis or treatment. Always consult a healthcare professional before starting any exercise program. The developers are not liable for any health-related outcomes from using this application.
- **Trademarks**: GEOID, Polar, Garmin, Wahoo are trademarks of their respective owners. This project is not affiliated with or endorsed by any sensor manufacturer.

---

## Contributing

1. Fork the repository
2. Create a feature branch (`git checkout -b feature/my-feature`)
3. Commit your changes
4. Push and open a Pull Request

---

## Changelog

See [CHANGELOG.md](CHANGELOG.md) for the full version history.

---

<p align="center">
  Made with Flutter | <a href="https://github.com/danil024/cardio_app">GitHub</a>
</p>
