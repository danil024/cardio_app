import 'dart:math' as math;
import 'dart:typed_data';
import 'dart:async';

import 'package:audioplayers/audioplayers.dart';
import 'package:flutter_tts/flutter_tts.dart';

import '../../core/app_strings.dart';

/// Сервис звуковых оповещений (тоны + TTS)
class NotificationAudioService {
  NotificationAudioService() {
    _initPlayer();
    _initTts();
  }

  final FlutterTts _tts = FlutterTts();
  final AudioPlayer _tonePlayer = AudioPlayer();

  bool soundEnabled = true;
  bool ttsEnabled = true;
  bool _ttsReady = false;
  String _ttsLanguage = AppStrings.en;
  AlertState _alertState = AlertState.none;
  DateTime? _lastTtsAt;
  Timer? _alertTimer;
  bool _disposed = false;
  bool _rangeUseBeep = true;
  bool _rangeUseVoice = true;

  Future<void> _initPlayer() async {
    await _tonePlayer.setReleaseMode(ReleaseMode.stop);
    await _tonePlayer.setVolume(1.0);
  }

  Future<void> setTtsLanguage(String language) async {
    final normalized =
        (language == AppStrings.ru) ? AppStrings.ru : AppStrings.en;
    if (normalized == _ttsLanguage && _ttsReady) return;
    _ttsLanguage = normalized;
    await _initTts();
  }

