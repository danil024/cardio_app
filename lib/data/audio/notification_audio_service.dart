import 'dart:math' as math;
import 'dart:typed_data';
import 'dart:async';

import 'package:audioplayers/audioplayers.dart';
import 'package:flutter_tts/flutter_tts.dart';

import '../../core/app_strings.dart';

class NotificationAudioService {
  NotificationAudioService() {
    _initPlayer();
    _bootstrapTts();
  }

  // ── Audio tone player ──────────────────────────────────────────────
  final AudioPlayer _tonePlayer = AudioPlayer();

  // ── TTS engine ─────────────────────────────────────────────────────
  final FlutterTts _tts = FlutterTts();
  bool _ttsReady = false;
  bool _ttsInitializing = false;
  String _ttsLanguage = AppStrings.en;
  // The language the TTS engine actually accepted (may differ from
  // _ttsLanguage if the device lacks the requested language pack).
  String _ttsEffectiveLanguage = AppStrings.en;

  // ── Public switches (set by bloc from settings each heartbeat) ─────
  bool soundEnabled = true;
  bool ttsEnabled = true;

  // ── Per-alert switches (passed from bloc via updateZoneState) ──────
  bool _rangeUseBeep = true;
  bool _rangeUseVoice = true;

  // ── Alert state machine ────────────────────────────────────────────
  AlertState _alertState = AlertState.none;
  Timer? _alertTimer;
  DateTime? _lastTtsAt;
  bool _disposed = false;

  // ────────────────────────────────────────────────────────────────────
  // Initialization
  // ────────────────────────────────────────────────────────────────────

  Future<void> _initPlayer() async {
    await _tonePlayer.setReleaseMode(ReleaseMode.stop);
    await _tonePlayer.setVolume(1.0);
  }

  void _bootstrapTts() {
    // Fire-and-forget; do not await so constructor stays sync.
    _doInitTts();
  }

  Future<void> setTtsLanguage(String language) async {
    final normalized =
        (language == AppStrings.ru) ? AppStrings.ru : AppStrings.en;
    if (normalized == _ttsLanguage && _ttsReady) return;
    _ttsLanguage = normalized;
    await _doInitTts();
  }

  Future<void> _doInitTts() async {
    if (_ttsInitializing) return;
    _ttsInitializing = true;
    try {
      // Check that a TTS engine is installed at all.
      final engines = await _tts.getEngines;
      if (engines is List && engines.isEmpty) {
        _ttsReady = false;
        return;
      }

      final preferred = _ttsLanguage == AppStrings.ru
          ? <String>['ru-RU', 'ru', 'en-US', 'en']
          : <String>['en-US', 'en', 'ru-RU', 'ru'];

      var configured = false;
      String chosenLang = 'en-US';
      for (final lang in preferred) {
        try {
          final result = await _tts.isLanguageAvailable(lang);
          // Android returns int (0 = available, 1 = country available,
          // 2 = variant available, <0 = missing/not supported).
          // iOS returns bool.
          final ok = result is bool
              ? result
              : (result is int && result >= 0);
          if (ok) {
            await _tts.setLanguage(lang);
            chosenLang = lang;
            configured = true;
            break;
          }
        } catch (_) {
          continue;
        }
      }
      if (!configured) {
        await _tts.setLanguage('en-US');
        chosenLang = 'en-US';
      }
      _ttsEffectiveLanguage =
          chosenLang.startsWith('ru') ? AppStrings.ru : AppStrings.en;
      await _tts.setSpeechRate(0.5);
      await _tts.setVolume(1.0);
      await _tts.awaitSpeakCompletion(true);
      _ttsReady = true;
    } catch (_) {
      _ttsReady = false;
    } finally {
      _ttsInitializing = false;
    }
  }

  // ────────────────────────────────────────────────────────────────────
  // Zone alert state machine
  // ────────────────────────────────────────────────────────────────────

  Future<void> updateZoneState({
    required bool inDanger,
    required bool inCustomEmergency,
    required bool aboveTarget,
    required bool belowTarget,
    required bool useBeep,
    required bool useVoice,
  }) async {
    if (_disposed) return;
    _rangeUseBeep = useBeep;
    _rangeUseVoice = useVoice;

    final nextState = inCustomEmergency
        ? AlertState.customEmergency
        : inDanger
            ? AlertState.danger
            : aboveTarget
                ? AlertState.reducePace
                : belowTarget
                    ? AlertState.increasePace
                    : AlertState.none;

    if (nextState == AlertState.none) {
      _stopAlertTimer();
      _alertState = AlertState.none;
      _lastTtsAt = null;
      return;
    }

    if (_alertState != nextState) {
      _lastTtsAt = null;
      _alertState = nextState;
      _scheduleImmediateTick();
      return;
    }

    if (_alertTimer == null || !_alertTimer!.isActive) {
      _scheduleNextTick();
    }
  }

  // ────────────────────────────────────────────────────────────────────
  // Alert emission: beep then voice, fully isolated
  // ────────────────────────────────────────────────────────────────────

