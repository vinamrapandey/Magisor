import 'dart:ui' show Offset;
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';

/// OS integration that lives in the native runner (Windows registry, etc.).
/// A [ChangeNotifier] so the Settings toggle reflects the real state.
class SystemService extends ChangeNotifier {
  static const MethodChannel _channel = MethodChannel('magisor/system');

  bool _launchAtStartup = false;
  bool get launchAtStartup => _launchAtStartup;

  /// Read the current launch-at-startup state. Call once at startup.
  Future<void> load() async {
    try {
      final r = await _channel.invokeMethod('isLaunchAtStartup');
      _launchAtStartup = r == true;
      notifyListeners();
    } catch (e) {
      debugPrint('isLaunchAtStartup failed: $e');
    }
  }

  /// Current mouse cursor position in physical screen pixels, or null.
  Future<Offset?> getCursorPos() async {
    try {
      final r = await _channel.invokeMethod('getCursorPos');
      if (r is Map) {
        return Offset((r['x'] as num).toDouble(), (r['y'] as num).toDouble());
      }
    } catch (e) {
      debugPrint('getCursorPos failed: $e');
    }
    return null;
  }

  Future<void> setLaunchAtStartup(bool enabled) async {
    try {
      await _channel.invokeMethod('setLaunchAtStartup', {'enabled': enabled});
      _launchAtStartup = enabled;
    } catch (e) {
      debugPrint('setLaunchAtStartup failed: $e');
    }
    notifyListeners();
  }
}
