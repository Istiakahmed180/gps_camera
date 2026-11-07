import 'package:flutter/services.dart';

/// Lets the phone's volume buttons act as a shutter. Android only passes
/// the keys to the app while [enable] is on, so volume works normally
/// everywhere else.
class VolumeShutter {
  VolumeShutter([MethodChannel? channel])
    : _channel = channel ?? const MethodChannel('co.tdevs.gps_camera/volume');

  final MethodChannel _channel;

  Future<void> enable(VoidCallback onPressed) async {
    _channel.setMethodCallHandler((call) async {
      if (call.method == 'pressed') onPressed();
    });
    await _set(true);
  }

  Future<void> disable() async {
    _channel.setMethodCallHandler(null);
    await _set(false);
  }

  Future<void> _set(bool enabled) async {
    try {
      await _channel.invokeMethod<void>('setEnabled', enabled);
    } on PlatformException {
      // Volume keys keep their normal behaviour.
    } on MissingPluginException {
      // Not available on this platform or in tests.
    }
  }
}