  Future<void> _emitAlert() async {
    if (_alertState == AlertState.none || _disposed) return;

    final jobs = <Future<void>>[];

    // Beep and voice run in parallel so they do not interrupt each other.
    if (_rangeUseBeep) {
      jobs.add(_playTone(_alertState));
    }
    if (_rangeUseVoice) {
      jobs.add(_speakAlert());
    }
    if (jobs.isEmpty) {
      return;
    }
    try {
      await Future.wait(jobs);
    } catch (_) {
      // Any single failure must not break the alert loop.
    }
  }

  Future<void> _speakAlert() async {
    if (!_ttsReady || _alertState == AlertState.none || _disposed) return;
    if (!ttsEnabled) return;

    final now = DateTime.now();
    const cooldown = Duration(seconds: 5);
    if (_lastTtsAt != null && now.difference(_lastTtsAt!) < cooldown) return;

    final text = _phraseForState();
    if (text.isEmpty) return;

    _lastTtsAt = now;
    try {
      await _tts.speak(text);
    } catch (_) {
      // TTS failure must not break the alert loop.
    }
  }

  // ────────────────────────────────────────────────────────────────────
  // Tone playback
  // ────────────────────────────────────────────────────────────────────

  Future<void> _playTone(
    AlertState state, {
    bool ignoreMasterSwitch = false,
  }) async {
    if (!soundEnabled && !ignoreMasterSwitch) return;
    await _tonePlayer.setAudioContext(_audioContextForState(state));
    switch (state) {
      case AlertState.reducePace:
        await _playPattern(const [
          _ToneStep(780, 130),
          _ToneStep(640, 180),
        ]);
        break;
      case AlertState.increasePace:
        await _playPattern(const [
          _ToneStep(520, 90),
          _ToneStep(660, 90),
          _ToneStep(820, 130),
        ]);
        break;
      case AlertState.danger:
        await _playPattern(const [
          _ToneStep(920, 170),
          _ToneStep(920, 170),
          _ToneStep(920, 220),
        ]);
        break;
      case AlertState.customEmergency:
        await _playPattern(const [
          _ToneStep(980, 170),
          _ToneStep(860, 170),
          _ToneStep(980, 220),
        ]);
        break;
      case AlertState.none:
        break;
    }
  }

  // ────────────────────────────────────────────────────────────────────
  // Phrases
  // ────────────────────────────────────────────────────────────────────

  String _phraseForState() {
    final isRu = _ttsEffectiveLanguage == AppStrings.ru;
    switch (_alertState) {
      case AlertState.reducePace:
        return isRu ? 'Снизьте темп' : 'Slow down';
      case AlertState.increasePace:
        return isRu ? 'Увеличьте темп' : 'Speed up';
      case AlertState.danger:
        return isRu
            ? 'Опасная зона. Снизьте нагрузку.'
            : 'Danger zone. Slow down.';
      case AlertState.customEmergency:
        return isRu
            ? 'Критический пульс. Немедленно снизьте темп.'
            : 'Critical heart rate. Reduce intensity now.';
      case AlertState.none:
        return '';
    }
  }

  // ────────────────────────────────────────────────────────────────────
  // Audio context / focus
  // ────────────────────────────────────────────────────────────────────

  AudioContext _audioContextForState(AlertState state) {
    final isEmergency =
        state == AlertState.danger || state == AlertState.customEmergency;
    return AudioContext(
      android: AudioContextAndroid(
        contentType: AndroidContentType.sonification,
        usageType:
            isEmergency ? AndroidUsageType.notification : AndroidUsageType.assistanceSonification,
        audioFocus: AndroidAudioFocus.none,
      ),
      iOS: AudioContextIOS(
        category: AVAudioSessionCategory.playback,
        options: const {AVAudioSessionOptions.mixWithOthers},
      ),
    );
  }

  // ────────────────────────────────────────────────────────────────────
  // WAV tone generation
  // ────────────────────────────────────────────────────────────────────

  Future<void> _playPattern(List<_ToneStep> steps) async {
    for (final step in steps) {
      final bytes = _buildWavTone(
        frequencyHz: step.frequencyHz,
        durationMs: step.durationMs,
      );
      await _tonePlayer.stop();
      await _tonePlayer.play(BytesSource(bytes));
      await Future<void>.delayed(
        Duration(milliseconds: step.durationMs + 20),
      );
    }
  }

