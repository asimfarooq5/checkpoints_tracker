import 'package:flutter/services.dart';

// Thin wrapper around a native MethodChannel (see android MainActivity.kt) that
// handles OEM-specific autostart/battery-optimization screens. Hand-rolled instead
// of a third-party plugin because this project's AGP/Gradle version is new enough
// that most published native plugins haven't caught up yet.
class BatteryOptimization {
  static const _channel = MethodChannel('com.guardtracker.checkpoints_tracker/battery');

  static Future<bool> isIgnoringBatteryOptimizations() async {
    try {
      return await _channel.invokeMethod<bool>('isIgnoringBatteryOptimizations') ?? false;
    } catch (_) {
      return false;
    }
  }

  static Future<void> openAutoStartSettings() async {
    try {
      await _channel.invokeMethod('openAutoStartSettings');
    } catch (_) {}
  }
}
