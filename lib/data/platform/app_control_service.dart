import 'dart:io';

import 'package:flutter/services.dart';

class AppControlService {
  static const MethodChannel _channel = MethodChannel('cardio_app/app_control');

  Future<void> forceExit() async {
    if (!Platform.isAndroid) {
      await SystemNavigator.pop();
      return;
    }
    await _channel.invokeMethod<void>('forceExit');
  }
}
