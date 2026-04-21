# Changelog

All notable changes to this project are documented in this file.

## v2.2.0 — 2026-04-21

### Added
- **Coach summary export**: compact `*.coach.json` session export for trainer review with key HR aggregates and zone distribution.
- **Tap-to-settings on target zone card**: quick navigation from home screen target-zone module to HR target settings.

### Changed
- **Session continuity policy**: recording now stays in one session across reconnect attempts and app pause; session split happens only when a BLE disconnect gap exceeds 10 minutes.
- **History copy/share behavior**: text export actions now use compact coach summary output by default instead of full raw logs.
- **Media module layout**: merged play/pause into a single center button and aligned controls to 3 symmetric buttons.
- **Home screen resilience on rotation**: main layout now scrolls on constrained heights to avoid overflow.

### Fixed
- **Android debug tooling**: added `INTERNET` permission in manifest to restore Dart VM service startup and enable `r`/`R` hot reload/restart.
- **Metronome preset editor crash**: fixed red-screen crash when saving/editing presets caused by premature `TextEditingController` disposal.

## v2.0.0 — 2026-03-13

### Added
- **HR Control Mode**: choose between Target Zone (age-based) or Manual Range (min–max slider) with independent beeper and voice toggles.
- **Auto-reconnect**: on unexpected BLE drops — attempts reconnection for 25s, auto-saves session, force-exits if unrecoverable.
- **Data watchdog**: detects silent sensor data drops and triggers reconnect flow.
- **Back-minimize**: back button/gesture minimizes the app instead of closing — workout continues in background.
- **iPhone-style age roller** (CupertinoPicker) in settings.
- **Force-exit** via native MethodChannel for unrecoverable disconnects.

### Changed
- **TTS voice fix**: tracks effective engine language separately from UI language; if Russian TTS is unavailable, phrases fall back to English automatically.
- **TTS init guard**: `setTtsLanguage` no longer re-initializes the engine on every heartbeat — only when the language actually changes.
- **TTS isolation**: beeper plays first, releases audio focus with 150ms gap, then TTS speaks — prevents audio focus conflicts on Android.
- **Sensor poll interval**: removed manual setting; auto-derived from chart window (5min→500ms, 10min→1s, 20min→2s). Real BLE sensors are push-based and unaffected.
- **Chart window options**: restricted to 5, 10, 20 minutes with soft migration from legacy values.
- **Settings layout**: reordered and consolidated — Age, HR Control Mode, Additional Settings, Chart Window, Language, Test.
- **Connect button**: compact icon-only design with colored status dot.

### Fixed
- Chart freezing after ~1/4 of the time window.
- Old chart peaks changing values (removed bucket aggregation, direct point plotting).
- Timer end sound not playing.
- Chart bottom edge not resting on the X-axis.
- Timer marker pointing to start instead of end time.
- White screen on navigation to Settings/History.
- Range alerts not firing when enabled.

## v1.0.0 — 2026-03-12

### Added
- BLE heart-rate workflow with GEOID HS500 focused discovery.
- Real-time HR chart with dynamic vertical range and detailed grid.
- Large BPM overlay on chart.
- Five-zone heart-rate model with visual zone indication.
- Alert engine with sound and TTS notifications.
- Timer/stopwatch module with roller-based time picker.
- Media control module with system Android media key integration.
- Workout history with CSV/JSON autosave and delete actions.
- EN/RU localization with linked interface + voice language switch.
- Test mode with emulated heart rate.
- Screen wake lock during workouts.