  Uint8List _buildWavTone({
    required int frequencyHz,
    required int durationMs,
    int sampleRate = 44100,
  }) {
    final sampleCount = (sampleRate * durationMs / 1000).round();
    final byteRate = sampleRate * 2;
    final dataLength = sampleCount * 2;
    final buffer = BytesBuilder(copy: false);

    void writeAscii(String value) => buffer.add(value.codeUnits);
    void writeUint32(int value) => buffer.add([
          value & 0xff,
          (value >> 8) & 0xff,
          (value >> 16) & 0xff,
          (value >> 24) & 0xff,
        ]);
    void writeUint16(int value) => buffer.add([
          value & 0xff,
          (value >> 8) & 0xff,
        ]);

    writeAscii('RIFF');
    writeUint32(36 + dataLength);
    writeAscii('WAVE');
    writeAscii('fmt ');
    writeUint32(16);
    writeUint16(1);
    writeUint16(1);
    writeUint32(sampleRate);
    writeUint32(byteRate);
    writeUint16(2);
    writeUint16(16);
    writeAscii('data');
    writeUint32(dataLength);

    for (var i = 0; i < sampleCount; i++) {
      final t = i / sampleRate;
      final fadeIn = (i / (sampleRate * 0.01)).clamp(0.0, 1.0);
      final fadeOut =
          ((sampleCount - i) / (sampleRate * 0.02)).clamp(0.0, 1.0);
      final envelope = math.min(fadeIn, fadeOut);
      final sample =
          (math.sin(2 * math.pi * frequencyHz * t) * 0.45 * envelope);
      final int16 = (sample * 32767).round().clamp(-32768, 32767);
      writeUint16(int16 & 0xffff);
    }

    return buffer.toBytes();
  }

  // ────────────────────────────────────────────────────────────────────
  // Timer scheduling
  // ────────────────────────────────────────────────────────────────────

  void _scheduleImmediateTick() {
    _stopAlertTimer();
    _alertTimer = Timer(Duration.zero, () async {
      await _emitAlert();
      _scheduleNextTick();
    });
  }

  void _scheduleNextTick() {
    if (_alertState == AlertState.none || _disposed) return;
    _stopAlertTimer();
    _alertTimer = Timer(_nextInterval(), () async {
      await _emitAlert();
      _scheduleNextTick();
    });
  }

  Duration _nextInterval() {
    switch (_alertState) {
      case AlertState.increasePace:
        return const Duration(seconds: 3);
      case AlertState.reducePace:
        return const Duration(seconds: 1);
      case AlertState.danger:
      case AlertState.customEmergency:
        return const Duration(seconds: 1);
      case AlertState.none:
        return const Duration(seconds: 1);
    }
  }

  void _stopAlertTimer() {
    _alertTimer?.cancel();
    _alertTimer = null;
  }

  // ────────────────────────────────────────────────────────────────────
  // One-off notifications (timer finished, start exercise)
  // ────────────────────────────────────────────────────────────────────

  Future<void> notifyStartExercise({required bool useVoice}) async {
    if (_disposed) return;
    final jobs = <Future<void>>[];
    if (soundEnabled) {
      jobs.add(() async {
        try {
          await _tonePlayer
              .setAudioContext(_audioContextForState(AlertState.increasePace));
          await _playPattern(const [
            _ToneStep(520, 90),
            _ToneStep(700, 90),
            _ToneStep(860, 120),
          ]);
        } catch (_) {}
      }());
    }
    if (useVoice && _ttsReady && ttsEnabled) {
      jobs.add(() async {
        try {
        final isRu = _ttsEffectiveLanguage == AppStrings.ru;
        await _tts.speak(isRu
            ? 'Пульс достиг порога. Начинайте упражнение.'
            : 'Heart rate reached the threshold. Start exercise.');
        } catch (_) {}
      }());
    }
    if (jobs.isNotEmpty) {
      await Future.wait(jobs);
    }
  }

  Future<void> notifyTimerFinished({
    required bool useVoice,
    bool forceSound = true,
  }) async {
    if (_disposed) return;
    final jobs = <Future<void>>[];
    if (soundEnabled || forceSound) {
      jobs.add(() async {
        try {
          await _tonePlayer
              .setAudioContext(_audioContextForState(AlertState.danger));
          await _tonePlayer.setVolume(1.0);
          await _playPattern(const [
            _ToneStep(920, 200),
            _ToneStep(920, 200),
            _ToneStep(920, 220),
            _ToneStep(980, 240),
          ]);
        } catch (_) {}
      }());
    }
    if (useVoice && _ttsReady && ttsEnabled) {
      jobs.add(() async {
        try {
        final isRu = _ttsEffectiveLanguage == AppStrings.ru;
        await _tts.speak(isRu ? 'Таймер завершён.' : 'Timer finished.');
        } catch (_) {}
      }());
    }
    if (jobs.isNotEmpty) {
      await Future.wait(jobs);
    }
  }

  // ────────────────────────────────────────────────────────────────────
  // Lifecycle
  // ────────────────────────────────────────────────────────────────────

  void dispose() {
    _disposed = true;
    _stopAlertTimer();
    _lastTtsAt = null;
    _alertState = AlertState.none;
    _tts.stop();
    _tonePlayer.dispose();
  }
}

// ──────────────────────────────────────────────────────────────────────
// Types
// ──────────────────────────────────────────────────────────────────────

enum AlertState {
  none,
  reducePace,
  increasePace,
  danger,
  customEmergency,
}

class _ToneStep {
  const _ToneStep(this.frequencyHz, this.durationMs);

  final int frequencyHz;
  final int durationMs;
}
