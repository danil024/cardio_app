import 'package:flutter/services.dart';

class MediaControlService {
  static const MethodChannel _channel =
      MethodChannel('cardio_app/media_control');

  Future<void> previous() async {
    await _channel.invokeMethod<void>('previous');
  }

  Future<void> playPause() async {
    await _channel.invokeMethod<void>('playPause');
  }

  Future<void> play() async {
    await _channel.invokeMethod<void>('play');
  }

  Future<void> pause() async {
    await _channel.invokeMethod<void>('pause');
  }

  Future<void> next() async {
    await _channel.invokeMethod<void>('next');
  }
}
