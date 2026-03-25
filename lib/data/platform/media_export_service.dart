import 'package:flutter/services.dart';

class MediaExportService {
  static const MethodChannel _channel =
      MethodChannel('cardio_app/media_export');

  Future<String?> savePngToGallery({
    required Uint8List bytes,
    required String fileName,
    String albumName = 'CardioApp Export',
  }) async {
    return _channel.invokeMethod<String>('savePngToGallery', {
      'bytes': bytes,
      'fileName': fileName,
      'albumName': albumName,
    });
  }
}
