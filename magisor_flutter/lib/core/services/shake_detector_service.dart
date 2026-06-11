import 'dart:async';
import 'package:flutter/services.dart';

enum ShakeSensitivity { low, medium, high }

class ShakeDetectorService {
  static const MethodChannel _channel = MethodChannel('magisor/mouse_hook');
  
  bool _isListening = false;
  Function(double x, double y)? onShakeDetected;
  
  ShakeSensitivity sensitivity = ShakeSensitivity.medium;

  Future<void> start() async {
    if (_isListening) return;
    _isListening = true;
    _channel.setMethodCallHandler(_handleNativeCall);
    try {
      await _channel.invokeMethod('startListening', {
        'sensitivity': sensitivity.index
      });
    } catch (e) {
      print("Warning: Failed to start native mouse hook: $e");
    }
  }

  Future<void> stop() async {
    if (!_isListening) return;
    _isListening = false;
    _channel.setMethodCallHandler(null);
    try {
      await _channel.invokeMethod('stopListening');
    } catch (e) {
      print("Warning: Failed to stop native mouse hook: $e");
    }
  }

  void updateSensitivity(ShakeSensitivity newSensitivity) {
    sensitivity = newSensitivity;
    if (_isListening) {
      _channel.invokeMethod('updateSensitivity', {
        'sensitivity': sensitivity.index
      });
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