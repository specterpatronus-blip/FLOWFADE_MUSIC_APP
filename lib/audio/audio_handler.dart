import 'package:flutter/services.dart';
import 'package:flutter/cupertino.dart';

class AudioHandler {
  static const MethodChannel _channel = MethodChannel('com.flowfade/audio');

  void setNativeCommandHandler({
    Future<void> Function()? onNextTrack,
    Future<void> Function()? onPreviousTrack,
  }) {
    _channel.setMethodCallHandler((call) async {
      switch (call.method) {
        case 'nextTrack':
          await onNextTrack?.call();
          break;
        case 'previousTrack':
          await onPreviousTrack?.call();
          break;
      }
    });
  }

  Future<bool> play(String filePath) async {
    debugPrint('AudioHandler: play() called with: $filePath');
    try {
      await _channel.invokeMethod('play', {'filePath': filePath});
      debugPrint('AudioHandler: play() completed successfully');
      return true;
    } on PlatformException catch (e) {
      debugPrint('AudioHandler: play() FAILED -> ${e.code}: ${e.message}');
      return false;
    } on MissingPluginException catch (e) {
      debugPrint('AudioHandler: play() FAILED -> MissingPluginException: $e');
      return false;
    } catch (e) {
      debugPrint('AudioHandler: play() FAILED -> $e');
      return false;
    }
  }

  Future<bool> pause() async {
    try {
      await _channel.invokeMethod('pause');
      return true;
    } on PlatformException catch (e) {
      debugPrint('AudioHandler: pause() FAILED -> ${e.message}');
      return false;
    } on MissingPluginException catch (e) {
      debugPrint('AudioHandler: pause() FAILED -> MissingPluginException: $e');
      return false;
    } catch (e) {
      debugPrint('AudioHandler: pause() FAILED -> $e');
      return false;
    }
  }

  Future<bool> resume() async {
    try {
      await _channel.invokeMethod('resume');
      return true;
    } on PlatformException catch (e) {
      debugPrint('AudioHandler: resume() FAILED -> ${e.message}');
      return false;
    } on MissingPluginException catch (e) {
      debugPrint('AudioHandler: resume() FAILED -> MissingPluginException: $e');
      return false;
    } catch (e) {
      debugPrint('AudioHandler: resume() FAILED -> $e');
      return false;
    }
  }

  Future<void> setCrossfadeDuration(double duration) async {
    try {
      await _channel.invokeMethod('setCrossfadeDuration', {'duration': duration});
    } on PlatformException catch (e) {
      debugPrint('AudioHandler: setCrossfadeDuration() FAILED -> ${e.message}');
    }
  }

  Future<Map<String, dynamic>> extractMetadata(String filePath) async {
    try {
      final Map<dynamic, dynamic>? result = await _channel.invokeMethod('extractMetadata', {'filePath': filePath});
      if (result != null) {
        return Map<String, dynamic>.from(result);
      }
    } on PlatformException catch (e) {
      debugPrint('AudioHandler: extractMetadata() FAILED -> ${e.message}');
    }
    return {};
  }
}
