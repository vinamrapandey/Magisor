import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';

enum ShakeSensitivity { low, medium, high }

/// Bridges the native C++ mouse-shake hook to Dart.
///
/// A [ChangeNotifier] so the Settings slider reflects changes live, and the
/// chosen sensitivity is persisted so it survives restarts.
class ShakeDetectorService extends ChangeNotifier {
  static const MethodChannel _channel = MethodChannel('magisor/mouse_hook');
  static const FlutterSecureStorage _storage = FlutterSecureStorage();
  static const String _sensitivityKey = 'magisor_shake_sensitivity';

  bool _isListening = false;
  Function(double x, double y)? onShakeDetected;

  ShakeSensitivity _sensitivity = ShakeSensitivity.medium;
  ShakeSensitivity get sensitivity => _sensitivity;

  Future<void> start() async {
    if (_isListening) return;
    _isListening = true;
    _channel.setMethodCallHandler(_handleNativeCall);

    await _loadSensitivity();

    try {
      await _channel.invokeMethod('startListening', {
        'sensitivity': _sensitivity.index,
      });
    } catch (e) {
      debugPrint("Warning: Failed to start native mouse hook: $e");
    }
  }

  Future<void> stop() async {
    if (!_isListening) return;
    _isListening = false;
    _channel.setMethodCallHandler(null);
    try {
      await _channel.invokeMethod('stopListening');
    } catch (e) {
      debugPrint("Warning: Failed to stop native mouse hook: $e");
    }
  }

  Future<void> updateSensitivity(ShakeSensitivity newSensitivity) async {
    if (newSensitivity == _sensitivity) return;
    _sensitivity = newSensitivity;
    notifyListeners();

    try {
      await _storage.write(key: _sensitivityKey, value: newSensitivity.index.toString());
    } catch (_) {
      // Persistence is best-effort.
    }

    if (_isListening) {
      try {
        await _channel.invokeMethod('updateSensitivity', {
          'sensitivity': _sensitivity.index,
        });
      } catch (e) {
        debugPrint("Warning: Failed to update sensitivity: $e");
      }
    }
  }

  Future<void> _loadSensitivity() async {
    try {
      final stored = await _storage.read(key: _sensitivityKey);
      final idx = stored == null ? null : int.tryParse(stored);
      if (idx != null && idx >= 0 && idx < ShakeSensitivity.values.length) {
        _sensitivity = ShakeSensitivity.values[idx];
        notifyListeners();
      }
    } catch (_) {
      // Keep the default sensitivity if storage is unavailable.
    }
  }

  Future<dynamic> _handleNativeCall(MethodCall call) async {
    if (call.method == 'onShakeDetected') {
      final args = call.arguments as Map<dynamic, dynamic>;
      if (onShakeDetected != null) {
        onShakeDetected!(args['x'] as double, args['y'] as double);
      }
    }
  }
}
