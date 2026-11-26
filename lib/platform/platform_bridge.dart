import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';

class PlatformBridge {
  const PlatformBridge();

  static const MethodChannel _channel = MethodChannel(
    'com.dearlicy.sillytavern/platform',
  );

  Future<String> platformName() async {
    if (kIsWeb) return 'web';
    try {
      return await _channel.invokeMethod<String>('platformName') ?? 'unknown';
    } on PlatformException {
      return 'unknown';
    } on MissingPluginException {
      return 'unknown';
    }
  }

  Future<void> setSecureScreen(bool enabled) async {
    if (kIsWeb) return;
    try {
      await _channel.invokeMethod<void>('setSecureScreen', {
        'enabled': enabled,
      });
    } on PlatformException {
      // Older builds may not expose the native channel yet.
    } on MissingPluginException {
      // The Flutter-only web and test targets intentionally have no native side.
    }
  }
}