  Future<void> _initTts() async {
    try {
      final preferred = _ttsLanguage == AppStrings.ru
          ? <String>['ru-RU', 'ru', 'en-US']
          : <String>['en-US', 'en', 'ru-RU', 'ru'];
      var configured = false;
      for (final language in preferred) {
        final isAvailable = await _tts.isLanguageAvailable(language);
        // Android returns int (>=0 = available), iOS returns bool true.
        final available = isAvailable is bool
            ? isAvailable
            : (isAvailable is int && isAvailable >= 0);
        if (available) {
          await _tts.setLanguage(language);
          configured = true;
          break;
        }
      }
      if (!configured) {
        await _tts.setLanguage('en-US');
      }
      await _tts.setSpeechRate(0.5);
      await _tts.setVolume(1.0);
      await _tts.awaitSpeakCompletion(true);
      _ttsReady = true;
    } catch (_) {
      _ttsReady = false;
    }
  }

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
      _resetEscalation();
      _alertState = AlertState.none;
      return;
    }

    if (_alertState != nextState) {
      _resetEscalation();
      _alertState = nextState;
      _scheduleImmediateTick();
      return;
    }

    if (_alertTimer == null || !_alertTimer!.isActive) {
      _scheduleNextTick();
    }
  }

  Future<void> _emitAlert() async {
    if (_alertState == AlertState.none || _disposed) return;
    // Beeper goes first so its gainTransient focus is fully released
    // before TTS tries to acquire audio focus. Without this order,
    // the residual focus from a previous tick can silently block TTS.
    if (_rangeUseBeep) {
      await _playTone(_alertState, ignoreMasterSwitch: true);
      // Reset audio context so the player no longer holds audio focus,
      // giving TTS a clean opportunity to speak.
      await _tonePlayer.setAudioContext(AudioContext());
    }
    if (_rangeUseVoice) {
      await _maybeSpeak(ignoreMasterSwitch: true);
    }
  }

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

  Future<void> _maybeSpeak({bool ignoreMasterSwitch = false}) async {
    if ((!ttsEnabled && !ignoreMasterSwitch) ||
        !_ttsReady ||
        _alertState == AlertState.none) {
      return;
    }
    final now = DateTime.now();
    // Единый кулдаун для всех голосовых сообщений
    const requiredGap = Duration(seconds: 5);
    if (_lastTtsAt != null && now.difference(_lastTtsAt!) < requiredGap) {
      return;
    }

    final text = _phraseForState();
    if (text.isEmpty) return;
    _lastTtsAt = now;
    await _tts.stop();
    await _tts.speak(text);
  }

  String _phraseForState() {
    final isRu = _ttsLanguage == AppStrings.ru;
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

  AudioContext _audioContextForState(AlertState state) {
    final emergencyStop = state == AlertState.danger ||
        state == AlertState.customEmergency ||
        state == AlertState.reducePace;
    final startDuck = state == AlertState.increasePace;
    return AudioContext(
      android: AudioContextAndroid(
        contentType: AndroidContentType.sonification,
        usageType: emergencyStop
            ? AndroidUsageType.alarm
            : AndroidUsageType.assistanceSonification,
        audioFocus: emergencyStop
            ? AndroidAudioFocus.gainTransient
            : startDuck
                ? AndroidAudioFocus.gainTransientMayDuck
                : AndroidAudioFocus.none,
      ),
      iOS: AudioContextIOS(
        category: AVAudioSessionCategory.playback,
        options: emergencyStop
            ? {AVAudioSessionOptions.duckOthers}
            : startDuck
                ? {AVAudioSessionOptions.duckOthers}
                : {AVAudioSessionOptions.mixWithOthers},
      ),
    );
  }

  Future<void> _playPattern(List<_ToneStep> steps) async {
    for (var i = 0; i < steps.length; i++) {
      final step = steps[i];
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
      final fadeOut = ((sampleCount - i) / (sampleRate * 0.02)).clamp(0.0, 1.0);
      final envelope = math.min(fadeIn, fadeOut);
      final sample =
          (math.sin(2 * math.pi * frequencyHz * t) * 0.45 * envelope);
      final int16 = (sample * 32767).round().clamp(-32768, 32767);
      writeUint16(int16 & 0xffff);
    }

    return buffer.toBytes();
  }

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
        // Мягкий сигнал для начала упражнения: раз в 3 секунды
        return const Duration(seconds: 3);
      case AlertState.reducePace:
        // Жёсткий сигнал для остановки: каждую секунду
        return const Duration(seconds: 1);
      case AlertState.danger:
      case AlertState.customEmergency:
        return const Duration(seconds: 1);
      case AlertState.none:
        return const Duration(seconds: 1);
    }
  }

  void _resetEscalation() {
    _lastTtsAt = null;
  }

  void _stopAlertTimer() {
    _alertTimer?.cancel();
    _alertTimer = null;
  }

  void dispose() {
    _disposed = true;
    _stopAlertTimer();
    _resetEscalation();
    _alertState = AlertState.none;
    _tts.stop();
    _tonePlayer.dispose();
  }

  Future<void> notifyStartExercise({
    required bool useVoice,
  }) async {
    if (_disposed) return;
    if (soundEnabled) {
      await _tonePlayer
          .setAudioContext(_audioContextForState(AlertState.increasePace));
      await _playPattern(const [
        _ToneStep(520, 90),
        _ToneStep(700, 90),
        _ToneStep(860, 120),
      ]);
    }
    if (useVoice && ttsEnabled && _ttsReady) {
      final isRu = _ttsLanguage == AppStrings.ru;
      await _tts.stop();
      await _tts.speak(isRu
          ? 'Пульс достиг порога. Начинайте упражнение.'
          : 'Heart rate reached the threshold. Start exercise.');
    }
  }

  Future<void> notifyTimerFinished({
    required bool useVoice,
    bool forceSound = true,
  }) async {
    if (_disposed) return;
    if (soundEnabled || forceSound) {
      await _tonePlayer
          .setAudioContext(_audioContextForState(AlertState.danger));
      await _tonePlayer.setVolume(1.0);
      await _playPattern(const [
        _ToneStep(920, 200),
        _ToneStep(920, 200),
        _ToneStep(920, 220),
        _ToneStep(980, 240),
      ]);
    }
    if (useVoice && ttsEnabled && _ttsReady) {
      final isRu = _ttsLanguage == AppStrings.ru;
      await _tts.stop();
      await _tts.speak(isRu ? 'Таймер завершён.' : 'Timer finished.');
    }
  }
}

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
