import 'package:flutter/services.dart';

class AudioHandler {
  static const MethodChannel _channel = MethodChannel('com.flowfade/audio');

  Future<void> play(String filePath) async {
    await _channel.invokeMethod('play', {'filePath': filePath});
  }

  Future<void> pause() async {
    await _channel.invokeMethod('pause');
  }

  Future<void> resume() async {
    await _channel.invokeMethod('resume');
  }

  Future<void> setCrossfadeDuration(double duration) async {
    await _channel.invokeMethod('setCrossfadeDuration', {'duration': duration});
  }

  Future<Map<String, dynamic>> extractMetadata(String filePath) async {
    final Map<dynamic, dynamic>? result = await _channel.invokeMethod('extractMetadata', {'filePath': filePath});
    if (result != null) {
      return Map<String, dynamic>.from(result);
    }
    return {};
  }
}
